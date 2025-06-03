return {
	"folke/snacks.nvim",
	priority = 1000,
	lazy = false,
	---@type snacks.Config
	opts = {
		animate = { enable = false },
		bigfile = { enabled = true },
		dashboard = {
			preset = {
				header = [[
███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗
████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║
██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║
██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║
██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║
╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝]],
				keys = {
					{ icon = " ", key = "f", desc = "Find File", action = ":lua Snacks.dashboard.pick('files')" },
					{ icon = " ", key = "n", desc = "New File", action = ":ene | startinsert" },
					{
						icon = " ",
						key = "g",
						desc = "Find Text",
						action = ":lua Snacks.dashboard.pick('live_grep')",
					},
					{
						icon = " ",
						key = "r",
						desc = "Recent Files",
						action = ":lua Snacks.dashboard.pick('oldfiles')",
					},
					{
						icon = " ",
						key = "c",
						desc = "Config",
						action = ":lua Snacks.dashboard.pick('files', {cwd = vim.fn.stdpath('config')})",
					},
					{ icon = " ", key = "s", desc = "Restore Session", section = "session" },
					{
						icon = "󰒲 ",
						key = "L",
						desc = "Lazy",
						action = ":Lazy",
						enabled = package.loaded.lazy ~= nil,
					},
					{ icon = " ", key = "q", desc = "Quit", action = ":qa" },
				},
			},
			sections = {
				{ section = "header" },
				{ section = "keys", gap = 1, padding = 1 },
				{ section = "startup" },
				{
					pane = 2,
					icon = "󰍉 ",
					key = "s",
					title = "Search Notes",
					action = ":lua Snacks.dashboard.pick('live_grep', {cwd = '/home/adam/notes/', wrap = true})",
					indent = 2,
					padding = 1,
				},
				{
					pane = 2,
					gap = 1,
					icon = " ",
					section = "recent_files",
					cwd = "/home/adam/notes/",
					limit = 10,
					indent = 2,
					padding = 1,
				},
			},
			enabled = true,
		},
		dim = { enabled = true },
		explorer = { enabled = true },
		indent = {
			animate = {
				enabled = false,
			},
			enabled = true,
		},
		input = { enabled = true },
		lazygit = { enabled = true },
		notifier = {
			enabled = true,
			timeout = 3000,
		},
		picker = { enabled = false },
		quickfile = { enabled = false },
		scope = { enabled = false },
		scroll = { enabled = false },
		statuscolumn = { enabled = true },
		toggle = { enabled = true },
		words = { enabled = false },
		zen = {
			enabled = true,
			toggles = {
				dim = true,
				git_signs = false,
				diagnostics = false,
				line_number = false,
				relative_number = false,
				signcolumn = "no",
				indent = false,
			},
		},
		styles = {
			zen = {
				enter = true,
				fixbuf = false,
				minimal = false,
				width = 200,
				height = 0,
				backdrop = { transparent = false },
				keys = { q = false },
				zindex = 70,
				wo = {
					winhighlight = "NormalFloat:Normal",
                    wrap = true,
				},
				w = {
					snacks_main = true,
				},
			},
		},
	},
	keys = {
		{
			"<leader>fb",
			function()
				Snacks.picker.buffers()
			end,
			desc = "Buffers",
		},
		{
			"<leader>lg",
			function()
				Snacks.lazygit.open()
			end,
			desc = "Lazygit",
		},
		{
			"<leader>ee",
			function()
				Snacks.explorer()
			end,
			desc = "File Explorer",
		},
		{
			"<leader>u",
			function()
				Snacks.picker.undo()
			end,
			desc = "Undo Tree",
		},
	},
	init = function()
		vim.api.nvim_create_autocmd("User", {
			pattern = "VeryLazy",
			callback = function()
				Snacks.toggle.dim():map("<leader>\\d")
			end,
		})
		vim.api.nvim_create_user_command("Zen", function()
			Snacks.zen()
			vim.wo.linebreak = true
		end, {})
	end,
}
