-- lazygit
-- local function goto_editor_win()
--   for _, win in ipairs(vim.api.nvim_list_wins()) do
--     local cfg = vim.api.nvim_win_get_config(win)
--     if cfg.relative == '' then
--       vim.api.nvim_set_current_win(win)
--       return
--     end
--   end
-- end
-- _G.goto_editor_win = goto_editor_win
--
-- local function toggle_lazygit()
--   if _G.lazygit_buf and vim.api.nvim_buf_is_valid(_G.lazygit_buf) then
--     vim.api.nvim_buf_delete(_G.lazygit_buf, { force = true })
--     _G.lazygit_buf = nil
--     return
--   end
--   goto_editor_win()
--   local buf = vim.api.nvim_create_buf(false, true)
--   local width = math.floor(vim.o.columns * 0.95)
--   local height = math.floor(vim.o.lines * 0.95)
--   vim.api.nvim_open_win(buf, true, {
--     relative = "editor",
--     width = width,
--     height = height,
--     col = math.floor((vim.o.columns - width) / 2),
--     row = math.floor((vim.o.lines - height) / 2),
--     style = "minimal",
--     border = "rounded",
--   })
--   vim.fn.jobstart("lazygit", {
--     term = true,
--     on_exit = function()
--       if vim.api.nvim_buf_is_valid(buf) then
--         vim.api.nvim_buf_delete(buf, { force = true })
--       end
--       _G.lazygit_buf = nil
--     end,
--   })
--   _G.lazygit_buf = buf
--   vim.cmd("startinsert")
-- end
-- vim.keymap.set("n", "<leader>gg", toggle_lazygit)

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
vim.api.nvim_create_autocmd("VimLeavePre", {
  callback = function()
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      local name = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(win))
      if name:match("%-notes%.md$") then
        pcall(save_notes_cursor, name, vim.api.nvim_win_get_cursor(win))
      end
    end
  end,
})

vim.keymap.set('n', '<leader>md', function()
  local path = notes_path()
  local is_new = vim.fn.filereadable(path) == 0

  local buf = vim.fn.bufadd(path)
  vim.fn.bufload(buf)

  if is_new then
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "# Notes", "" })
    vim.api.nvim_buf_call(buf, function() vim.cmd("write") end)
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
local float_term = { buf = nil, win = nil }

local function toggle_float_term()
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

  local width = math.floor(vim.o.columns * 0.9)
  local height = math.floor(vim.o.lines * 0.8)
  local is_new = not (float_term.buf and vim.api.nvim_buf_is_valid(float_term.buf))

  if is_new then
    float_term.buf = vim.api.nvim_create_buf(false, true)
    vim.bo[float_term.buf].bufhidden = 'hide'
    -- Terminal mode passes every key straight to the shell (that's the
    -- point), so the toggle needs its own buffer-local terminal-mode
    -- binding to be reachable without dropping to normal mode first via
    -- <C-\><C-n>. A single chord rather than a <leader> sequence, so it's
    -- both fast and not something you'd plausibly type into the shell.
    vim.keymap.set('t', '<C-t>', toggle_float_term, { buffer = float_term.buf, desc = 'Toggle floating terminal' })
  end

  float_term.win = vim.api.nvim_open_win(float_term.buf, true, {
    relative = "editor",
    width = width,
    height = height,
    col = math.floor((vim.o.columns - width) / 2),
    row = math.floor((vim.o.lines - height) / 2),
    style = "minimal",
    border = "rounded",
    title = " Terminal ",
    title_pos = "center",
  })

  if is_new then
    vim.fn.jobstart(vim.o.shell, { term = true, cwd = dir })
  end

  vim.cmd('startinsert')
end

vim.keymap.set('n', '<C-t>', toggle_float_term, { desc = 'Toggle floating terminal' })

-- Builds a PR/MR link for the current branch purely from local git state
-- (remote URL + branch name) -- no HTTP requests, just string construction.
-- Any host that isn't github.com/bitbucket.org/*gitlab* is assumed to be a
-- self-hosted Bitbucket Server (Stash) instance.
local function pr_link()
  local remote = vim.trim(vim.fn.system("git remote get-url origin"))
  if vim.v.shell_error ~= 0 or remote == "" then
    vim.notify("No 'origin' remote found", vim.log.levels.WARN)
    return nil
  end

  local branch = vim.trim(vim.fn.system("git rev-parse --abbrev-ref HEAD"))
  if vim.v.shell_error ~= 0 or branch == "" or branch == "HEAD" then
    vim.notify("Not on a branch (detached HEAD?)", vim.log.levels.WARN)
    return nil
  end

  remote = remote:gsub("%.git$", "")

  local host, path
  if remote:match("^git@") then
    host, path = remote:match("^git@([^:]+):(.+)$")
  elseif remote:match("^ssh://") then
    host, path = remote:match("^ssh://[^@/]+@([^:/]+):?%d*/(.+)$")
  elseif remote:match("^https?://") then
    host, path = remote:match("^https?://([^/]+)/(.+)$")
    if host then
      host = host:gsub("^.-@", "") -- drop any embedded credentials
    end
  end

  if not (host and path) then
    vim.notify("Couldn't parse remote URL: " .. remote, vim.log.levels.WARN)
    return nil
  end

  local encoded_branch = branch:gsub("[^%w%-%._/]", function(c)
    return string.format("%%%02X", string.byte(c))
  end)

  if host == "github.com" then
    return ("https://github.com/%s/pull/new/%s"):format(path, encoded_branch)
  elseif host == "bitbucket.org" then
    return ("https://bitbucket.org/%s/pull-requests/new?source=%s&t=1"):format(path, encoded_branch)
  elseif host:find("gitlab", 1, true) then
    return ("https://%s/%s/-/merge_requests/new?merge_request[source_branch]=%s"):format(host, path, encoded_branch)
  else
    -- Bitbucket Server / Stash. HTTPS clone URLs route through
    -- /scm/<PROJECT>/<repo>; strip that to get PROJECT/repo.
    path = path:gsub("^scm/", "")
    local project, repo = path:match("^([^/]+)/(.+)$")
    if not (project and repo) then
      vim.notify("Couldn't parse project/repo from: " .. path, vim.log.levels.WARN)
      return nil
    end
    return ("https://%s/projects/%s/repos/%s/pull-requests?create&sourceBranch=refs/heads/%s")
        :format(host, project, repo, encoded_branch)
  end
end

vim.keymap.set('n', '<leader>gp', function()
  local link = pr_link()
  if link then
    vim.fn.setreg("+", link)
    vim.notify("Copied: " .. link)
  end
end, { desc = 'Copy PR/MR link for current branch' })

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

-- grep
vim.keymap.set('n', '<leader>gn', function()
  local root = vim.fn.getcwd()
  require('telescope.builtin').live_grep({
    prompt_title = 'Live grep (from ' .. vim.fn.fnamemodify(root, ':~') .. ')',
    search_dirs = { root },
  })
end, { desc = 'Live grep in cwd' })

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
vim.keymap.set('n', '<leader>nr', function()
  local root = vim.fn.systemlist('git rev-parse --show-toplevel')[1]
  local dir = (vim.v.shell_error == 0 and root) or vim.fn.getcwd()
  require('yazi').yazi(nil, dir)
end, { desc = 'Open explorer at git root' })

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
