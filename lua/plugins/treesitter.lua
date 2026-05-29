return
{
  'nvim-treesitter/nvim-treesitter',
  opts = {
     highlight = { enable = true },
  },
  lazy = false,
  build = ':TSUpdate'
}
