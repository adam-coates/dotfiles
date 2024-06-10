return {
	"quarto-dev/quarto-nvim",
	dependencies = {
		{ "hrsh7th/nvim-cmp" },
		{ "jmbuhr/otter.nvim" },
		"nvim-treesitter/nvim-treesitter",
	},
	config = function()
		require("quarto").setup({
			closePreviewOnExit = true,
			lspFeatures = {
				enabled = true,
				languages = { "r", "python", "bash" },
				chunks = "all",
				diagnostics = {
					enabled = true,
					triggers = { "TextChanged" },
				},
				completion = {
					enabled = true,
				},
			},
		})

		vim.treesitter.language.register("markdown", "quarto")
		-- Function to open Quarto Preview in a buffer instead of a tab
		vim.cmd([[
            function! QuartoPreview()
                :w!
                :terminal quarto preview %:p
                :call feedkeys('<Esc>')
                :bprev
            endfunction
        ]])
		vim.keymap.set("n", "<localleader>P", ":call QuartoPreview() <CR>")
	end,
}
