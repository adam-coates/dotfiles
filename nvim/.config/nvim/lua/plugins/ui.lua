local settings = require("settings")

-- Icons, surround and text objects -----------------------------------------------
require("mini.icons").setup()
MiniIcons.mock_nvim_web_devicons()

require("mini.ai").setup({
	n_lines = 200,
	custom_textobjects = {
		-- ic / ac: a fenced code block; i* a*: emphasis
		c = { "\n```[^\n]*\n().-()\n```" },
		["*"] = { "%*+()[^%*]+()%*+" },
	},
})

-- sa / sd / sr, with markdown's markers: saiwb makes a word bold, saiwl a link.
local function buffer_surround()
	vim.b.minisurround_config = {
		custom_surroundings = {
			b = { input = { "%*%*().-()%*%*" }, output = { left = "**", right = "**" } },
			i = { input = { "%*().-()%*" }, output = { left = "*", right = "*" } },
			["="] = { input = { "==().-()==" }, output = { left = "==", right = "==" } },
			["~"] = { input = { "~~().-()~~" }, output = { left = "~~", right = "~~" } },
			c = { input = { "`().-()`" }, output = { left = "`", right = "`" } },
			w = { input = { "%[%[().-()%]%]" }, output = { left = "[[", right = "]]" } },
			l = {
				input = { "%[().-()%]%(.-%)" },
				output = function()
					local url = vim.fn.getreg("+"):match("^%s*(%a+://%S+)%s*$")
					return { left = "[", right = "](" .. (url or "") .. ")" }
				end,
			},
		},
	}
end
require("mini.surround").setup({ n_lines = 60 })
vim.api.nvim_create_autocmd("FileType", {
	group = vim.api.nvim_create_augroup("notes_surround", { clear = true }),
	pattern = { "markdown", "quarto" },
	callback = buffer_surround,
})

-- Snacks ---------------------------------------------------------------------------
require("snacks").setup({
	bigfile = { enabled = true },
	input = { enabled = true },
	notifier = { enabled = true, timeout = 3500, style = "compact" },
	indent = { enabled = true },
	scroll = { enabled = false },
	statuscolumn = { enabled = true },
	words = { enabled = true }, -- highlights other uses of the symbol under the cursor
	lazygit = {
		enabled = true,
		configure = true, -- auto-sets nvim-remote preset & syncs theme
		theme = {
			activeBorderColor = { fg = "WarningMsg", bold = true },
		},
	},
	image = {
		enabled = settings.images ~= false,
		force = settings.images == true,
		doc = {
			inline = true,
			float = true,
			max_width = 72,
			max_height = 24,
			conceal = function(_, kind)
				return kind == "math" -- keep ![[image]] and mermaid source visible
			end,
		},
		math = {
			enabled = true,
			latex = { font_size = "normalsize" },
		},
		-- ![[name.png]] anywhere in the vault (obsidian.nvim only looks in the
		-- attachments folder). A canvas is drawn from a copy named after its version.
		resolve = function(path, src)
			local vault = require("notes.vault")
			if src:match("^%a[%w+.-]*://") or not vault.is_note(path) then
				return nil
			end
			local index = require("notes.index")
			local rel = index.resolve_file((src:gsub("%%20", " ")), index.get(path))
			local file = rel and vault.abs(rel)
			if not file then
				local ok, api = pcall(require, "obsidian.api")
				file = ok and tostring(api.resolve_attachment_path(src)) or nil
			end
			return file and require("notes.canvas").image_path(file) or file
		end,
		convert = { notify = false },
	},
	picker = {
		enabled = true,
		ui_select = true,
		layout = function()
			return vim.o.columns >= 130 and "default" or "vertical"
		end,
		formatters = { file = { filename_first = true, truncate = 80 } },
		win = {
			input = {
				keys = {
					["<C-x>"] = { "edit_split", mode = { "i", "n" } },
					["<C-v>"] = { "edit_vsplit", mode = { "i", "n" } },
				},
			},
		},
		sources = {
			files = { hidden = true },
			grep = { hidden = true },
			explorer = {
				hidden = true,
				ignored = true, -- show gitignored files, as nvim-tree did
				layout = { layout = { width = 50, position = "left" } },
				exclude = { ".DS_Store", ".obsidian", ".trash" },
				win = { list = { keys = { ["<C-c>"] = false } } },
			},
			select = { layout = { preset = "select" } },
		},
	},
	explorer = { enabled = true, replace_netrw = true },
	dashboard = require("config.dashboard").startup(),
	zen = {
		toggles = { dim = false, git_signs = false },
		show = { statusline = false, tabline = false },
		win = {
			style = "zen",
			width = settings.readable_width,
			backdrop = { transparent = false, blend = 95 },
			wo = { signcolumn = "no", number = false, relativenumber = false, statuscolumn = "", foldcolumn = "0" },
		},
		on_open = function()
			if vim.env.HERDR_ENV == "1" then
				vim.system({ "herdr", "pane", "zoom", "--current", "--on" })
			end
		end,
		on_close = function()
			if vim.env.HERDR_ENV == "1" then
				vim.system({ "herdr", "pane", "zoom", "--current", "--off" })
			end
		end,
	},
	styles = {
		notification = { wo = { wrap = true } },
		input = { relative = "editor", row = math.floor(vim.o.lines * 0.3), width = 70 },
		zen = { relative = "editor" },
	},
})

