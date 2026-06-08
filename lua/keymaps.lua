local function get_neotree_root()
  local ok, manager = pcall(require, "neo-tree.sources.manager")
  if not ok then return nil end
  local state = manager.get_state("filesystem")
  return state and state.path or nil
end

-- lazygit
local lazygit_buf = nil
local function toggle_lazygit()
  if lazygit_buf and vim.api.nvim_buf_is_valid(lazygit_buf) then
    vim.api.nvim_buf_delete(lazygit_buf, { force = true })
    lazygit_buf = nil
    return
  end
  local buf = vim.api.nvim_create_buf(false, true)
  local width = math.floor(vim.o.columns * 0.85)
  local height = math.floor(vim.o.lines * 0.85)
  vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width, height = height,
    col = math.floor((vim.o.columns - width) / 2),
    row = math.floor((vim.o.lines - height) / 2),
    style = "minimal",
    border = "rounded",
  })
  vim.api.nvim_set_current_buf(buf)
  vim.fn.jobstart("lazygit", {
    term = true,
    on_exit = function()
      if vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_buf_delete(buf, { force = true })
      end
      lazygit_buf = nil
    end,
  })
  lazygit_buf = buf
  vim.cmd("startinsert")
end
vim.keymap.set("n", "<leader>gg", toggle_lazygit)

-- misc 
vim.keymap.set('n', '<leader>ww', '<cmd>w<cr>',  { desc = 'Write file' })
vim.keymap.set('n', '<leader>wa', '<cmd>wa<cr>', { desc = 'Write all' })
vim.keymap.set('n', '<leader>qq', '<cmd>qa!<cr>', { desc = 'Quit all' })
vim.keymap.set('n', '<leader>p', '<cmd>let @+ = expand("%:p")<cr>', { desc = 'Copy current path' })

-- lsp stuff
vim.keymap.set('n', '<leader>e', vim.diagnostic.open_float, { desc = 'Show diagnostic' })
vim.keymap.set('i', '<C-Space>', vim.lsp.buf.signature_help, { desc = 'Signature help' })

-- epic void register trick
vim.keymap.set("x", "<leader>p", [["_dP]])

-- close the current buffer without closing the window
vim.keymap.set('n', '<leader>bd', ':bp|bd #<CR>')
vim.keymap.set('n', '<leader>bb', require('telescope.builtin').buffers)
vim.keymap.set('n', '<Tab>', '<cmd>b#<cr>')


-- scrolling
vim.keymap.set('n', '<C-d>', '<C-d>zz', { desc = 'Scroll down and center' })
vim.keymap.set('n', '<C-u>', '<C-u>zz', { desc = 'Scroll up and center' })

-- noice 
vim.keymap.set('n', '<leader>nd', '<cmd>Noice dismiss<cr>', { desc = 'Dismiss Noice toasts' })
vim.keymap.set('n', '<leader>na', '<cmd>Noice all<cr>', { desc = 'View all messages' })

-- window management
vim.keymap.set('n', '<leader>w|', vim.cmd.vsplit)
vim.keymap.set('n', '<leader>w-', vim.cmd.split)
vim.keymap.set('n', '<leader>wd', vim.cmd.close)

-- window navigation
vim.keymap.set('n', '<leader>wh', '<C-w>h')
vim.keymap.set('n', '<leader>wj', '<C-w>j')
vim.keymap.set('n', '<leader>wk', '<C-w>k')
vim.keymap.set('n', '<leader>wl', '<C-w>l')
vim.keymap.set('n', '<leader>wH', '<C-w>H')
vim.keymap.set('n', '<leader>wJ', '<C-w>J')
vim.keymap.set('n', '<leader>wK', '<C-w>K')
vim.keymap.set('n', '<leader>wL', '<C-w>L')

-- window resizing
vim.keymap.set('n', '<C-Up>',    '<cmd>resize +5<cr>',          { desc = 'Increase height' })
vim.keymap.set('n', '<C-Down>',  '<cmd>resize -5<cr>',          { desc = 'Decrease height' })
vim.keymap.set('n', '<C-Left>',  '<cmd>vertical resize -5<cr>', { desc = 'Decrease width' })
vim.keymap.set('n', '<C-Right>', '<cmd>vertical resize +5<cr>', { desc = 'Increase width' })

-- telescope
vim.keymap.set('n', '<leader>fn', function()
  local dir = get_neotree_root() or vim.fn.getcwd()
  require('telescope.builtin').find_files({
    prompt_title = 'Find files in ' .. vim.fn.fnamemodify(dir, ':~'),
    cwd = dir,
  })
end, { desc = 'Find files in neo-tree root' })

-- grep
vim.keymap.set('n', '<leader>gn', function()
  local state = require('neo-tree.sources.manager').get_state('filesystem')
  local root = state and state.path or vim.fn.getcwd()

  require('telescope.builtin').live_grep({
    prompt_title = 'Live grep (from ' .. vim.fn.fnamemodify(root, ':~') .. ')',
    search_dirs = { root },
  })
end, { desc = 'Live grep in neo-tree root' })

-- then it runs neotree to that directory so it opens in the file explorer
vim.keymap.set('n', '<leader>dn', function()
  local state = require('neo-tree.sources.manager').get_state('filesystem')
  local root = state and state.path or vim.fn.getcwd()

  require('telescope.builtin').find_files({
    prompt_title = 'Find directories (from ' .. vim.fn.fnamemodify(root, ':~') .. ')',
    find_command = { 'fd', '--type', 'd', '--base-directory', root },
    cwd = root,
  })
end, { desc = 'Find Neo-tree directory' })


-- neotree
vim.keymap.set('n', '<leader>nf', '<cmd>Neotree focus<cr>',  { desc = 'Focus explorer' })
vim.keymap.set('n', '<leader>ne', '<cmd>Neotree toggle<cr>',   { desc = 'Show explorer' })
vim.keymap.set('n', '<leader>no', '<cmd>Neotree reveal_force_cwd<cr>',   { desc = 'Reveal current file' })
vim.keymap.set('n', '<leader>nr', function()
  local root = vim.fn.systemlist('git rev-parse --show-toplevel')[1]
  local dir = (vim.v.shell_error == 0 and root) or vim.fn.getcwd()
  require('neo-tree.command').execute({ dir = dir, action = 'show' })
end, { desc = 'File explorer' })

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

