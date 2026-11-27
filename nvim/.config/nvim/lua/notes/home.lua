-- The start screen: what is due, what you worked on last, and the keys to start.

local M = {}

local function greeting()
	local hour = tonumber(os.date("%H"))
	local part = hour < 5 and "Good night"
		or hour < 12 and "Good morning"
		or hour < 18 and "Good afternoon"
		or "Good evening"
	return part .. os.date(" · %A, %d %B")
end

local function keys()
	local items = {
		{ "󰃶 ", "Today", "t", "<leader>dd" },
		{ "󰎜 ", "New note", "n", "<leader>nn" },
		{ "󰈞 ", "Find a note", "f", "<leader><leader>" },
		{ "󰊄 ", "Search text", "s", "<leader>/" },
		{ "󰄲 ", "Agenda", "a", "<leader>tt" },
		{ "󰃭 ", "Calendar", "c", "<leader>dc" },
		{ "󰘸 ", "Review cards", "r", "<leader>kk" },
		{ "󱁉 ", "Graph", "g", "<leader>pg" },
		{ "󰋖 ", "Keys and help", "?", "<leader>?" },
		{ "󰕮 ", "Dashboard", "d", "dashboard" },
		{ "󰗼 ", "Quit", "q", "quit" },
	}
	local section = { padding = 1 }
	for _, item in ipairs(items) do
		section[#section + 1] = {
			key = item[3],
			action = function()
				if item[4] == "quit" then
					vim.cmd.qall()
				elseif item[4] == "dashboard" then
					require("config.dashboard").open()
				else
					vim.api.nvim_feedkeys(vim.keycode(item[4]), "m", false)
				end
			end,
			text = { { item[1], hl = "icon" }, { ("%-18s"):format(item[2]), hl = "desc" }, { item[3], hl = "key" } },
		}
	end
	return section
end

local function tasks()
	local ok, rows = pcall(function()
		return require("notes.agenda").upcoming(5)
	end)
	if not ok or #rows == 0 then
		return {}
	end
	local D, T, util = require("notes.date"), require("notes.tasks"), require("notes.util")
	local section = { pane = 2, icon = "󰄲 ", title = "Tasks", indent = 2, padding = 1 }
	for _, row in ipairs(rows) do
		local date = row.task.due or row.task.scheduled
		local when = date and D.human(date) or ""
		section[#section + 1] = {
			text = {
				{ util.pad(util.truncate(util.plain(row.task.text), 38), 39), hl = "desc" },
				{ when, hl = date and T.date_hl(date) or "NotesMuted" },
			},
			action = function()
				if row.todoist then
					return vim.ui.open(require("notes.todoist").url(row.todoist.id))
				end
				require("notes.vault").open(row.entry.path, { line = row.task.line })
			end,
		}
	end
	return section
end

local function recent()
	local ok, entries = pcall(function()
		return vim.list_extend({}, require("notes.index").all())
	end)
	if not ok or #entries == 0 then
		return {}
	end
	table.sort(entries, function(a, b)
		return a.mtime > b.mtime
	end)
	local util, D = require("notes.util"), require("notes.date")
	local section = { pane = 2, icon = "󰋚 ", title = "Recent notes", indent = 2, padding = 1 }
	for i = 1, math.min(5, #entries) do
		local e = entries[i]
		section[#section + 1] = {
			key = tostring(i),
			action = function()
				require("notes.vault").open(e.path)
			end,
			text = {
				{ util.pad(util.truncate(e.name, 30), 31), hl = "file" },
				{ util.pad(util.truncate(D.human(D.iso(e.mtime)), 13), 14), hl = "NotesMuted" },
				{ tostring(i), hl = "key" },
			},
		}
	end
	return section
end

local function summary()
	local ok, text = pcall(function()
		local index = require("notes.index")
		local all = index.all()
		local words, links = 0, 0
		for _, e in ipairs(all) do
			words, links = words + e.words, links + #e.links
		end
		local parts = {
			("%d notes"):format(#all),
			("%d links"):format(links),
			("%d tags"):format(vim.tbl_count(index.tags())),
			("%dk words"):format(math.floor(words / 1000 + 0.5)),
		}
		local _, due, new = require("notes.cards").due()
		if due + new > 0 then
			parts[#parts + 1] = ("%d cards due"):format(due + new)
		end
		return table.concat(parts, "  ·  ")
	end)
	return { pane = 1, text = { { ok and text or "", hl = "footer" } }, padding = { 0, 1 } }
end

function M.dashboard()
	return {
		enabled = true,
		width = 56,
		pane_gap = 6,
		preset = {},
		sections = {
			function()
				return {
					pane = 1,
					padding = 1,
					text = {
						{ "󰠮  " .. require("notes.vault").name() .. "\n", hl = "header" },
						{ greeting(), hl = "NotesMuted" },
					},
				}
			end,
			keys,
			summary,
			tasks,
			recent,
		},
	}
end

function M.open()
	require("config.dashboard").show(M.dashboard())
end

return M
