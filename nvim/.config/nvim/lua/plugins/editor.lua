require("gitsigns").setup({})

-- Close and rename HTML/JSX tags as you type
require("nvim-ts-autotag").setup({})

require("img-clip").setup({
	default = {
		dir_path = "images",
		relative_to_current_file = true, -- images/ next to the file, like figures
		copy_images = true, -- a pasted file path is copied into images/ too, not linked
	},
	filetypes = {
		quarto = { template = "![$CURSOR]($FILE_PATH)" },
	},
})

local wk = require("which-key")
wk.setup({ preset = "classic" })
wk.add({
	{ "<leader>c", group = "Code / REPL" },
	{ "<leader>d", group = "Debug" },
	{ "<leader>ci", group = "Start REPL" },
	{ "<leader>e", group = "Explorer" },
	{ "<leader>f", group = "Find" },
	{ "<leader>i", group = "Images" },
	{ "<leader>l", group = "LSP / LazyGit" },
	{ "<leader>m", group = "Make pretty" },
	{ "<leader>o", group = "Notes" },
	{ "<leader>p", group = "Print" },
	{ "<leader>q", group = "Quarto" },
	{ "<leader>s", group = "Split / Replace" },
	{ "<leader>t", group = "Typst" },
	{ "<localleader>r", group = "Run code" },
	{ "z", group = "Folding" },
	{ "[", group = "Jump backwards" },
	{ "]", group = "Jump forwards" },
	{ "g", group = "Go to" },
})
