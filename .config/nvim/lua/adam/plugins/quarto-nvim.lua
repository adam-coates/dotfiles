return {
	"quarto-dev/quarto-nvim",
	dependencies = {
		{ "hrsh7th/nvim-cmp" },
		{ "jmbuhr/otter.nvim" },
		"nvim-treesitter/nvim-treesitter",
	},
	opts = {
		debug = false,
		closePreviewOnExit = true,
		lspFeatures = {
			enabled = true,
			chunks = "curly",
			languages = { "r", "python", "julia", "bash", "html" },
			diagnostics = {
				enabled = true,
				triggers = { "BufWritePost" },
			},
			completion = {
				enabled = true,
			},
		},
		codeRunner = {
			enabled = true,
			default_method = "molten", -- 'molten' or 'slime'
			ft_runners = {}, -- filetype to runner, ie. `{ python = "molten" }`.
			-- Takes precedence over `default_method`
			never_run = { "yaml" }, -- filetypes which are never sent to a code runner
		},
		keymap = {
			-- set whole section or individual keys to `false` to disable
			hover = "K",
			definition = "gd",
			type_definition = "gD",
			rename = "<leader>lR",
			format = "<leader>lf",
			references = "gr",
			document_symbols = "gS",
		},
		-- Function to open Quarto Preview in a buffer instead of a tab
		vim.cmd([[
            function! QuartoPreview()
                :w!
                :terminal quarto preview %:p
                :call feedkeys('<Esc>')
                :bprev
            endfunction
        ]]),
		vim.keymap.set("n", "<localleader>P", ":call QuartoPreview() <CR>"),
	},
}
