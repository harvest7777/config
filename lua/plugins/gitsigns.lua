return {
  'lewis6991/gitsigns.nvim',
  opts = {
    current_line_blame = true,
    update_debounce = 50,
    on_attach = function(bufnr)
      local gs = require('gitsigns')
      local map = function(mode, l, r, desc)
        -- tset
        vim.keymap.set(mode, l, r, { buffer = bufnr, desc = desc })
      end
      map('n', ']c', gs.next_hunk, 'Next hunk')
      map('n', '[c', gs.prev_hunk, 'Prev hunk')
      map('n', '<leader>d', gs.preview_hunk_inline, 'Preview hunk inline')
    end,
  },
}
