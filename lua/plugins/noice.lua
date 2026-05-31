return {
  "folke/noice.nvim",
  event = "VeryLazy",
  opts = {
    messages = {
      enabled = true,
      view = "mini",        -- bottom-right corner instead of big popup
      view_error = "mini",
      view_warn = "mini",
      view_history = "popup", -- view for :messages
    },
    commands = {
      all = {
        view = "popup",
        opts = { enter = true, format = "details" },
        filter = {},
      },
    },
    lsp = {
      progress = {
        enabled = false,    -- kills the LSP spinner
      },
      hover = {
        enabled = false
      },
      signature = {
        enabled = false,
      },
    },
    notify = {
      enabled = true,
      view = "mini",
    },
    presets = {
      command_palette = false,
      long_message_to_split = true, -- long messages go to a split instead of popup
      inc_rename = false,
    },
  },
}
