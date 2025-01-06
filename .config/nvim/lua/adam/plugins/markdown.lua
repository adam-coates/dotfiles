local colorquote = "fffcfc"
return {
	"MeanderingProgrammer/markdown.nvim",
	main = "render-markdown",
	opts = {},
	name = "render-markdown", -- Only needed if you have another plugin named markdown.nvim
	dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
	config = function()
		require("render-markdown").setup({
            file_types = {'markdown', 'quarto'},
			quote = {
				enabled = true,
				highlight = colorquote,
			},
		})
	end,
}
