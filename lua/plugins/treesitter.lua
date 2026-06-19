return {
  'nvim-treesitter/nvim-treesitter',
  lazy = false,
  build = ':TSUpdate',
  main = 'nvim-treesitter',
  opts = {
    ensure_installed = 'all',
  },
}
