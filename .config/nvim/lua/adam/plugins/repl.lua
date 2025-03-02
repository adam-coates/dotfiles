return {
	{
		"benlubas/molten-nvim",
		dependencies = { "3rd/image.nvim" },
		build = ":UpdateRemotePlugins",
		init = function()
			-- these are examples, not defaults. Please see the readme
			vim.g.molten_image_provider = "image.nvim"
			vim.g.molten_output_win_max_height = 50
            vim.g.molten_auto_image_popup = 1
            vim.g.molten_image_location = "virt"
            vim.g.molten_virt_text_output = true
			vim.keymap.set("n", "<localleader>mi", ":MoltenInit<CR>")
			vim.keymap.set("n", "<localleader>e", ":MoltenEvaluateOperator<CR>")
			vim.keymap.set("n", "<localleader>rr", ":MoltenReevaluateCell<CR>")
			vim.keymap.set("v", "<localleader>r", ":<C-u>MoltenEvaluateVisual<CR>gv")
			vim.keymap.set("n", "<localleader>os", ":noautocmd MoltenEnterOutput<CR>")
			vim.keymap.set("n", "<localleader>oh", ":MoltenHideOutput<CR>")
			vim.keymap.set("n", "<localleader>md", ":MoltenDelete<CR>")
		end,
	},
}
