return {
  'folke/persistence.nvim',
  event = 'BufReadPre',
  opts = {},
  init = function()
    -- close neo-tree before saving so it's not included in the session
    vim.api.nvim_create_autocmd('VimLeavePre', {
      callback = function()
        pcall(vim.cmd, 'Neotree close')
      end,
    })

    -- auto-restore session on startup (only when opened with no file args)
    vim.api.nvim_create_autocmd('VimEnter', {
      nested = true,
      callback = function()
        if vim.fn.argc() == 0 then
          require('persistence').load()
        end
      end,
    })
  end,
}
