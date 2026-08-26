-- Floating terminal. Replaces the hand-rolled float that used to live in
-- keymaps.lua: floaterm owns the window, the multi-terminal sidebar and
-- the toggle, so all that's left here is the behaviour it doesn't cover.
local api = vim.api

local function float_term_dir()
  local dir = vim.fn.expand('%:p:h')
  if dir == '' or vim.fn.isdirectory(dir) == 0 then
    dir = vim.fn.getcwd()
  end
  return dir
end

-- Same tmux copy-mode treatment the old float had: the mouse wheel drops
-- a terminal out of terminal mode (:h terminal-mouse), so make getting
-- back to the prompt automatic rather than a manual `i`.
local function term_resume()
  if vim.bo[api.nvim_get_current_buf()].buftype ~= 'terminal' then
    return
  end
  -- Scheduled because startinsert doesn't stick when it's issued from
  -- inside a mapping or an autocmd.
  vim.schedule(function()
    vim.cmd('startinsert')
  end)
end

local function setup_term_buf(buf)
  -- floaterm routes its buffers through volt, which claims <C-t> (cycle
  -- windows) and -- worse for a terminal you reach by scrolling -- binds
  -- q and <Esc> to tear the whole thing down, shells included. This hook
  -- runs after volt's mappings, so these win.
  vim.keymap.set({ 'n', 't' }, '<C-t>', function()
    require('floaterm').toggle()
  end, { buffer = buf, desc = 'Toggle floating terminal' })

  vim.keymap.set('n', 'q', term_resume, { buffer = buf, desc = 'Resume typing in the terminal' })
  vim.keymap.set('n', '<Esc>', term_resume, { buffer = buf, desc = 'Resume typing in the terminal' })

  local group = api.nvim_create_augroup('FloatermScrollback', { clear = true })

  -- Scrolling back down to the live screen means you're done reading, so
  -- hand the keyboard back to the shell. Also makes a stray wheel nudge
  -- at the prompt a no-op.
  api.nvim_create_autocmd('WinScrolled', {
    group = group,
    buffer = buf,
    callback = function()
      -- Normal mode in a terminal buffer reports as 'nt', not 'n'.
      if api.nvim_get_mode().mode:sub(1, 1) ~= 'n' then
        return
      end
      if vim.fn.line('w$') >= api.nvim_buf_line_count(buf) then
        term_resume()
      end
    end,
    desc = 'Leave terminal scrollback once the live screen is back in view',
  })

  -- A shell has no use for the global scrolloff, and at this config's
  -- value it would shove the live prompt into the middle of the float
  -- the moment the wheel drops you into normal mode. Window-local, so it
  -- has to be reapplied every time the float is reopened.
  api.nvim_create_autocmd({ 'BufWinEnter', 'WinEnter' }, {
    group = group,
    buffer = buf,
    callback = function()
      vim.wo.scrolloff = 0
      vim.wo.sidescrolloff = 0
    end,
    desc = 'Drop scrolloff in the floating terminal window',
  })

  vim.wo.scrolloff = 0
  vim.wo.sidescrolloff = 0
end

-- floaterm's own rename redraws the sidebar list and nothing else, so the
-- info bar on the right keeps showing the old name until something happens
-- to redraw it -- selecting a terminal, or the bar's own 10s refresh timer.
-- It also writes the prompt's result back unconditionally, so cancelling
-- sets the name to nil and every later bar redraw throws on the concat in
-- floaterm's ui.lua. Same rename, minus both.
local function setup_sidebar_buf(buf)
  vim.keymap.set('n', 'e', function()
    local state = require('floaterm.state')
    local volt = require('volt')
    local row = require('floaterm.utils').get_buf_on_cursor()
    if not row then
      return
    end

    vim.ui.input({ prompt = '   Enter name: ' }, function(input)
      api.nvim_echo({}, false, {})
      if not input or input == '' then
        return
      end
      state.terminals[row].name = input
      volt.redraw(state.sidebuf, 'bufs')
      volt.redraw(state.barbuf, 'bar')
    end)
  end, { buffer = buf, desc = 'Rename terminal' })
