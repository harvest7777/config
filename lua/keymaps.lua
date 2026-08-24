local function read_cache(cache_path)
  local f = io.open(cache_path, "r")
  if not f then
    return {}
  end
  local content = f:read("*a")
  f:close()
  if content == "" then
    return {}
  end
  local ok, data = pcall(vim.json.decode, content)
  if not ok or type(data) ~= "table" then
    return {}
  end
  return data
end

vim.keymap.set('n', '<leader>ip', function()
  local opts = { prompt = 'Enter pr link', scope = 'buffer' }

  vim.ui.input(opts, function(input)
    local valid = input ~= '' and input ~= nil
    if valid then
      local state_path = vim.fs.joinpath(vim.fn.stdpath("state"), "pr_links.json")

      local data = read_cache(state_path)

      local cwd = vim.fn.getcwd()
      local branch_name = vim.fn.system("git rev-parse --abbrev-ref HEAD")
      local cwd_branch_name_key = cwd .. "-" .. branch_name

      data[cwd_branch_name_key] = input

      local f = io.open(state_path, "w")
      if not f then
        return
      end
      f:write(vim.json.encode(data))
      f:close()
      vim.notify('Saved ' .. input)
    end
  end)
end, { desc = 'Save PR to branch or worktree' })

vim.keymap.set('n', '<leader>gp', function()
  local cwd = vim.fn.getcwd()
  -- a combination of cwd/branch is guaranteed to be unique
  local branch_name = vim.fn.system("git rev-parse --abbrev-ref HEAD")
  local cwd_branch_name_key = cwd .. "-" .. branch_name
  -- need to save that bitch somewhere
  local state_path = vim.fs.joinpath(vim.fn.stdpath("state"), "pr_links.json")
  local data = read_cache(state_path)
  local pr_link = data[cwd_branch_name_key]
  vim.fn.setreg("+", pr_link)
  vim.notify('Copied ' .. pr_link)
end, { desc = 'Save PR to branch or worktree' })

-- misc
vim.keymap.set('n', '<leader>ww', '<cmd>w<cr>', { desc = 'Write file' })
vim.keymap.set('n', '<leader>wa', '<cmd>wa<cr>', { desc = 'Write all' })
vim.keymap.set('n', '<leader>qq', '<cmd>qa!<cr>', { desc = 'Quit all' })
-- Neogit's "view file at old commit" buffers are named
-- neogit://<sha>/<path-relative-to-repo-root>, not a real filesystem path,
-- so expand("%:p") on them just returns garbage. Resolve to the real path
-- on disk in that case; everywhere else, behave exactly as before.
local function real_path_for_current_buffer()
  local name = vim.api.nvim_buf_get_name(0)
  local rel = name:match("^neogit://[^/]+/(.+)$")
  if not rel then
    return nil
  end
  local root = vim.trim(vim.fn.system("git rev-parse --show-toplevel"))
  if vim.v.shell_error ~= 0 or root == "" then
    return nil
  end
  return root .. "/" .. rel
end

vim.keymap.set('n', '<leader>p', function()
  vim.fn.setreg("+", real_path_for_current_buffer() or vim.fn.expand("%:p"))
end, { desc = 'Copy absolute path' })

vim.keymap.set('n', '<leader>P', function()
  local abs = real_path_for_current_buffer()
  local rel = abs and vim.fn.fnamemodify(abs, ":~:.") or vim.fn.fnamemodify(vim.fn.expand("%"), ":~:.")
  vim.fn.setreg("+", rel)
end, { desc = 'Copy relative path' })

