return {
  'mikavilpas/yazi.nvim',
  event = 'VeryLazy',
  opts = {
    open_for_directories = true,
    ui = {
      backdrop = 100,
    },
    highlight_hovered_buffers_in_same_directory = false,
    keymaps = {
      show_help = '<f1>',
      open_file_in_vertical_split = '<c-v>',
      open_file_in_horizontal_split = '<c-x>',
      open_file_in_tab = '<c-t>',
      grep_in_directory = '<c-s>',
      cycle_open_buffers = '<tab>',
      copy_relative_path_to_clipboard = '<c-y>',
    },
  },
}