end

-- floaterm builds its UI out of three independently bordered floats laid
-- next to each other, which leaves a one-column seam between the sidebar
-- and the terminal where the buffer underneath shows through, and gives
-- the group no outline of its own. The layout below reassembles the same
-- three windows as a single framed unit: a backdrop float draws the outer
-- border and fills every cell behind the group, and the bar and terminal
-- carry only the rules that divide the interior.
local SIDEBAR_W = 20 -- floaterm hardcodes this
local OUTER_BORDER = 'rounded'
local BAR_BORDER = { '', '', '', '', '', '', '', '│' }
local TERM_BORDER = { '├', '─', '', '', '', '', '', '│' }
local FRAME_HL = 'Normal:Normal,FloatBorder:Comment'

local backdrop_buf, backdrop_win

local function close_backdrop()
  if backdrop_win and api.nvim_win_is_valid(backdrop_win) then
    api.nvim_win_close(backdrop_win, true)
  end
  backdrop_win = nil
end

-- Geometry of the whole assembly. size.h/size.w are read as the outer
-- dimensions, frame included, so the group never runs off the screen.
local function geometry(state)
  local conf = state.config
  local min_h = #(state.terminals or { 1 }) + 5
  local total_h = math.floor(vim.o.lines * (conf.size.h / 100))
  local total_w = math.floor(vim.o.columns * (conf.size.w / 100))

  total_h = math.min(math.max(total_h, min_h), vim.o.lines)
  total_w = math.min(math.max(total_w, SIDEBAR_W + 14), vim.o.columns)

  local g = {
    -- outer frame (backdrop border) top-left
    oy = math.max(0, math.floor((vim.o.lines - total_h) / 2) - 1),
    ox = math.max(0, math.floor((vim.o.columns - total_w) / 2)),
    -- interior: everything inside the frame
    ih = total_h - 2,
    iw = total_w - 2,
  }
  g.iy, g.ix = g.oy + 1, g.ox + 1
  g.pane_w = g.iw - SIDEBAR_W - 1 -- minus the vertical rule
  return g
end