vim.keymap.set('n', '<leader>nf', function()
  local real = real_path_for_current_buffer()
  if not real then
    vim.notify('Not in a Neogit commit-preview buffer', vim.log.levels.WARN)
    return
  end
  local cursor = vim.api.nvim_win_get_cursor(0)
  vim.cmd('edit ' .. vim.fn.fnameescape(real))
  -- The historical version can have a different line count/content than
  -- HEAD, so clamp to whatever's actually in the real file.
  local line = math.min(cursor[1], vim.api.nvim_buf_line_count(0))
  local line_text = vim.api.nvim_buf_get_lines(0, line - 1, line, false)[1] or ""
  local col = math.min(cursor[2], #line_text)
  pcall(vim.api.nvim_win_set_cursor, 0, { line, col })
end, { desc = 'Open real file from Neogit commit preview' })

-- Per-worktree scratch notes, kept in ~/notes/ so they survive both editor
-- restarts and /tmp getting cleared on reboot. One file per worktree root
-- (not per branch) since a worktree checkout IS effectively the branch in
-- this workflow.
local function notes_path()
  local root = vim.trim(vim.fn.system("git rev-parse --show-toplevel"))
  local key = (vim.v.shell_error == 0 and root ~= "") and vim.fn.fnamemodify(root, ":t")
      or vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
  key = key:gsub("[^%w%-_.]", "-")
  local notes_dir = vim.fs.joinpath(vim.uv.os_homedir(), "notes")
  vim.fn.mkdir(notes_dir, "p")
  return vim.fs.joinpath(notes_dir, key .. "-notes.md")
end

-- Track cursor position for notes files ourselves rather than relying on
-- Neovim's native '\" mark restore -- that's still subject to 'shada's
-- `'50` remembered-files cap and silently drops entries once you've edited
-- enough other files, which would be an easy way to lose this quietly.
local notes_cursor_cache_path = vim.fs.joinpath(vim.fn.stdpath("state"), "notes_cursor.json")

local function read_notes_cursor_cache()
  local f = io.open(notes_cursor_cache_path, "r")
  if not f then
    return {}
  end
  local content = f:read("*a")
  f:close()
  if content == "" then
    return {}
  end
  local ok, data = pcall(vim.json.decode, content)
  if not ok or type(data) ~= "table" then
    return {}
  end
  return data
end

local function save_notes_cursor(path, cursor)
  local data = read_notes_cursor_cache()
  data[path] = { cursor[1], cursor[2] }
  local f = io.open(notes_cursor_cache_path, "w")
  if not f then
    return
  end
  f:write(vim.json.encode(data))
  f:close()
end

-- Safety net for quitting outright while the notes float is still open and
-- was never otherwise left (BufWinLeave doesn't reliably fire for the last
-- window closed on :qa).
-- Also autosaves any dirty notes buffer on the way out -- covers `:qa`
-- (bang skips the usual "unsaved changes" prompt, so without this an edit
-- would just be silently discarded) as well as a notes buffer left dirty
-- and hidden (bufhidden/'hidden' keeps it loaded but off-screen) from
-- earlier in the session.
vim.api.nvim_create_autocmd("VimLeavePre", {
  callback = function()
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      local name = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(win))
      if name:match("%-notes%.md$") then
        pcall(save_notes_cursor, name, vim.api.nvim_win_get_cursor(win))
      end
    end
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].modified
          and vim.api.nvim_buf_get_name(buf):match("%-notes%.md$") then
        pcall(vim.api.nvim_buf_call, buf, function() vim.cmd("write") end)
      end
    end
  end,
})

