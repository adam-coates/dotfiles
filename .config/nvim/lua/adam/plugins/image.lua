return {
	{
		"vhyrro/luarocks.nvim",
		priority = 1001, -- this plugin needs to run before anything else
		opts = {
			rocks = { "magick" },
		},
	},
	{
		"3rd/image.nvim",
		config = function()
			local image = require("image")
			image.setup({
				backend = "kitty",
				integrations = {
					markdown = {
						enabled = true,
						only_render_image_at_cursor = true,
						-- only_render_image_at_cursor_mode = "popup",
						filetypes = { "markdown", "vimwiki", "quarto" },
					},
				},
			})
		end,
	},
}