local function apply_frame()
  local state = require('floaterm.state')
  if not state.volt_set or not (state.win and api.nvim_win_is_valid(state.win)) then
    return
  end

  local volt = require('volt')
  local g = geometry(state)

  -- floaterm's sidebar filler and bar padding are derived from these, so
  -- they have to describe the reshaped windows, not the original ones.
  -- The bar pads itself to state.w - SIDEBAR_W - 2, two cells short of its
  -- own window, so state.w has to be back-solved from the new pane width.
  state.h = g.ih
  state.w = g.pane_w + SIDEBAR_W

  -- Reused by floaterm when it has to recreate the terminal window.
  state.term_win_opts = {
    relative = 'editor',
    row = g.iy + 1,
    col = g.ix + SIDEBAR_W,
    width = g.pane_w,
    height = g.ih - 2,
    style = 'minimal',
    border = TERM_BORDER,
    zindex = 100,
  }

  if not (backdrop_win and api.nvim_win_is_valid(backdrop_win)) then
    if not (backdrop_buf and api.nvim_buf_is_valid(backdrop_buf)) then
      backdrop_buf = api.nvim_create_buf(false, true)
    end
    backdrop_win = api.nvim_open_win(backdrop_buf, false, {
      relative = 'editor',
      row = g.oy,
      col = g.ox,
      width = g.iw,
      height = g.ih,
      style = 'minimal',
      border = OUTER_BORDER,
      -- Below the group's own windows (100) but above the buffer, so it
      -- backs the seams instead of covering the terminal.
      zindex = 99,
      focusable = false,
      noautocmd = true,
    })
    vim.wo[backdrop_win].winhl = FRAME_HL
  else
    api.nvim_win_set_config(backdrop_win, {
      relative = 'editor',
      row = g.oy,
      col = g.ox,
      width = g.iw,
      height = g.ih,
      border = OUTER_BORDER,
    })
  end

  api.nvim_win_set_config(state.sidewin, {
    relative = 'editor',
    row = g.iy,
    col = g.ix,
    width = SIDEBAR_W,
    height = g.ih,
    border = 'none',
  })
  api.nvim_win_set_config(state.barwin, {
    relative = 'editor',
    row = g.iy,
    col = g.ix + SIDEBAR_W,
    width = g.pane_w,
    height = 1,
    border = BAR_BORDER,
  })
  api.nvim_win_set_config(state.win, {
    relative = 'editor',
    row = state.term_win_opts.row,
    col = state.term_win_opts.col,
    width = state.term_win_opts.width,
    height = state.term_win_opts.height,
    border = TERM_BORDER,
  })

  vim.wo[state.barwin].winhl = FRAME_HL
  vim.wo[state.win].winhl = FRAME_HL

  -- volt lays its content out against a buffer of blank lines sized to
  -- the window, so both buffers have to be refilled at the new size
  -- before the extmarks are redrawn.
  vim.bo[state.sidebuf].modifiable = true
  volt.set_empty_lines(state.sidebuf, g.ih, SIDEBAR_W)
  volt.redraw(state.sidebuf, 'all')
  vim.bo[state.sidebuf].modifiable = false

  vim.bo[state.barbuf].modifiable = true
  volt.set_empty_lines(state.barbuf, 1, g.pane_w)
  volt.redraw(state.barbuf, 'bar')
  vim.bo[state.barbuf].modifiable = false
end

return {
  'nvzone/floaterm',
  dependencies = 'nvzone/volt',
  cmd = 'FloatermToggle',
  keys = {
    { '<C-t>', '<cmd>FloatermToggle<cr>', desc = 'Toggle floating terminal' },
  },
  opts = {
    border = true,
    size = { h = 80, w = 90 },
    -- floaterm has no cwd option; it just jobstart()s vim.o.shell. The
    -- cmd string is run as `shell -c "<cmd>; shell"`, so cd'ing there is
    -- what gets a shell that opens in the current buffer's directory.
    terminals = function()
      return { { name = 'Terminal', cmd = 'cd ' .. vim.fn.shellescape(float_term_dir()) } }
    end,
    mappings = { sidebar = setup_sidebar_buf, term = setup_term_buf },
  },
  config = function(_, opts)
    local floaterm = require('floaterm')
    floaterm.setup(opts)

    -- floaterm has no hook that runs once the group is on screen, so wrap
    -- open(). toggle() and :FloatermToggle both route through it.
    local open = floaterm.open
    floaterm.open = function(...)
      open(...)
      apply_frame()
    end

    local group = api.nvim_create_augroup('FloatermFrame', { clear = true })

    -- floaterm sizes itself off vim.o.lines/columns once, at open. Without
    -- this the group keeps its old size after the tmux pane it lives in is
    -- resized.
    api.nvim_create_autocmd('VimResized', {
      group = group,
      callback = apply_frame,
      desc = 'Re-lay out the floating terminal when the editor resizes',
    })

    -- The backdrop isn't one of floaterm's windows, so nothing closes it
    -- when the group goes away -- and the group can go away by toggle, by
    -- volt's q/<Esc>, or by the last terminal being deleted.
    api.nvim_create_autocmd('WinClosed', {
      group = group,
      callback = function()
        if not backdrop_win then
          return
        end
        vim.schedule(function()
          local state = require('floaterm.state')
          if state.volt_set and state.win and api.nvim_win_is_valid(state.win) then
            return
          end
          close_backdrop()
        end)
      end,
      desc = 'Tear down the floating terminal backdrop with the group',
    })
  end,
}
