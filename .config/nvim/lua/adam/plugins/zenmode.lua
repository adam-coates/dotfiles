return {
	"folke/zen-mode.nvim",
	event = "VeryLazy",
	dependencies = {
		"folke/twilight.nvim",
		"preservim/vim-pencil",
	},
	config = function()
		require("zen-mode").setup({
			window = {
				backdrop = 0.95,
				width = 180, -- width of the Zen window
				height = 1, -- height of the Zen window
				options = {
					signcolumn = "no", -- disable signcolumn
					number = false, -- disable number column
					relativenumber = false, -- disable relative numbers
					-- cursorline = false, -- disable cursorline
					-- cursorcolumn = false, -- disable cursor column
					-- foldcolumn = "0", -- disable fold column
					-- list = false, -- disable whitespace characters
				},
			},
            plugins = {
                twilight = { enabled = false },
                tmux = { enabled = true }
            },
		})
		require("twilight").setup({
			dimming = {
				alpha = 0.5,
			},
		})
	end,
}
