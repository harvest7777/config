-- line numbers
vim.opt.number = true         -- show line numbers
vim.opt.relativenumber = true -- relative numbers (great for jumping)


-- indentation
vim.opt.tabstop = 2        -- tab = 2 spaces
vim.opt.shiftwidth = 2     -- indent = 2 spaces
vim.opt.expandtab = true   -- use spaces instead of tabs
vim.opt.smartindent = true -- auto indent new lines

-- search
vim.opt.ignorecase = true -- case insensitive search
vim.opt.smartcase = true  -- unless you type a capital
vim.opt.hlsearch = false  -- don't highlight after search is done

-- ui
vim.opt.wrap = false       -- don't wrap long lines
vim.opt.scrolloff = 18     -- keep 8 lines above/below cursor
vim.opt.signcolumn = 'yes' -- always show sign column (prevents jumpiness)
vim.opt.cursorline = true  -- highlight current line
vim.opt.cmdheight = 0      -- hides it when not in use
vim.opt.foldlevel = 99     -- default unfolded

-- splits
vim.opt.splitright = true -- vsplit opens right
vim.opt.splitbelow = true -- split opens below

-- misc
vim.opt.swapfile = false -- no swap files
vim.opt.undofile = true  -- persistent undo across sessions
vim.opt.clipboard = 'unnamedplus'
vim.opt.iskeyword:append("-")

-- auto reload
vim.o.autoread = true
vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold", "CursorHoldI" }, {
  callback = function()
    vim.cmd("checktime")
  end,
})

-- restore last cursor position when reopening a file
vim.api.nvim_create_autocmd("BufReadPost", {
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    local line_count = vim.api.nvim_buf_line_count(0)
    if mark[1] > 0 and mark[1] <= line_count then
      vim.api.nvim_win_set_cursor(0, mark)
    end
  end,
})

vim.diagnostic.config({
  virtual_text = {
    spacing = 2,
    prefix = '■',
    format = function(diag)
      return diag.message:sub(1, 60) .. (diag.message:len() > 55 and '...' or '')
    end,
  },
  signs = true,
  underline = true,
  update_in_insert = false, -- no noise while typing
  severity_sort = true,     -- errors before warnings
  float = {
    border = 'rounded',
    source = true, -- shows 'pyright' or 'lua_ls' etc
  },
})
