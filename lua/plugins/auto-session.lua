return {
  'folke/persistence.nvim',
  event = 'BufReadPre',
  opts = {},
  init = function()
    -- close neogit before saving so its scratch status buffer isn't
    -- captured in the session in place of whatever real file was open
    -- before it took over the window (same class of issue as the old
    -- neo-tree hook). Neogit's status buffer is "replace" kind, so closing
    -- it restores the real underlying buffer into the window.
    vim.api.nvim_create_autocmd('VimLeavePre', {
      callback = function()
        if package.loaded['neogit'] then
          pcall(require('neogit').close)
        end
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