vim.keymap.set('n', '<leader>md', function()
  local path = notes_path()
  local is_new = vim.fn.filereadable(path) == 0

  local buf = vim.fn.bufadd(path)
  local loaded_ok, load_err = pcall(vim.fn.bufload, buf)
  if not loaded_ok then
    vim.notify("Couldn't open notes: " .. tostring(load_err), vim.log.levels.ERROR)
    return
  end

  if is_new then
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "# Notes", "" })
    local write_ok, write_err = pcall(vim.api.nvim_buf_call, buf, function() vim.cmd("write") end)
    if not write_ok then
      vim.notify("Couldn't save new notes file: " .. tostring(write_err), vim.log.levels.ERROR)
      return
    end
    vim.notify("Created " .. path)
  end

  local width = math.floor(vim.o.columns * 0.9)
  local height = math.floor(vim.o.lines * 0.8)
  local notes_win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    col = math.floor((vim.o.columns - width) / 2),
    row = math.floor((vim.o.lines - height) / 2),
    style = "minimal",
    border = "rounded",
    title = " Notes ",
    title_pos = "center",
  })
  -- render-markdown pads checkbox/bullet icons with a highlight it expects
  -- to match the surrounding background (default: 'Normal'), and it only
  -- auto-switches that to NormalFloat for buftype=nofile scratch buffers --
  -- notes.md is a real file buffer, so that built-in override doesn't
  -- apply. Remap Normal -> NormalFloat for just this window instead of
  -- changing render-markdown's global config, which would break the match
  -- for any regular, non-floating markdown buffer.
  vim.wo[notes_win].winhighlight = "Normal:NormalFloat"
  vim.wo[notes_win].wrap = true
  vim.wo[notes_win].linebreak = true

  local saved = read_notes_cursor_cache()[path]
  if saved then
    local line = math.min(saved[1], vim.api.nvim_buf_line_count(buf))
    local line_text = vim.api.nvim_buf_get_lines(buf, line - 1, line, false)[1] or ""
    local col = math.min(saved[2], #line_text)
    pcall(vim.api.nvim_win_set_cursor, 0, { line, col })
  end

  vim.api.nvim_create_autocmd("BufWinLeave", {
    buffer = buf,
    once = true,
    callback = function()
      pcall(save_notes_cursor, path, vim.api.nvim_win_get_cursor(0))
      -- Still the current buffer/window at this point (BufWinLeave fires
      -- just before leaving), so a plain :write covers however you left --
      -- q, <Esc>, or switching windows some other way.
      if vim.bo[buf].modified then
        pcall(vim.cmd, "write")
      end
    end,
  })

  vim.keymap.set('n', 'q', '<cmd>close<cr>', { buffer = buf, silent = true })
  vim.keymap.set('n', '<Esc>', '<cmd>close<cr>', { buffer = buf, silent = true })
end, { desc = "Open this worktree's notes.md (floating)" })

