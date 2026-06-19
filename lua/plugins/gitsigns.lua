return {
  'lewis6991/gitsigns.nvim',
  opts = {
    current_line_blame = true,
    on_attach = function(bufnr)
      local gs = require('gitsigns')
      local map = function(mode, l, r, desc)
        vim.keymap.set(mode, l, r, { buffer = bufnr, desc = desc })
      end
      map('n', ']c', gs.next_hunk, 'Next hunk')
      map('n', '[c', gs.prev_hunk, 'Prev hunk')
    end,
  },
}
