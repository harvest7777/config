-- comment number nine
vim.g.mapleader = " "


-- bootstrap lazy.nvim
local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    'git', 'clone', '--filter=blob:none',
    'https://github.com/folke/lazy.nvim.git',
    '--branch=stable',
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require('lazy').setup('plugins') -- scans lua/plugins/ automatically
require("options")
require("keymaps")
require("lsp")

-- delete the empty startup buffer once a real file is opened
vim.api.nvim_create_autocmd({ 'BufReadPost', 'BufNewFile' }, {
  once = true,
  callback = function(ev)
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if buf ~= ev.buf
          and vim.fn.buflisted(buf) == 1
          and vim.api.nvim_buf_get_name(buf) == ''
          and not vim.bo[buf].modified
      then
        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        if #lines == 0 or (#lines == 1 and lines[1] == '') then
          pcall(vim.api.nvim_buf_delete, buf, {})
        end
      end
    end
  end,
})

vim.lsp.enable('lua_ls')
vim.lsp.enable('pyright')
vim.lsp.enable('yamlls')
vim.lsp.enable('jsonnet_ls')
vim.lsp.enable('bashls')
vim.lsp.enable('clangd')
