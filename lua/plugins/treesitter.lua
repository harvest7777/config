return {
  'neovim-treesitter/nvim-treesitter',
  dependencies = { 'neovim-treesitter/treesitter-parser-registry' },
  lazy = false,
  build = ':TSUpdate',
  config = function()
    vim.api.nvim_create_autocmd('FileType', {
      pattern = '*',
      callback = function()
        local ok = pcall(vim.treesitter.start)
        if not ok then return end
        vim.wo.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
        vim.wo.foldmethod = 'expr'
        vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
      end,
    })
  end,
}
