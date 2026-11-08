-- Snacks.zen knows nothing about herdr, so zoom the pane here.
local function herdr_zoom(enable)
	if vim.env.HERDR_ENV ~= "1" then
		return
	end
	vim.fn.system({ "herdr", "pane", "zoom", "--current", enable and "--on" or "--off" })
end

require("snacks").setup({
	indent = { enabled = true },
	scroll = { enabled = false },
	picker = {
		enabled = true,
		sources = {
			files = { hidden = true },
			grep = { hidden = true },
			explorer = {
				hidden = true,
				ignored = true, -- show gitignored files, as nvim-tree did
				exclude = { ".DS_Store" },
				layout = { layout = { width = 50 } },
			},
		},
	},
	explorer = { enabled = true },
	notifier = { enabled = true },
	statuscolumn = { enabled = true },
	words = { enabled = true },
	zen = {
		win = {
			wo = {
				signcolumn = "no",
				number = false,
				relativenumber = false,
				statuscolumn = "",
			},
		},
		on_open = function()
			herdr_zoom(true)
		end,
		on_close = function()
			herdr_zoom(false)
		end,
	},
	lazygit = {
		enabled = true,
		configure = true, -- auto-sets nvim-remote preset & syncs theme
		theme = {
			activeBorderColor = { fg = "WarningMsg", bold = true },
		},
	},
})
