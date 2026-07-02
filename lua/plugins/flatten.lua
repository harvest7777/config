return
{
  'willothy/flatten.nvim',
  lazy = false,
  priority = 1001,
  opts = {
    window = { open = "current" },
    hooks = {
      pre_open = function()
        if _G.lazygit_buf and vim.api.nvim_buf_is_valid(_G.lazygit_buf) then
          vim.api.nvim_buf_delete(_G.lazygit_buf, { force = true })
          _G.lazygit_buf = nil
        end
      end,
    },
  },
}
