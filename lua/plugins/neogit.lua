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

    -- Neogit only saves the status buffer's fold/cursor state when
    -- StatusBuffer:close() runs. Drilling from "Recent Commits" into a
    -- commit and then a file swaps the window's buffer directly
    -- (nvim_set_current_buf), bypassing close() entirely -- so on the way
    -- back Neogit finds the old buffer hidden, rebuilds it from scratch,
    -- and every section resets to its configured default fold state.
    -- Capture the state ourselves as soon as the buffer loses its window,
    -- so it's there to restore no matter how we got away from it.
    vim.api.nvim_create_autocmd("FileType", {
      pattern = "NeogitStatus",
      group = vim.api.nvim_create_augroup("NeogitPreserveFoldState", { clear = true }),
      callback = function(args)
        vim.api.nvim_create_autocmd("BufWinLeave", {
          buffer = args.buf,
          once = true,
          callback = function()
            local ok, status = pcall(require, "neogit.buffers.status")
            if not ok then
              return
            end
            local inst = status.instance()
            if inst and inst.buffer and inst.buffer.ui then
              inst.fold_state = inst.buffer.ui:get_fold_state()
            end
          end,
        })
      end,
    })

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

    -- diffview always opens its diff/conflict UI in a new tab (no "replace
    -- window" mode exists). Hide the tabline while it's open so it doesn't
    -- visually register as a tab-switch; restore it once the view closes.
    --
    -- Hook diffview's emitter directly rather than calling its setup() --
    -- setup() also wires this up, but its config re-init previously broke
    -- the conflict view's ours/theirs content. DiffviewGlobal is a real _G
    -- global set the moment any diffview module loads, no setup() required.
    local has_diffview = pcall(require, "diffview")
    if has_diffview and _G.DiffviewGlobal then
      local saved_showtabline

      DiffviewGlobal.emitter:on("view_opened", function()
        saved_showtabline = vim.o.showtabline
        vim.o.showtabline = 0
      end)

      DiffviewGlobal.emitter:on("view_closed", function()
        if saved_showtabline ~= nil then
          vim.o.showtabline = saved_showtabline
          saved_showtabline = nil
        end
      end)
    end
  end,
}
