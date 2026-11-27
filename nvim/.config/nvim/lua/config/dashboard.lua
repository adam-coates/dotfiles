-- Two start screens: your previous config's (files, recent notes, recent files) and
-- the notes one (today, tasks, recent notes, cards). settings.start_screen picks
-- the one Neovim opens with; `o` on yours opens the notes one, `d` on the notes
-- one comes back.

local M = {}

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
		{ " ", "Notes", "o", function()
			require("notes.home").open()
		end },
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

--- The vault's most recently edited notes.
local function recent_notes(limit)
	local title = { title = "Recent notes", icon = "󰎚 ", padding = 1 }
	local list = { indent = 2, padding = 1 }
	local ok, entries = pcall(function()
		return vim.list_extend({}, require("notes.index").all())
	end)
	if ok then
		table.sort(entries, function(a, b)
			return a.mtime > b.mtime
		end)
		for i = 1, math.min(limit, #entries) do
			local entry = entries[i]
			list[#list + 1] = {
				desc = entry.name,
				autokey = true,
				action = function()
					require("notes.vault").open(entry.path)
				end,
			}
		end
	end
	if #list == 0 then
		list[1] = { text = { { "No notes yet", hl = "Comment" } } }
	end
	return { pane = 2, title, list }
end

--- Your previous config's dashboard: Snacks' actions on the left; recent notes and
--- recent files on the right (stacked below on narrow windows).
function M.default()
	return {
		enabled = true,
		width = 60,
		pane_gap = 4,
		sections = {
			actions(),
			function()
				return recent_notes(5)
			end,
			vim.tbl_extend("force", separator(0), { pane = 2 }),
			{ pane = 2, icon = " ", title = "Recent Files", padding = 1 }, -- own item, so it gets a gap below
			{ pane = 2, section = "recent_files", limit = 3, indent = 2, padding = 1 },
		},
	}
end

local function inside_vault()
	local cwd = vim.fn.getcwd()
	for _, v in ipairs(require("notes.vault").list()) do
		local root = vim.fs.normalize(v.path)
		if cwd == root or vim.startswith(cwd, root .. "/") then
			return true
		end
	end
	return vim.env.NOTES_VAULT ~= nil
end

--- The one Neovim starts with.
function M.startup()
	local choice = require("settings").start_screen or "default"
	if choice == "notes" or (choice == "auto" and inside_vault()) then
		return require("notes.home").dashboard()
	end
	return M.default()
end

--- Show a dashboard. Snacks gives every dashboard the same autocmd group and
--- recreates it for each new one, so a dashboard that is still open when the next
--- one starts later fails to clean up ("No such group"). Close it first, and draw
--- the new one in the same window.
function M.show(opts)
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].filetype == "snacks_dashboard" then
			if buf == vim.api.nvim_get_current_buf() then
				vim.cmd("enew") -- the old dashboard is wiped, and cleans up after itself
				opts = vim.tbl_extend("force", opts, { buf = 0, win = 0 })
			else
				vim.api.nvim_buf_delete(buf, { force = true })
			end
		end
	end
	Snacks.dashboard.open(opts)
end

function M.open()
	M.show(M.default())
end

return M