-- Floating terminal, toggled by the same key: hides (doesn't kill) the
-- shell on repeat presses so it keeps running in the background, same as
-- switching away from a regular terminal window and back. Only cd's into
-- the current buffer's directory on first creation -- re-toggling later
-- doesn't yank a running shell out from under whatever it's doing.
local float_term = { buf = nil, win = nil, scrollback = false }
local toggle_float_term

-- Geometry is derived from the editor's current size, so it has to be
-- recomputed rather than captured once: resizing the tmux pane nvim lives
-- in changes vim.o.columns/lines, but a float keeps whatever size and
-- position it was opened with until something tells it otherwise.
local function float_term_config(scrollback)
  local width = math.floor(vim.o.columns * 0.9)
  local height = math.floor(vim.o.lines * 0.8)
  return {
    relative = "editor",
    width = width,
    height = height,
    col = math.floor((vim.o.columns - width) / 2),
    row = math.floor((vim.o.lines - height) / 2),
    style = "minimal",
    border = "rounded",
    title = scrollback and " Terminal - scrollback (q to resume) " or " Terminal ",
    title_pos = "center",
  }
end

-- Terminal mode always renders the live screen, so viewing scrollback
-- necessarily means dropping to normal mode -- which is what the mouse
-- wheel does on its own (see :h terminal-mouse: with no mouse reporting
-- from the shell, the wheel event steals terminal focus). Rather than
-- fight that, treat normal mode in this buffer as tmux's copy-mode: the
-- title says so, and getting back to the prompt is automatic instead of
-- a manual `i`.
local function term_resume()
  if not (float_term.buf and vim.api.nvim_buf_is_valid(float_term.buf)) then
    return
  end
  -- The buffer is a plain scratch one until jobstart() attaches the shell,
  -- and goes inert again once the shell exits; startinsert would mean
  -- ordinary insert mode in both cases.
  if vim.bo[float_term.buf].buftype ~= 'terminal' then
    return
  end
  if float_term.win and vim.api.nvim_win_is_valid(float_term.win) and vim.api.nvim_get_current_win() == float_term.win then
    -- Scheduled because startinsert doesn't stick when it's issued from
    -- inside a mapping or an autocmd -- the pending mode change is
    -- discarded when the event that triggered it finishes.
    vim.schedule(function()
      -- Entering terminal mode snaps back to the live screen on its own.
      vim.cmd('startinsert')
    end)
  end
end

local function float_term_setup(buf)
  -- Terminal mode passes every key straight to the shell (that's the
  -- point), so the toggle needs its own buffer-local terminal-mode
  -- binding to be reachable without dropping to normal mode first via
  -- <C-\><C-n>. A single chord rather than a <leader> sequence, so it's
  -- both fast and not something you'd plausibly type into the shell.
  vim.keymap.set('t', '<C-t>', toggle_float_term, { buffer = buf, desc = 'Toggle floating terminal' })

  -- tmux exits copy-mode on q; <Esc> is the same reflex here.
  vim.keymap.set('n', 'q', term_resume, { buffer = buf, desc = 'Resume typing in the terminal' })
  vim.keymap.set('n', '<Esc>', term_resume, { buffer = buf, desc = 'Resume typing in the terminal' })

  local group = vim.api.nvim_create_augroup('FloatTermScrollback', { clear = true })

  -- Scrolling back down to the bottom means you're done reading, so hand
  -- the keyboard back to the shell. This is also what makes an accidental
  -- wheel nudge at the prompt a no-op: focus is lost and restored before
  -- you can type into the wrong mode.
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

  -- Re-focusing the float should type, not navigate.
  vim.api.nvim_create_autocmd({ 'BufEnter', 'WinEnter' }, {
    group = group,
    buffer = buf,
    callback = term_resume,
    desc = 'Start typing when the floating terminal regains focus',
  })

  -- Keep the title honest about which of the two modes you're in.
  vim.api.nvim_create_autocmd({ 'TermEnter', 'TermLeave' }, {
    group = group,
    buffer = buf,
    callback = function(ev)
      float_term.scrollback = ev.event == 'TermLeave'
      if float_term.win and vim.api.nvim_win_is_valid(float_term.win) then
        vim.api.nvim_win_set_config(float_term.win, float_term_config(float_term.scrollback))
      end
    end,
    desc = 'Label the floating terminal when it is showing scrollback',
  })
end

function toggle_float_term()
  if float_term.win and vim.api.nvim_win_is_valid(float_term.win) then
    vim.api.nvim_win_hide(float_term.win)
    float_term.win = nil
    return
  end

  -- Must read this before opening/switching to the terminal window below --
  -- once that's current, % refers to the terminal buffer, not this one.
  local dir = vim.fn.expand('%:p:h')
  if dir == '' or vim.fn.isdirectory(dir) == 0 then
    dir = vim.fn.getcwd()
  end

  local is_new = not (float_term.buf and vim.api.nvim_buf_is_valid(float_term.buf))

  if is_new then
    float_term.buf = vim.api.nvim_create_buf(false, true)
    vim.bo[float_term.buf].bufhidden = 'hide'
    float_term_setup(float_term.buf)
  end

  float_term.win = vim.api.nvim_open_win(float_term.buf, true, float_term_config())

  -- A shell has no use for the global scrolloff, and at this config's
  -- value it would shove the live prompt into the middle of the float the
  -- moment the wheel drops you into normal mode.
  vim.wo[float_term.win].scrolloff = 0
  vim.wo[float_term.win].sidescrolloff = 0

  if is_new then
    vim.fn.jobstart(vim.o.shell, { term = true, cwd = dir })
  end

  vim.cmd('startinsert')
end

vim.keymap.set('n', '<C-t>', toggle_float_term, { desc = 'Toggle floating terminal' })

-- Without this the float keeps its old geometry after the surrounding tmux
-- pane is resized, which leaves the shell's pty at a stale size (and the
-- window itself hanging off the edge when the pane shrank).
vim.api.nvim_create_autocmd('VimResized', {
  group = vim.api.nvim_create_augroup('FloatTermResize', { clear = true }),
  callback = function()
    if float_term.win and vim.api.nvim_win_is_valid(float_term.win) then
      vim.api.nvim_win_set_config(float_term.win, float_term_config(float_term.scrollback))
    end
  end,
  desc = 'Keep the floating terminal sized to the editor',
})

-- toggles
vim.keymap.set('n', '<leader>lb', function()
  vim.wo.wrap = not vim.wo.wrap
  vim.wo.linebreak = vim.wo.wrap
end, { desc = 'Toggle wrap + linebreak' })

