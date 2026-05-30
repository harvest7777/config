-- misc 
vim.keymap.set('n', '<leader>ww', '<cmd>w<cr>',  { desc = 'Write file' })
vim.keymap.set('n', '<leader>wa', '<cmd>wa<cr>', { desc = 'Write all' })
vim.keymap.set('n', '<leader>qq', '<cmd>qa!<cr>', { desc = 'Quit all' })
vim.keymap.set('n', '<leader>p', '<cmd>let @+ = expand("%:p")<cr>', { desc = 'Copy current path' })

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
vim.keymap.set('n', '<C-Up>',    '<cmd>resize +2<cr>',          { desc = 'Increase height' })
vim.keymap.set('n', '<C-Down>',  '<cmd>resize -2<cr>',          { desc = 'Decrease height' })
vim.keymap.set('n', '<C-Left>',  '<cmd>vertical resize -2<cr>', { desc = 'Decrease width' })
vim.keymap.set('n', '<C-Right>', '<cmd>vertical resize +2<cr>', { desc = 'Increase width' })

-- telescope
vim.keymap.set('n', '<leader>ff', function()
  require('telescope.builtin').git_files({ 
        prompt_title = 'Find git files',
        show_untracked = true,
      })
end, { desc = 'Find git files' })
vim.keymap.set('n', '<leader>faf', function()
  require('telescope.builtin').find_files({ 
        prompt_title = 'Find all files',
        show_untracked = true,
      })
end, { desc = 'Find all files' })
vim.keymap.set('n', '<leader>fgo', function()
  require('telescope.builtin').live_grep({
        prompt_title = 'Grep in open buffers',
        grep_open_files = true,
        show_untracked = true,
      })
end, { desc = 'Grep in open buffers' })
vim.keymap.set('n', '<leader>fga', function()
  require('telescope.builtin').live_grep({ prompt_title = 'Live grep all files' })
end, { desc = 'Live grep all files' })

-- crazy ass function. basically it finds by directory with fd (brew install fd)
-- then it runs neotree to that directory so it opens in the file explorer
vim.keymap.set('n', '<leader>fd', function()
  tb.find_files({
    find_command = { 'fd', '--type', 'd' },
    attach_mappings = function(prompt_bufnr, map)
      local actions = require('telescope.actions')
      local action_state = require('telescope.actions.state')
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local dir = action_state.get_selected_entry()[1]
        vim.cmd('Neotree ' .. dir)
      end)
      return true
    end
  })
end, { desc = 'Find directory' })

-- live grep in the current netoree directory
vim.keymap.set('n', '<leader>gu', function()
  -- Get the current Neo-tree root directory
  local manager = require('neo-tree.sources.manager')
  local state = manager.get_state('filesystem')
  local root = state and state.path

  if not root then
    vim.notify('No Neo-tree directory open', vim.log.levels.WARN)
    return
  end

  require('telescope.builtin').live_grep({ search_dirs = { root } })
end, { desc = 'Grep in Neo-tree directory' })

-- neotree
vim.keymap.set('n', '<leader>nf', '<cmd>Neotree focus<cr>',  { desc = 'Focus explorer' })
vim.keymap.set('n', '<leader>ne', '<cmd>Neotree toggle<cr>',   { desc = 'Show explorer' })
vim.keymap.set('n', '<leader>no', '<cmd>Neotree reveal<cr>',   { desc = 'Reveal current file' })
vim.keymap.set('n', '<leader>nr', function()
  local root = vim.fn.systemlist('git rev-parse --show-toplevel')[1]
  local dir = (vim.v.shell_error == 0 and root) or vim.fn.getcwd()
  vim.cmd('Neotree toggle dir=' .. dir)
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

