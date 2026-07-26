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
vim.keymap.set('n', '<leader>nf', '<cmd>Yazi<cr>', { desc = 'Open file explorer' })
vim.keymap.set('n', '<leader>ne', '<cmd>Yazi toggle<cr>', { desc = 'Toggle file explorer' })
vim.keymap.set('n', '<leader>no', '<cmd>Yazi<cr>', { desc = 'Reveal current file' })
vim.keymap.set('n', '<leader>nr', function()
  local root = vim.fn.systemlist('git rev-parse --show-toplevel')[1]
  local dir = (vim.v.shell_error == 0 and root) or vim.fn.getcwd()
  require('yazi').yazi(nil, dir)
end, { desc = 'Open explorer at git root' })

-- todos
vim.keymap.set('n', '<leader>x', function()
  local line = vim.api.nvim_get_current_line()
  if line:match('%[x%]') then
    vim.api.nvim_set_current_line((line:gsub('%[x%]', '[ ]', 1)))
  elseif line:match('%[ %]') then
    vim.api.nvim_set_current_line((line:gsub('%[ %]', '[x]', 1)))
  end
end, { desc = 'Toggle todo' })

vim.keymap.set('n', '<leader>td', function()
  local line = vim.api.nvim_get_current_line()
  if line:match('^%s*$') then
    vim.api.nvim_set_current_line('- [ ] ')
  else
    vim.api.nvim_set_current_line('- [ ] ' .. line)
  end
end, { desc = 'Add todo' })

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