-- lsp stuff
vim.keymap.set('n', '<leader>e', vim.diagnostic.open_float, { desc = 'Show diagnostic' })
vim.keymap.set('i', '<C-Space>', function() vim.lsp.buf.signature_help({ border = 'rounded', max_width = 80 }) end,
  { desc = 'Signature help' })

vim.api.nvim_create_autocmd('LspAttach', {
  callback = function(ev)
    local map = function(keys, fn, desc)
      vim.keymap.set('n', keys, fn, { buffer = ev.buf, desc = desc })
    end
    map('gd', vim.lsp.buf.definition, 'Go to definition')
    map('gD', vim.lsp.buf.declaration, 'Go to declaration')
    map('gr', vim.lsp.buf.references, 'Go to references')
    map('gi', vim.lsp.buf.implementation, 'Go to implementation')
    map('K', function() vim.lsp.buf.hover({ border = 'rounded', max_width = 80 }) end, 'Hover docs')
    map('<leader>rn', vim.lsp.buf.rename, 'Rename symbol')
    map('<leader>ca', vim.lsp.buf.code_action, 'Code action')
    map('[d', function() vim.diagnostic.jump({ count = -1, float = { border = 'rounded' } }) end, 'Prev diagnostic')
    map(']d', function() vim.diagnostic.jump({ count = 1, float = { border = 'rounded' } }) end, 'Next diagnostic')
  end,
})

