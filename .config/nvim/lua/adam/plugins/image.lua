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
                        clear_in_insert_mode = true,
						only_render_image_at_cursor = true,
						-- only_render_image_at_cursor_mode = "popup",
						filetypes = { "markdown", "vimwiki", "quarto" },
						max_width = 100, -- tweak to preference
						max_height = 12, -- ^
						max_height_window_percentage = math.huge, -- this is necessary for a good experience
						max_width_window_percentage = math.huge,
						window_overlap_clear_enabled = true,
						window_overlap_clear_ft_ignore = { "cmp_menu", "cmp_docs", "" },
					},
				},
			})
		end,
	},
}
