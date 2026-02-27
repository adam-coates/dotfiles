return {
	"yetone/avante.nvim",
	event = "VeryLazy",
	version = false,
	opts = {
		-- Gemini 2.5 flash
		provider = "gemini",
		providers = {
			gemini = {
				endpoint = "https://generativelanguage.googleapis.com/v1beta/models",
				model = "gemini-2.5-flash",
				timeout = 30000, -- Timeout in milliseconds
				temperature = 0,
				max_tokens = 8192,
			},
			ollama = {
				endpoint = "http://127.0.0.1:11434",
				model = "kimi-k2.5:cloud",
			},
		},
	},
	build = "make",
	dependencies = {
		"nvim-lua/plenary.nvim",
		"MunifTanjim/nui.nvim",
		"nvim-telescope/telescope.nvim",
		"hrsh7th/nvim-cmp",
		"nvim-tree/nvim-web-devicons",
		"zbirenbaum/copilot.lua",
		{
			"MeanderingProgrammer/markdown.nvim",
			main = "render-markdown",
			name = "render-markdown",
			opts = {
				file_types = { "markdown", "Avante" },
			},
			ft = { "markdown", "Avante" },
		},
	},
}
