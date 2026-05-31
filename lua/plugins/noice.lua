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
        enabled = false,    -- kills the LSP spinner (most annoying thing)
      },
      hover = {
        enabled = false,    -- use default vim hover, noice's can be jumpy
      },
      signature = {
        enabled = false,    -- same, let your LSP plugin handle this
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
