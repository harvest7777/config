return {
  'folke/persistence.nvim',
  event = 'BufReadPre',
  opts = {},
  init = function()
    -- auto-restore session on startup (only when opened with no file args)
    vim.api.nvim_create_autocmd('VimEnter', {
      nested = true,
      callback = function()
        if vim.fn.argc() == 0 then
          require('persistence').load()
          -- clear flash.nvim label patterns saved in session to avoid E486
          vim.schedule(function() vim.cmd('nohlsearch') end)
        end
      end,
    })
  end,
}
