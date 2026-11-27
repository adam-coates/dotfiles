-- Options. The global values are your previous config's (code first); prose buffers
-- (markdown, quarto, text, git commits) get their own in config/autocmds.lua:
-- wrapping at words, concealed markup, no line numbers unless settings.numbers.

local settings = require("settings")
local o = vim.opt

vim.g.mapleader = " "
vim.g.maplocalleader = ","

-- Basics
o.number = true
o.relativenumber = true
o.title = true
o.cursorline = true
o.wrap = false
o.scrolloff = 8
o.sidescrolloff = 8
o.smoothscroll = true
o.breakindent = true
o.breakindentopt = "list:-1"
o.showbreak = ""

-- Indentation
o.tabstop = 4
o.shiftwidth = 4
o.softtabstop = 4
o.expandtab = true
o.smartindent = true
o.formatoptions = "jcroqln"

-- Spelling (words added with zg go to spell/en.utf-8.add)
o.spell = true
o.spelllang = settings.spelllang
o.spelloptions = "camel"
o.spellsuggest = "best,9"

-- Search
o.ignorecase = true
o.smartcase = true
o.inccommand = "split"

-- Looks
o.termguicolors = true
o.signcolumn = "yes"
o.showmatch = true
o.matchtime = 2
o.cmdheight = 0
o.laststatus = 3
o.showmode = false
o.winborder = "rounded"
o.completeopt = "menuone,noinsert,noselect"
o.pumheight = 10
o.pumblend = 10
o.fillchars = { eob = " ", fold = " ", foldopen = "▾", foldclose = "▸", foldsep = " ", diff = "╱" }
o.shortmess:append("IcCsW")
o.guicursor =
	"n-v-c:block,i-ci-ve:ver25,r-cr:hor20,o:hor50,a:blinkwait700-blinkoff400-blinkon250-Cursor/lCursor,sm:block-blinkwait175-blinkoff150-blinkon175"

-- Folding: treesitter everywhere, all open
o.foldmethod = "expr"
o.foldexpr = "v:lua.vim.treesitter.foldexpr()"
o.foldlevel = 99
o.foldlevelstart = 99

-- Splits
o.splitbelow = true
o.splitright = true
o.splitkeep = "screen"

-- Files
o.writebackup = false
o.swapfile = false
o.undofile = true
o.undodir = vim.env.HOME .. "/.vim/undodir" -- shared with your previous config, so undo history carries over
o.autoread = true
o.confirm = true
o.updatetime = 300
o.timeoutlen = 500
o.ttimeoutlen = 0

-- Behaviour
o.iskeyword:append("-")
o.path:append("**")
o.wildignore:append({ "*/node_modules/*", "*.o", "*.obj", "*.pyc", "*.class", "*.jar" })
o.wildmode = "longest:full,full"
o.clipboard = "unnamedplus"
o.mouse = settings.mouse and "a" or ""
o.virtualedit = "block"
o.jumpoptions = "stack,view"
o.sessionoptions = "buffers,curdir,folds,tabpages,winsize"

-- netrw stays for :Explore; `nvim folder` opens the Snacks explorer.
vim.g.netrw_keepdir = 0
vim.g.netrw_localcopydircmd = "cp -r"

vim.g.markdown_recommended_style = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0
vim.g.loaded_node_provider = 0
vim.g.loaded_python3_provider = 0

-- Messages and the command line in floating windows (your previous config's setup).
-- Still experimental in Neovim, hence the pcall.
pcall(function()
	require("vim._core.ui2").enable({
		enable = true,
		msg = {
			targets = {
				[""] = "msg",
				empty = "cmd",
				bufwrite = "msg",
				confirm = "cmd",
				emsg = "pager",
				echo = "msg",
				echomsg = "msg",
				echoerr = "pager",
				completion = "cmd",
				list_cmd = "pager",
				lua_error = "pager",
				lua_print = "msg",
				progress = "pager",
				rpc_error = "pager",
				quickfix = "msg",
				search_cmd = "cmd",
				search_count = "cmd",
				shell_cmd = "pager",
				shell_err = "pager",
				shell_out = "pager",
				shell_ret = "msg",
				undo = "msg",
				verbose = "pager",
				wildlist = "cmd",
				wmsg = "msg",
				typed_cmd = "cmd",
			},
			cmd = { height = 0.5 },
			dialog = { height = 0.5 },
			msg = { height = 0.3, timeout = 5000 },
			pager = { height = 0.5 },
		},
	})
end)
