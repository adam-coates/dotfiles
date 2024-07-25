return {
	"oflisback/obsidian-bridge.nvim",
	dependencies = { "nvim-telescope/telescope.nvim" },
	config = function()
		require("obsidian-bridge").setup()
		obsidian_server_address = "http://127.0.0.1:27123"
	end,
	event = {
		"BufReadPre *.md",
		"BufNewFile *.md",
	},
	lazy = true,
	dependencies = {
		"nvim-lua/plenary.nvim",
	},
}