vim.print = function(...)
	return Snacks.debug.inspect(...)
end

-- Keys ----------------------------------------------------------------------------
local wk = require("which-key")
wk.setup({
	preset = "classic",
	delay = 350,
	icons = { mappings = true, rules = false },
	show_help = false,
	win = { border = "rounded", title = true },
	spec = {
		{ "<leader>n", group = "note", icon = "󰎞" },
		{ "<leader>d", group = "daily & calendar (debug in code)", icon = "󰃭" },
		{ "<leader>l", group = "links (LSP in code) / LazyGit", icon = "󰌷" },
		{ "<leader>f", group = "find", icon = "󰍉" },
		{ "<leader>t", group = "tasks", icon = "󰄲" },
		{ "<leader>p", group = "panels", icon = "󰕰" },
		{ "<leader>P", group = "print", icon = "󰐪", mode = { "n", "x" } },
		{ "<leader>i", group = "insert / images", icon = "󰐕", mode = { "n", "x" } },
		{ "<leader>k", group = "flashcards", icon = "󰘸" },
		{ "<leader>c", group = "code / REPL", icon = "", mode = { "n", "x" } },
		{ "<leader>ci", group = "start REPL" },
		{ "<leader>e", group = "explorer", icon = "󰙅" },
		{ "<leader>m", group = "make pretty", icon = "󰉼", mode = { "n", "x" } },
		{ "<leader>o", group = "Word", icon = "󰈙" },
		{ "<leader>q", group = "quarto", icon = "󰠮" },
		{ "<leader>v", group = "view & toggles", icon = "󰈈" },
		{ "<leader>g", group = "git & sync", icon = "󰊢" },
		{ "<leader>x", group = "export & preview", icon = "󰈇" },
		{ "<leader>r", group = "refactor", icon = "󰑕", mode = { "n", "x" } },
		{ "<leader>s", group = "split / spelling / replace", icon = "󰤼" },
		{ "<leader>w", group = "vault", icon = "󰢬" },
		{ "<leader>z", group = "zotero", icon = "󰂺" },
		{ "<localleader>r", group = "run code", mode = { "n", "x" } },
		{ "z", group = "folding" },
		{ "<localleader>m", group = "format", mode = { "n", "x" } },
		{ "<localleader>mQ", group = "callout", mode = { "n", "x" } },
		{ "<localleader>mf", group = "footnote" },
		{ "<localleader>h", group = "heading" },
		{ "<localleader>l", group = "list", mode = { "n", "x" } },
		{ "<localleader>lt", group = "list type", mode = { "n", "x" } },
		{ "<localleader>t", group = "table" },
		{ "<localleader>ti", group = "table insert" },
		{ "<localleader>td", group = "table delete" },
		{ "<localleader>ty", group = "table duplicate" },
		{ "<localleader>ts", group = "table sort" },
		{ "<localleader>tv", group = "table csv" },
		{ "[", group = "previous" },
		{ "]", group = "next" },
		{ "g", group = "go to" },
		{ "s", group = "surround", mode = { "n", "x" } },
	},
})
