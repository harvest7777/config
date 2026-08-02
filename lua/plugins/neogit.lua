--test
return
{
  "NeogitOrg/neogit",
  lazy = true,
  dependencies = {
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
    sections = {
      -- "Recent commits" defaults to folded, unlike "Unmerged into" which
      -- it's spliced alongside (see the status_ui.Status patch below) --
      -- unfold it so it doesn't look empty at a glance.
      recent = { folded = false },
    },
    mappings = {
      -- Frees up <C-t> (default: TabOpen) so the global floating-terminal
      -- toggle works inside Neogit's status buffer too.
      status = { ["<c-t>"] = false },
    },
  },
  config = function(_, opts)
    require("neogit").setup(opts)

    -- Persist the status buffer's fold state (which sections are
    -- expanded/collapsed) across full Neovim restarts, keyed by repo path.
    -- Pure vim.fn.stdpath/vim.json/io -- no shell-outs, so it behaves the
    -- same on macOS and Linux.
    local fold_cache_path = vim.fs.joinpath(vim.fn.stdpath("state"), "neogit_fold_state.json")

    local function read_fold_cache()
      local f = io.open(fold_cache_path, "r")
      if not f then
        return {}
      end
      local content = f:read("*a")
      f:close()
      if content == "" then
        return {}
      end
      local ok, data = pcall(vim.json.decode, content)
      if not ok or type(data) ~= "table" then
        return {}
      end
      return data
    end

    local function persist_fold_state(cwd, fold_state)
      if not cwd or not fold_state or vim.tbl_isempty(fold_state) then
        return
      end
      local data = read_fold_cache()
      data[cwd] = fold_state
      local f = io.open(fold_cache_path, "w")
      if not f then
        return
      end
      f:write(vim.json.encode(data))
      f:close()
    end

    local function load_fold_state(cwd)
      if not cwd then
        return nil
      end
      return read_fold_cache()[cwd]
    end

    -- Every Neogit UI buffer (status, commit view, log view, popups, ...)
    -- defaults to bufhidden=wipe. A "replace"-kind view swaps the previous
    -- buffer out of its window via nvim_set_current_buf without closing it
    -- first, so wipe kicks in immediately and destroys it. When you back out
    -- ("q"), Neogit tries to restore that buffer, finds it's already gone,
    -- and falls back to `enew()` -- an empty buffer instead of where you were.
    -- Force these buffers to survive being swapped out instead. This is
    -- scoped to Neogit's own "Neogit*"-filetype chrome, so the deliberately
    -- throwaway "view file at old commit" scratch buffers (real filetypes
    -- like `lua`) are untouched and still wipe themselves as intended.
    vim.api.nvim_create_autocmd("FileType", {
      pattern = "Neogit*",
      group = vim.api.nvim_create_augroup("NeogitPreserveBuffersOnReplace", { clear = true }),
      callback = function(args)
        -- NeogitCommitSelectView is a one-shot modal (squash/fixup/rebase
        -- commit picker), never something you back out to and expect
        -- restored. It also opens a separate floating header window that
        -- Neogit only closes via an on_detach callback fired by the
        -- default bufhidden=wipe when Buffer:close() swaps the window's
        -- buffer back. Forcing hide here stops that swap from wiping the
        -- buffer, on_detach never fires, and the header window is
        -- orphaned -- left floating indefinitely after you pick a commit.
        if args.match == "NeogitCommitSelectView" then
          return
        end
        vim.bo[args.buf].bufhidden = "hide"
      end,
    })

    -- The fix above stops the *common* case, but "Recent Commits" -> commit
    -- -> file -> q -> q still lands you in a blank buffer. That q-mapping
    -- (neogit/lib/jump.lua) force-deletes the file-preview scratch buffer
    -- *before* reopening the commit view, so the commit view's "buffer to
    -- restore to" gets captured from whatever anonymous placeholder buffer
    -- Neovim fell back to mid-deletion, not the real previous buffer.
    -- If that recorded target turns out to be one of those anonymous
    -- placeholders (no name, no filetype), redirect to Neogit's status
    -- buffer instead -- the correct destination for every case this
    -- actually happens in.
    local Buffer = require("neogit.lib.buffer")
    local orig_buffer_close = Buffer.close
    Buffer.close = function(self, force)
      local function is_real_target(buf)
        if not (buf and vim.api.nvim_buf_is_valid(buf)) then
          return false
        end
        return vim.api.nvim_buf_get_name(buf) ~= "" or vim.bo[buf].filetype ~= ""
      end

      if self.kind == "replace" and not is_real_target(self.old_buf) then
        local ok, status = pcall(require, "neogit.buffers.status")
        if ok then
          local inst = status.instance()
          if inst and inst.buffer and inst.buffer.handle ~= self.handle and vim.api.nvim_buf_is_valid(inst.buffer.handle) then
            self.old_buf = inst.buffer.handle
          end
        end
      end

      return orig_buffer_close(self, force)
    end

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
        do
          local ok, status = pcall(require, "neogit.buffers.status")
          if ok then
            local inst = status.instance()
            -- Seed a brand-new instance (nothing captured yet this session)
            -- from the on-disk cache left by a previous Neovim session.
            if inst and not inst.fold_state then
              inst.fold_state = load_fold_state(inst.cwd)
            end
          end
        end

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
              -- BufWinLeave fires while this buffer's window is still
              -- current, so cursor_line()/save_view() (both window-0-based)
              -- still read the right place.
              inst.cursor_state = inst.buffer:cursor_line()
              inst.view_state = inst.buffer:save_view()
              persist_fold_state(inst.cwd, inst.fold_state)
            end
          end,
        })
      end,
    })

    -- Covers quitting Neovim outright while the status buffer is still open
    -- (folds toggled, but BufWinLeave above never fired).
    vim.api.nvim_create_autocmd("VimLeavePre", {
      group = vim.api.nvim_create_augroup("NeogitPersistFoldStateOnExit", { clear = true }),
      callback = function()
        local ok, status = pcall(require, "neogit.buffers.status")
        if not ok then
          return
        end
        local inst = status.instance()
        if not inst then
          return
        end
        local fold_state = (inst.buffer and inst.buffer.ui and inst.buffer.ui:get_fold_state()) or inst.fold_state
        persist_fold_state(inst.cwd, fold_state)
      end,
    })

    -- Status buffer hides "Recent Commits" whenever "Unmerged into
    -- origin/main" is showing (buffers/status/ui.lua:
    -- `not show_upstream_unmerged and show_recent`) since they'd otherwise
    -- show mostly the same commits -- there's no config flag to show both.
    -- Render the tree twice: once normally (to get "Unmerged into" if
    -- present), once with that section force-hidden (to coax "Recent
    -- Commits" into existing), then splice the latter's "recent" section
    -- into the former's tree right after "Unmerged into".
    local status_ui = require("neogit.buffers.status.ui")
    local orig_status_render = status_ui.Status
    status_ui.Status = function(state, cfg)
      local result = orig_status_render(state, cfg)

      local show_recent = #state.recent.items > 0 and not cfg.sections.recent.hidden
      local show_unmerged = #state.upstream.unmerged.items > 0 and not cfg.sections.unmerged_upstream.hidden

      if show_recent and show_unmerged then
        local cfg2 = vim.tbl_extend("force", {}, cfg)
        cfg2.sections = vim.tbl_extend("force", {}, cfg.sections)
        cfg2.sections.unmerged_upstream =
          vim.tbl_extend("force", {}, cfg.sections.unmerged_upstream, { hidden = true })
        local recent_only = orig_status_render(state, cfg2)

        local recent_component
        for _, child in ipairs(recent_only[1].children) do
          if child.options and child.options.id == "recent" then
            recent_component = child
            break
          end
        end

        if recent_component then
          local children = result[1].children
          local insert_at = #children + 1
          for i, child in ipairs(children) do
            if child.options and child.options.id == "upstream_unmerged" then
              insert_at = i + 1
              break
            end
          end
          table.insert(children, insert_at, recent_component)
        end
      end

      return result
    end

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
