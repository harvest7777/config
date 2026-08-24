-- Floating terminal. Replaces the hand-rolled float that used to live in
-- keymaps.lua: floaterm owns the window, the multi-terminal sidebar and
-- the toggle, so all that's left here is the behaviour it doesn't cover.
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
  if vim.bo[vim.api.nvim_get_current_buf()].buftype ~= 'terminal' then
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

  local group = vim.api.nvim_create_augroup('FloatermScrollback', { clear = true })

  -- Scrolling back down to the live screen means you're done reading, so
  -- hand the keyboard back to the shell. Also makes a stray wheel nudge
  -- at the prompt a no-op.
  vim.api.nvim_create_autocmd('WinScrolled', {
    group = group,
    buffer = buf,
    callback = function()
      -- Normal mode in a terminal buffer reports as 'nt', not 'n'.
      if vim.api.nvim_get_mode().mode:sub(1, 1) ~= 'n' then
        return
      end
      if vim.fn.line('w$') >= vim.api.nvim_buf_line_count(buf) then
        term_resume()
      end
    end,
    desc = 'Leave terminal scrollback once the live screen is back in view',
  })

  -- A shell has no use for the global scrolloff, and at this config's
  -- value it would shove the live prompt into the middle of the float
  -- the moment the wheel drops you into normal mode. Window-local, so it
  -- has to be reapplied every time the float is reopened.
  vim.api.nvim_create_autocmd({ 'BufWinEnter', 'WinEnter' }, {
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
    mappings = { term = setup_term_buf },
  },
}
