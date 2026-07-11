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
vim.keymap.set('n', '<leader>p', '<cmd>let @+ = expand("%:p")<cr>', { desc = 'Copy absolute path' })
vim.keymap.set('n', '<leader>P', '<cmd>let @+ = fnamemodify(expand("%"), ":~:.")<cr>', { desc = 'Copy relative path' })

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
    vim.api.nvim_set_current_line('[ ] ')
  else
    vim.api.nvim_set_current_line('[ ] ' .. line)
  end
  vim.cmd('startinsert!')
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
