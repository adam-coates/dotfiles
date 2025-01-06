local opt = vim.opt

-- set spell
opt.spelllang = "en_gb"
opt.spell = true

-- line numbers
opt.relativenumber = true
opt.number = true

-- tabs & indentation
opt.tabstop = 4
opt.shiftwidth = 4
opt.expandtab = true
opt.autoindent = true

-- line wrapping
opt.wrap = false

-- search settings
opt.ignorecase = true
opt.smartcase = true

-- cursor line
opt.cursorline = true

-- appearance
opt.termguicolors = true
opt.background = "dark"
opt.signcolumn = "yes"

-- backspace
opt.backspace = "indent,eol,start"

-- clipboard
opt.clipboard:append("unnamedplus")

-- split windows
opt.splitright = true
opt.splitbelow = true

opt.iskeyword:append("-")

-- leave 8 rows bottom and top while scrolling
opt.scrolloff = 8

-- undos saved
opt.swapfile = false
opt.backup = false
opt.undodir = os.getenv("HOME") .. "/.vim/undodir"
opt.undofile = true


-- vim.g.markdown_folding = 1

--vim.opt.list = true
--vim.opt.listchars = {
--    space = "⋅",
--    eol = "↴",
--    tab = "▎_",
--    tab = "|_>",
--      tab = "| ",
--    trail = "•",
--    extends = "❯",
--    precedes = "❮",
--    nbsp = "",
--}
--vim.opt.fillchars = {
--    fold = " ",
--    foldsep = " ",
--    foldopen = "",
--    foldclose = "",
--    diff = "╱",
--}
-- Set the char for the indent line
--vim.g.indentline_char = '│'
