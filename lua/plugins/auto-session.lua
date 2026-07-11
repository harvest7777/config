return {
  'folke/persistence.nvim',
  event = 'BufReadPre',
  opts = {},
  init = function()
    -- close diffview before saving so its tab/scratch buffers aren't
    -- included in the session (same class of issue as the old neo-tree hook)
    vim.api.nvim_create_autocmd('VimLeavePre', {
      callback = function()
        pcall(vim.cmd, 'DiffviewClose')
      end,
    })

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
