-- Render markdown and quarto in the buffer: headings, quotes, code blocks, tables.
-- Headings take their colours from the theme (RenderMarkdownH1..6).
require("render-markdown").setup({
	file_types = { "markdown", "quarto" },
	-- Quarto divs and spans, styled from the document's css: like the preview
	-- (utils/quarto_render.lua). Runs alongside the builtin markdown rendering.
	custom_handlers = {
		markdown = {
			extends = true,
			parse = function(ctx)
				return require("utils.quarto_render").parse(ctx)
			end,
		},
	},
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
