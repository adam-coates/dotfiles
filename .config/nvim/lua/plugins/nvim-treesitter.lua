return {
	"nvim-treesitter/nvim-treesitter",
    dev = false,
	build = ":TSUpdate",
	dependencies = {
		{
			"windwp/nvim-ts-autotag",
			event = "InsertEnter",
			config = function()
				require("nvim-ts-autotag").setup({})
			end,
		},
	},
	config = function()
		require("nvim-treesitter.configs").setup({
			highlight = {
				enable = true,
			},
			indent = { enable = true },
			ensure_installed = {
				"python",
				"matlab",
				"json",
				"javascript",
				"typescript",
				"yaml",
				"html",
				"css",
				"markdown",
				"markdown_inline",
				"bash",
				"lua",
				"vim",
				"dockerfile",
				"gitignore",
				"r",
			},
			auto_install = true,
			incremental_selection = {
				enable = true,
				keymaps = {
					init_selection = "gnn",
					node_incremental = "gnn",
					scope_incremental = false,
					node_decremental = "<bs>",
				},
			},
		})
	end,
}
