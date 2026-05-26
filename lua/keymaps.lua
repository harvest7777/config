-- misc 
vim.keymap.set('n', '<leader>qa', '<cmd>qa<cr>', { desc = 'Quit all' })
vim.keymap.set('n', '<leader>qq', '<cmd>q<cr>',  { desc = 'Quit' })
vim.keymap.set('n', '<leader>qw', '<cmd>wq<cr>', { desc = 'Save and quit' })

-- window management
vim.keymap.set('n', '<leader>w|', vim.cmd.vsplit)
vim.keymap.set('n', '<leader>w-', vim.cmd.split)
vim.keymap.set('n', '<leader>wx', vim.cmd.close)

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
local tb = require('telescope.builtin')
vim.keymap.set('n', '<leader>ff', tb.find_files, { desc = 'Find files' })
vim.keymap.set('n', '<leader>gf', tb.git_files, { desc = 'Find git files' })
vim.keymap.set('n', '<leader>fg', tb.live_grep,  { desc = 'Live grep' })
vim.keymap.set('n', '<leader>fb', tb.buffers,    { desc = 'Buffers' })
vim.keymap.set('n', '<leader>fh', tb.help_tags,  { desc = 'Help tags' })

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

-- neotree
vim.keymap.set('n', '<leader>nf', '<cmd>Neotree focus<cr>',  { desc = 'Focus explorer' })
vim.keymap.set('n', '<leader>ne', '<cmd>Neotree toggle<cr>',   { desc = 'Show explorer' })
vim.keymap.set('n', '<leader>nr', function()
  local root = vim.fn.systemlist('git rev-parse --show-toplevel')[1]
  local dir = (vim.v.shell_error == 0 and root) or vim.fn.getcwd()
  vim.cmd('Neotree toggle dir=' .. dir)
end, { desc = 'File explorer' })
