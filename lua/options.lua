-- line numbers
vim.opt.number = true          -- show line numbers
vim.opt.relativenumber = true  -- relative numbers (great for jumping)


-- indentation
vim.opt.tabstop = 2            -- tab = 2 spaces
vim.opt.shiftwidth = 2         -- indent = 2 spaces
vim.opt.expandtab = true       -- use spaces instead of tabs
vim.opt.smartindent = true     -- auto indent new lines

-- search
vim.opt.ignorecase = true      -- case insensitive search
vim.opt.smartcase = true       -- unless you type a capital
vim.opt.hlsearch = false       -- don't highlight after search is done

-- ui
vim.opt.wrap = false           -- don't wrap long lines
vim.opt.scrolloff = 8          -- keep 8 lines above/below cursor
vim.opt.signcolumn = 'yes'     -- always show sign column (prevents jumpiness)
vim.opt.cursorline = true      -- highlight current line
vim.opt.cmdheight = 0          -- hides it when not in use
vim.opt.foldlevel = 99         -- default unfolded

-- splits
vim.opt.splitright = true      -- vsplit opens right
vim.opt.splitbelow = true      -- split opens below

-- misc
vim.opt.swapfile = false       -- no swap files
vim.opt.undofile = true        -- persistent undo across sessions
vim.opt.clipboard = 'unnamedplus'
