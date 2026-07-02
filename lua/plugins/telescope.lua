return {
  'nvim-telescope/telescope.nvim',
  dependencies = {
    'nvim-lua/plenary.nvim',
    { 'nvim-telescope/telescope-fzf-native.nvim', build = 'make' },
  },
  config = function(_, opts)
    local telescope = require('telescope')
    telescope.setup(opts)
    telescope.load_extension('fzf')
  end,
  opts = {
    defaults = {
      preview = {
        treesitter = false,
      },
      get_selection_window = function()
        for _, win in ipairs(vim.api.nvim_list_wins()) do
          local buf = vim.api.nvim_win_get_buf(win)
          local ft = vim.api.nvim_get_option_value('filetype', { buf = buf })
          local is_float = vim.api.nvim_win_get_config(win).relative ~= ''
          if not is_float and ft ~= 'neo-tree' then
            return win
          end
        end
        return 0
      end,
    },
  },
}
