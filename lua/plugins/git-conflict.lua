return {
  'akinsho/git-conflict.nvim',
  -- must be loaded before VimEnter/BufRead fire for the first buffer, since
  -- those are what it hooks to detect conflicts (VeryLazy fires too late).
  lazy = false,
  dependencies = { 'catppuccin/nvim' },
  config = function()
    require('git-conflict').setup({
      default_mappings = true,
      default_commands = true,
      -- NOT disable_diagnostics=true: the plugin implements it via
      -- vim.diagnostic.disable(), removed in nvim 0.12. That throws and
      -- aborts the GitConflictDetected callback before it reaches the
      -- buffer-local co/ct mapping setup later in the same function, so it
      -- silently breaks both features. Replicate it below instead.
    })

    local diag_group = vim.api.nvim_create_augroup('GitConflictDiagnostics', { clear = true })
    vim.api.nvim_create_autocmd('User', {
      pattern = 'GitConflictDetected',
      group = diag_group,
      callback = function() vim.diagnostic.enable(false, { bufnr = vim.api.nvim_get_current_buf() }) end,
    })
    vim.api.nvim_create_autocmd('User', {
      pattern = 'GitConflictResolved',
      group = diag_group,
      callback = function() vim.diagnostic.enable(true, { bufnr = vim.api.nvim_get_current_buf() }) end,
    })

    -- git-conflict derives its marker-line "label" highlights by *lightening*
    -- the region color by a fixed amount, which assumes a dark background.
    -- On catppuccin latte the region tints already sit near-white, so that
    -- lightening clips straight to solid white. Set all six groups directly
    -- from the catppuccin palette instead of letting the plugin derive them.
    local function set_conflict_hl()
      local palette = require('catppuccin.palettes').get_palette()
      local blend = require('catppuccin.utils.colors').blend

      local function region(color) return blend(color, palette.base, 0.18) end
      local function label(color) return blend(color, palette.base, 0.55) end

      vim.api.nvim_set_hl(0, 'GitConflictCurrent', { bg = region(palette.yellow), bold = true })
      vim.api.nvim_set_hl(0, 'GitConflictIncoming', { bg = region(palette.green), bold = true })
      vim.api.nvim_set_hl(0, 'GitConflictAncestor', { bg = region(palette.lavender), bold = true })
      vim.api.nvim_set_hl(0, 'GitConflictCurrentLabel', { bg = label(palette.yellow), fg = palette.text, bold = true })
      vim.api.nvim_set_hl(0, 'GitConflictIncomingLabel', { bg = label(palette.green), fg = palette.text, bold = true })
      vim.api.nvim_set_hl(0, 'GitConflictAncestorLabel', { bg = label(palette.lavender), fg = palette.text, bold = true })
    end

    set_conflict_hl()
    vim.api.nvim_create_autocmd('ColorScheme', {
      group = vim.api.nvim_create_augroup('GitConflictCatppuccinHl', { clear = true }),
      callback = set_conflict_hl,
    })
  end,
}
