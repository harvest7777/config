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

-- lsps
vim.lsp.config('lua_ls', {
  cmd = { 'lua-language-server' },
  filetypes = { 'lua' },
  root_markers = { { '.luarc.json', '.luarc.jsonc' }, '.git' },
  settings = {
    Lua = {
      runtime = { version = 'LuaJIT' },
      workspace = {
        library = vim.api.nvim_get_runtime_file("", true),
        checkThirdParty = false,
      },
      diagnostics = {
        globals = { 'vim' },
      },
    }
  }
})

vim.lsp.enable('lua_ls')

vim.lsp.config('pyright', {
  cmd = { 'pyright-langserver', '--stdio' },
  filetypes = { 'python' },
  root_markers = { 'pyproject.toml', 'setup.py', 'requirements.txt', '.git' },
  settings = {
    python = {
      analysis = {
        typeCheckingMode = 'basic',
      }
    }
  }
})

vim.lsp.enable('pyright')

vim.lsp.config('yamlls', {
  cmd = { 'yaml-language-server', '--stdio' },
  filetypes = { 'yaml', 'yml' },
  root_markers = { '.git' },
  settings = {
    yaml = {
      schemas = {
      }
    }
  }
})

vim.lsp.enable('yamlls')

vim.lsp.config('jsonnet_ls', {
  cmd = { vim.fn.expand('~/go/bin/jsonnet-language-server'), '-t' },
  filetypes = { 'jsonnet', 'libsonnet' },
  root_markers = { 'jsonnetfile.json', '.git' },
})

vim.lsp.enable('jsonnet_ls')

vim.lsp.config('bashls', {
  cmd = { 'bash-language-server', 'start' },
  filetypes = { 'sh', 'bash' },
  root_markers = { '.git' },
})

vim.lsp.enable('bashls')
