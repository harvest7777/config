return {
  'lewis6991/gitsigns.nvim',
  opts = {
    current_line_blame = false,
    preview_config = {
      border = 'rounded',
      style = 'minimal',
      row = 1,
      col = 0,
      focusable = true,
    },
    on_attach = function(bufnr)
      local gs = require('gitsigns')
      local map = function(mode, l, r, desc)
        vim.keymap.set(mode, l, r, { buffer = bufnr, desc = desc })
      end
      map('n', '<leader>hs', gs.stage_hunk, 'Stage hunk')
      map('n', '<leader>hr', gs.reset_hunk, 'Reset hunk')
      map('n', '<leader>hb', gs.blame_line, 'Blame line')
      map('v', '<leader>hs', function() gs.stage_hunk { vim.fn.line('.'), vim.fn.line('v') } end, 'Stage selected lines')
      map('v', '<leader>hr', function() gs.reset_hunk { vim.fn.line('.'), vim.fn.line('v') } end, 'Reset selected lines')
    end,
  },
}
