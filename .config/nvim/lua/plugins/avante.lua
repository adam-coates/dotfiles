return {
	"yetone/avante.nvim",
	event = "VeryLazy",
	version = false,
	opts = {
		provider = "copilot", -- Set your default provider
		providers = {
			copilot = {
				endpoint = "https://api.githubcopilot.com",
				model = "gpt-4o-2024-11-20",
				timeout = 30000,
				extra_request_body = {
					temperature = 0.75,
					max_tokens = 20480,
				},
			},
			gemini = {
				endpoint = "https://generativelanguage.googleapis.com/v1beta/models",
				model = "gemini-2.0-flash", -- or "gemini-1.5-pro", "gemini-1.5-flash", etc.
				api_key_name = "GEMINI_API_KEY", -- Set this environment variable
				timeout = 30000,
				use_ReAct_prompt = true,
				extra_request_body = {
					generationConfig = {
						temperature = 0.75,
					},
				},
			},
		},
		behaviour = {
			enable_cursor_planning_mode = true,
		},
	},
	build = "make",
	dependencies = {
		"nvim-treesitter/nvim-treesitter",
		"stevearc/dressing.nvim",
		"nvim-lua/plenary.nvim",
		"MunifTanjim/nui.nvim",
		"nvim-telescope/telescope.nvim", -- for file_selector provider telescope
		"nvim-tree/nvim-web-devicons",
        "zbirenbaum/copilot.lua",
		{
			"HakonHarnes/img-clip.nvim",
			event = "VeryLazy",
			opts = {
				default = {
					embed_image_as_base64 = false,
					prompt_for_file_name = false,
					drag_and_drop = {
						insert_mode = true,
					},
					use_absolute_path = true,
				},
			},
		},
	},
}
