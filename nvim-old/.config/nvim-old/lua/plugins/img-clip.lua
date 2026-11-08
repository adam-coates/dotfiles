return {
	"HakonHarnes/img-clip.nvim",
	event = "VeryLazy",
	opts = {
		default = {
			dir_path = "images",
		},
	},
	keys = {
		-- suggested keymap
		{ "<localleader>p", "<cmd>PasteImage<cr>", desc = "Paste image from system clipboard" },
	},
}
