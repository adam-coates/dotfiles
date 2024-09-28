return {
	"epwalsh/obsidian.nvim",
	version = "*", -- recommended, use latest release instead of latest commit
	lazy = true,
	ft = "markdown",
	dependencies = {
		"nvim-lua/plenary.nvim",
		"hrsh7th/nvim-cmp",
		"nvim-telescope/telescope.nvim",
		"nvim-treesitter/nvim-treesitter",
	},
	opts = {
		workspaces = {
			{
				name = "notes",
				path = "~/notes",
			},
		},
		--open_notes_in = "vsplit",
		disable_frontmatter = true,
		ui = { enable = false },

		templates = {
			folder = "Templates",
			substitutions = {
				citation_title = function()
					vim.cmd("FindCitation")
				end,
			},
		},
	},
}