-- epic void register trick
vim.keymap.set("x", "<leader>p", [["_dP]])

-- close the current buffer without closing the window
vim.keymap.set('n', '<Tab>', '<cmd>b#<cr>')


-- scrolling
vim.keymap.set('n', '<C-d>', '<C-d>zz', { desc = 'Scroll down and center' })
vim.keymap.set('n', '<C-u>', '<C-u>zz', { desc = 'Scroll up and center' })
vim.keymap.set('n', 'j', 'jzz', { desc = 'Down and center' })
vim.keymap.set('n', 'k', 'kzz', { desc = 'Up and center' })
vim.keymap.set('n', 'n', 'nzz', { desc = 'Next match and center' })
vim.keymap.set('n', 'N', 'Nzz', { desc = 'Prev match and center' })

vim.keymap.set('n', '<leader>gx', '<cmd>tabclose<cr>', { desc = 'Close tab' })
vim.keymap.set('n', '<leader>gn', '<cmd>tabnew<cr>', { desc = 'New tab' })

-- noice
vim.keymap.set('n', '<leader>nd', '<cmd>Noice dismiss<cr>', { desc = 'Dismiss Noice toasts' })
vim.keymap.set('n', '<leader>na', '<cmd>Noice all<cr>', { desc = 'View all messages' })
vim.keymap.set('n', '<leader>nl', '<cmd>Noice last<cr>', { desc = 'View last message' })

-- window management
vim.keymap.set('n', '<leader>w|', vim.cmd.vsplit)
vim.keymap.set('n', '<leader>w-', vim.cmd.split)
vim.keymap.set('n', '<leader>wd', vim.cmd.close)

-- window navigation
vim.keymap.set('n', '<leader>wn', '<C-w>w')
vim.keymap.set('n', '<leader>wh', '<C-w>h')
vim.keymap.set('n', '<leader>wj', '<C-w>j')
vim.keymap.set('n', '<leader>wk', '<C-w>k')
vim.keymap.set('n', '<leader>wl', '<C-w>l')

-- window resizing
vim.keymap.set('n', '<C-Up>', '<cmd>resize +5<cr>', { desc = 'Increase height' })
vim.keymap.set('n', '<C-Down>', '<cmd>resize -5<cr>', { desc = 'Decrease height' })
vim.keymap.set('n', '<C-Left>', '<cmd>vertical resize -5<cr>', { desc = 'Decrease width' })
vim.keymap.set('n', '<C-Right>', '<cmd>vertical resize +5<cr>', { desc = 'Increase width' })

-- telescope
vim.keymap.set('n', '<leader>fn', function()
  local dir = vim.fn.getcwd()
  require('telescope.builtin').find_files({
    prompt_title = 'Find files in ' .. vim.fn.fnamemodify(dir, ':~'),
    cwd = dir,
  })
end, { desc = 'Find files in cwd' })

vim.keymap.set('n', '<leader>dn', function()
  local root = vim.fn.getcwd()
  require('telescope.builtin').find_files({
    prompt_title = 'Find directories (from ' .. vim.fn.fnamemodify(root, ':~') .. ')',
    find_command = { 'fd', '--type', 'd', '--base-directory', root },
    cwd = root,
  })
end, { desc = 'Find directory in cwd' })


-- yazi
vim.keymap.set('n', '<leader>no', '<cmd>Yazi<cr>', { desc = 'Reveal current file' })
local function explorer_root()
  local root = vim.fn.systemlist('git rev-parse --show-toplevel')[1]
  return (vim.v.shell_error == 0 and root) or vim.fn.getcwd()
end

vim.keymap.set('n', '<leader>nr', function()
  require('yazi').yazi(nil, explorer_root())
end, { desc = 'Open explorer at git root' })

vim.keymap.set('n', '<leader>ne', function()
  local dir = vim.g.yazi_last_directory
  if not dir or vim.fn.isdirectory(dir) == 0 then
    dir = explorer_root()
  end
  require('yazi').yazi(nil, dir)
end, { desc = 'Open explorer where it was last closed' })

-- todos
local function toggle_todo_line(line)
  if line:match('%[x%]') then
    return (line:gsub('%[x%]', '[ ]', 1))
  elseif line:match('%[ %]') then
    return (line:gsub('%[ %]', '[x]', 1))
  end
  return line
end

local function add_todo_line(line)
  if line:match('^%s*%-%s*%[[ xX]%]') then
    return line -- already a checkbox, leave it alone
  end
  if line:match('^%s*$') then
    return '- [ ] '
  end
  return '- [ ] ' .. line
end

-- '< and '> only get updated to the just-made selection's bounds once you
-- actually *leave* Visual mode -- and a Lua function bound straight to a
-- visual-mode keymap runs while still IN Visual mode (mode() == 'v'/'V'),
-- before that update happens, so line("'<")/line("'>") read stale/zeroed
-- marks. The classic fix: map to a literal `:` command instead of a Lua
-- function. Pressing `:` from Visual mode is itself what makes Vim leave
-- Visual mode and set the marks -- <C-u> then clears the `'<,'>` range
-- Vim auto-inserts on the command line, since we read the marks ourselves.
local function apply_to_visual_selection(transform)
  local start_line = vim.fn.line("'<")
  local end_line = vim.fn.line("'>")
  for lnum = start_line, end_line do
    vim.fn.setline(lnum, transform(vim.fn.getline(lnum)))
  end
end

vim.keymap.set('n', '<leader>x', function()
  vim.api.nvim_set_current_line(toggle_todo_line(vim.api.nvim_get_current_line()))
end, { desc = 'Toggle todo' })

_G.__todo_toggle_range = function() apply_to_visual_selection(toggle_todo_line) end
vim.keymap.set('v', '<leader>x', ':<C-u>lua __todo_toggle_range()<CR>',
  { silent = true, desc = 'Toggle todo (selection)' })

vim.keymap.set('n', '<leader>td', function()
  vim.api.nvim_set_current_line(add_todo_line(vim.api.nvim_get_current_line()))
end, { desc = 'Add todo' })

_G.__todo_add_range = function() apply_to_visual_selection(add_todo_line) end
vim.keymap.set('v', '<leader>td', ':<C-u>lua __todo_add_range()<CR>',
  { silent = true, desc = 'Add todo (selection)' })

-- folding
vim.o.foldmethod = 'expr'
-- Default to treesitter folding
vim.o.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
-- Prefer LSP folding if client supports it
vim.api.nvim_create_autocmd('LspAttach', {
  callback = function(ev)
    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    if client:supports_method('textDocument/foldingRange') then
      local win = vim.api.nvim_get_current_win()
      vim.wo[win][0].foldexpr = 'v:lua.vim.lsp.foldexpr()'
    end
  end,
})
