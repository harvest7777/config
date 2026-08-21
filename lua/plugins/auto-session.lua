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
          vim.schedule(function()
            -- clear flash.nvim label patterns saved in session to avoid E486
            vim.cmd('nohlsearch')

            -- yazi.nvim deliberately skips its directory-buffer hijack while a
            -- session is loading (:h SessionLoad-variable), so a directory that
            -- was open when the session was saved comes back as a stray listed
            -- buffer -- which then gets re-saved on exit, making it permanent.
            -- Wipe directory buffers once the restore has settled.
            for _, buf in ipairs(vim.api.nvim_list_bufs()) do
              local name = vim.api.nvim_buf_get_name(buf)
              if name ~= '' and vim.fn.isdirectory(name) == 1 then
                pcall(vim.api.nvim_buf_delete, buf, { force = true })
              end
            end
          end)
        end
      end,
    })
  end,
}
