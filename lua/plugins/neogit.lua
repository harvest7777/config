return
{
  "NeogitOrg/neogit",
  lazy = true,
  dependencies = {
    -- Only one of these is needed.
    "sindrets/diffview.nvim",   -- optional
    "esmuellert/codediff.nvim", -- optional

    -- For a custom log pager
    "m00qek/baleia.nvim", -- optional

    -- Only one of these is needed.
    "nvim-telescope/telescope.nvim", -- optional
    "ibhagwan/fzf-lua",              -- optional
    "nvim-mini/mini.pick",           -- optional
    "folke/snacks.nvim",             -- optional
  },
  cmd = "Neogit",
  keys = {
    { "<leader>gg", "<cmd>Neogit<cr>", desc = "Show Neogit UI" }
  },
  opts = {
    kind = "replace",
    commit_editor = { kind = "replace" },
    commit_select_view = { kind = "replace" },
    commit_view = { kind = "replace" },
    log_view = { kind = "replace" },
    rebase_editor = { kind = "replace" },
    reflog_view = { kind = "replace" },
    merge_editor = { kind = "replace" },
    preview_buffer = { kind = "floating_console" },
    popup = { kind = "replace" },
    stash = { kind = "replace" },
    refs_view = { kind = "replace" },
  },
  config = function(_, opts)
    require("neogit").setup(opts)

    -- Context (unchanged) lines in expanded diffs default to a shaded
    -- background; flatten them to match Normal so only +/- lines stand out.
    local function flatten_context_hl()
      vim.api.nvim_set_hl(0, "NeogitDiffContext", { link = "Normal" })
      vim.api.nvim_set_hl(0, "NeogitDiffContextHighlight", { link = "CursorLine" })
      vim.api.nvim_set_hl(0, "NeogitDiffContextCursor", { link = "Normal" })
    end

    flatten_context_hl()
    vim.api.nvim_create_autocmd("ColorScheme", {
      group = vim.api.nvim_create_augroup("NeogitFlattenContextHl", { clear = true }),
      callback = flatten_context_hl,
    })
  end,
}
