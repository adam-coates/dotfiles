-- Snacks.zen knows nothing about herdr, so zoom the pane here.
local function herdr_zoom(enable)
	if vim.env.HERDR_ENV ~= "1" then
		return
	end
	vim.fn.system({ "herdr", "pane", "zoom", "--current", enable and "--on" or "--off" })
end

-- A dashboard section that's just a line across a column (Snacks' default
-- width is 60), with `padding` blank lines below it.
local function separator(padding)
	return { text = { { string.rep("─", 60), hl = "NonText" } }, padding = padding }
end

-- Snacks' default dashboard actions, drawn with the key right after the name
-- (Snacks puts keys at the far right of the column). Restore Session and Lazy
-- are left out: there's no session plugin, and lazy.nvim isn't used.
local function actions()
	local items = {
		{ " ", "Find File", "f", ":lua Snacks.dashboard.pick('files')" },
		{ " ", "New File", "n", ":ene | startinsert" },
		{ " ", "Find Text", "g", ":lua Snacks.dashboard.pick('live_grep')" },
		{ " ", "Recent Files", "r", ":lua Snacks.dashboard.pick('oldfiles')" },
		{ " ", "Config", "c", ":lua Snacks.dashboard.pick('files', {cwd = vim.fn.stdpath('config')})" },
		{ " ", "Quit", "q", ":qa" },
	}
	local width = 0
	for _, a in ipairs(items) do
		width = math.max(width, vim.fn.strdisplaywidth(a[2]))
	end
	local section = { gap = 1, padding = 1, align = "center" }
	for _, a in ipairs(items) do
		section[#section + 1] = {
			key = a[3],
			action = a[4],
			text = {
				{ a[1], hl = "icon" },
				{ a[2] .. string.rep(" ", width - vim.fn.strdisplaywidth(a[2]) + 2), hl = "desc" },
				{ a[3], hl = "key" },
			},
		}
	end
	return section
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
	-- Start screen: Snacks' default actions on the left; Joplin notes and recent
	-- files on the right (stacked below on narrow windows). Snacks' "startup"
	-- section needs lazy.nvim, so it's left out.
	dashboard = {
		enabled = true,
		sections = {
			actions(),
			function()
				return require("utils.joplin").dashboard({ pane = 2, limit = 3 })
			end,
			vim.tbl_extend("force", separator(0), { pane = 2 }),
			{ pane = 2, icon = " ", title = "Recent Files", padding = 1 }, -- own item, so it gets a gap below
			{ pane = 2, section = "recent_files", limit = 3, indent = 2, padding = 1 },
		},
	},
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
