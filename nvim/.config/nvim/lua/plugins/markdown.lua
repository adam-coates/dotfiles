-- Render markdown and quarto in the buffer: headings, quotes, code blocks, tables.
-- Headings take their colours from the theme (RenderMarkdownH1..6).
require("render-markdown").setup({
	file_types = { "markdown", "quarto" },
	heading = {
		enabled = true,
		sign = true,
		position = "overlay",
		icons = { "󰲡 ", "󰲣 ", "󰲥 ", "󰲧 ", "󰲩 ", "󰲫 " },
		signs = { "󰫎 " },
		width = "full",
		left_margin = 0,
		left_pad = 0,
		right_pad = 0,
		min_width = 0,
		border = false,
		border_virtual = false,
		border_prefix = false,
		above = "▄",
		below = "▀",
		backgrounds = {
			"RenderMarkdownH1Bg",
			"RenderMarkdownH2Bg",
			"RenderMarkdownH3Bg",
			"RenderMarkdownH4Bg",
			"RenderMarkdownH5Bg",
			"RenderMarkdownH6Bg",
		},
		foregrounds = {
			"RenderMarkdownH1",
			"RenderMarkdownH2",
			"RenderMarkdownH3",
			"RenderMarkdownH4",
			"RenderMarkdownH5",
			"RenderMarkdownH6",
		},
	},
})
