return {
	"nvim-telescope/telescope.nvim",
	branch = "0.1.x",
	dependencies = {
        { 'nvim-telescope/telescope-ui-select.nvim' },
		"nvim-lua/plenary.nvim",
		{ "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
		"nvim-tree/nvim-web-devicons",
		{
			"jmbuhr/telescope-zotero.nvim",
			dependencies = {
				{ "kkharji/sqlite.lua" },
			},
			config = function()
				-- This is the key addition - directly configuring the zotero plugin
				require('zotero').setup({
					zotero_db_path = "/home/adam/Zotero/zotero.sqlite",
					better_bibtex_db_path = "/home/adam/Zotero/better-bibtex.sqlite",
					zotero_storage_path = "/home/adam/Nextcloud/zotero/",
					pdf_opener = "xdg-open"
				})
			end,
		},
	},
	config = function()
		local telescope = require("telescope")
		local actions = require("telescope.actions")
		telescope.setup({
			defaults = {
				path_display = { "truncate " },
				layout_strategy = "vertical",
				mappings = {
					i = {
						["<C-k>"] = actions.move_selection_previous,
						["<C-j>"] = actions.move_selection_next,
						["<C-q>"] = actions.send_selected_to_qflist + actions.open_qflist,
					},
				},
			},
			extensions = {
                ['ui-select'] = {
                    require('telescope.themes').get_dropdown(),
                },
				-- You can keep this too for completeness, but the direct setup is what matters
				zotero = {
					zotero_db_path = "/home/adam/Zotero/zotero.sqlite",
					better_bibtex_db_path = "/home/adam/Zotero/better-bibtex.sqlite",
					zotero_storage_path = "/home/adam/Nextcloud/zotero/",
					pdf_opener = "xdg-open"
				},
			}
		})
		telescope.load_extension("fzf")
        telescope.load_extension('ui-select')
		telescope.load_extension("zotero")
		
		-- Your keymaps remain the same
		local keymap = vim.keymap
		keymap.set("n", "<leader>ff", "<cmd>Telescope find_files<cr>", { desc = "Fuzzy find files in cwd" })
		keymap.set("n", "<leader>fr", "<cmd>Telescope oldfiles<cr>", { desc = "Find string in cwd" })
		keymap.set("n", "<leader>fs", "<cmd>Telescope live_grep<cr>", { desc = "Find string in cwd" })
		keymap.set("n", "<leader>fc", "<cmd>Telescope grep_string<cr>", { desc = "Find string under cursor in cwd" })
		keymap.set('n', '<leader>fz', ':Telescope zotero<cr>', { desc = '[z]otero' })
	end,
}
