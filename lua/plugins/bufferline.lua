return {
  'akinsho/bufferline.nvim',
  version = '*',
  dependencies = 'nvim-tree/nvim-web-devicons',
  event = 'VeryLazy',
  keys = {
    { ']b',         '<cmd>BufferLineCycleNext<cr>',   desc = 'Next buffer' },
    { '[b',         '<cmd>BufferLineCyclePrev<cr>',   desc = 'Prev buffer' },
    { '<leader>bm', '<cmd>BufferLineMoveNext<cr>',    desc = 'Move buffer right' },
    { '<leader>bM', '<cmd>BufferLineMovePrev<cr>',    desc = 'Move buffer left' },
    { '<leader>bp', '<cmd>BufferLineTogglePin<cr>',   desc = 'Pin buffer' },
    { '<leader>bl', '<cmd>BufferLineCloseLeft<cr>',   desc = 'Close left' },
    { '<leader>br', '<cmd>BufferLineCloseRight<cr>',  desc = 'Close right' },
    { '<leader>bb', '<cmd>BufferLinePick<cr>',        desc = 'Pick buffer' },
    { '<leader>bd', '<cmd>BufferLinePickClose<cr>',   desc = 'Pick buffer to close' },
    { '<leader>bo', '<cmd>BufferLineCloseOthers<cr>', desc = 'Close other buffers' },
  },
  opts = {
    options = {
      -- switch to 'tabs' to list tab pages instead of open buffers
      mode = 'buffers',
      diagnostics = 'nvim_lsp',
      diagnostics_indicator = function(count, level)
        return (level:match('error') and ' ' or ' ') .. count
      end,
      separator_style = 'thin',
      indicator = { style = 'underline' },
      show_buffer_close_icons = false,
      show_close_icon = false,
      always_show_bufferline = true,
      hover = { enabled = true, delay = 200, reveal = { 'close' } },
    },
  },
}
