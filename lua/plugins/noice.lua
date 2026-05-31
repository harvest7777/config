return {
  "folke/noice.nvim",
  event = "VeryLazy",
  opts = {
    messages = {
      enabled = true,
      view = "mini",        -- bottom-right corner instead of big popup
      view_error = "mini",
      view_warn = "mini",
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
      bottom_search = true,         -- classic / search at the bottom
      command_palette = false,
      long_message_to_split = true, -- long messages go to a split instead of popup
      inc_rename = false,
    },
    routes = {
      -- swallow "written" messages
      { filter = { event = "msg_show", find = "written" }, opts = { skip = true } },
      -- swallow search count like [1/45]
      { filter = { event = "msg_show", find = "%d+L, %d+B" }, opts = { skip = true } },
      -- swallow "already at newest change" etc
      { filter = { event = "msg_show", kind = "wmsg" }, opts = { skip = true } },
    },
  },
}
