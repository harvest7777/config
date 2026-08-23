-- remember where yazi was when it was last closed, so <leader>ne can resume there
local function remember_last_directory(state)
  local dir = state and state.last_directory and state.last_directory.filename
  if dir and vim.fn.isdirectory(dir) == 1 then
    vim.g.yazi_last_directory = dir
  end
end

return {
  'mikavilpas/yazi.nvim',
  event = 'VeryLazy',
  opts = {
    open_for_directories = true,
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
    hooks = {
      yazi_closed_successfully = function(_, _, state)
        remember_last_directory(state)
      end,
      yazi_opened_multiple_files = function(chosen_files, config, state)
        remember_last_directory(state)
        require('yazi.openers').open_multiple_files(chosen_files, config, state)
      end,
    },
  },
}
