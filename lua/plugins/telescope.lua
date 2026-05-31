return {
  'nvim-telescope/telescope.nvim',
  dependencies = { 'nvim-lua/plenary.nvim' },
  opts = {
    defaults = {
      preview = {
        treesitter = false,  -- applies to all pickers
      },
    },
  },
}
