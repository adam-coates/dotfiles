-- A month calendar: which days have a daily note, which have tasks due. Shown in
-- the context panel, and on its own with <leader>dc.
--
-- (calendar.nvim by wsdjeg is a nice plugin, but its window is fixed in a corner,
-- it has no week numbers and it asks what to do on every <CR>.)

local settings = require("settings")
local D = require("notes.date")
local util = require("notes.util")
local periodic = require("notes.periodic")

local M = {}

--- Days with an open task due or scheduled, for one month: day -> "overdue"/"open".
local function due_days(prefix)
	local out, today = {}, D.today()
	local T = require("notes.tasks")
	local rows = vim.list_extend({}, require("notes.index").tasks())
	vim.list_extend(rows, require("notes.todoist").rows())
	for _, item in ipairs(rows) do
		local task = item.task
		if not T.is_done(task.status) then
			local date = task.due or task.scheduled
			if date and date:sub(1, 7) == prefix then
				out[date] = date < today and "overdue" or "open"
			end
		end
	end
	return out
end

--- Rows for a month. Returns rows (for util.render) and a function that finds the
--- day, or week, at a row and byte column.
---@param month string "2026-11"
---@param selected string? day to highlight
function M.rows(month, selected)
	local today = D.today()
	local first = month .. "-01"
	local start = D.week_start(first)
	local due = due_days(month)
	local y, m = tonumber(month:sub(1, 4)), tonumber(month:sub(6, 7))
	local rows, cells = {}, {}

	local title = os.date("%B %Y", D.time(first))
	rows[#rows + 1] = { { util.pad(title, 32, "center"), "NotesTitle" } }
	local head = { { " Wk ", "NotesMuted" } }
	for i = 0, 6 do
		local name = os.date("%a", D.time(D.add(start, i, "day"))):sub(1, 2)
		head[#head + 1] = { " " .. name .. " ", "NotesMuted" }
	end
	rows[#rows + 1] = head

	local weeks = math.ceil((D.diff(start, ("%04d-%02d-%02d"):format(y, m, D.days_in_month(y, m))) + 1) / 7)
	for w = 0, weeks - 1 do
		local monday = D.add(start, w * 7, "day")
		-- The ISO week of the Thursday in this row, also when weeks start on Sunday
		local thursday = D.add(monday, (4 - settings.week_start) % 7, "day")
		local has_week = periodic.exists("weekly", thursday)
		local row = { { (" %02d "):format(tonumber(os.date("%V", D.time(thursday)))), has_week and "NotesLink" or "NotesMuted" } }
		local spans = { { from = 0, to = 4, week = thursday } }
		local col = 4
		for i = 0, 6 do
			local iso = D.add(monday, i, "day")
			local inside = iso:sub(1, 7) == month
			local has_note = periodic.exists("daily", iso)
			local hl = inside and (has_note and "NotesLink" or "NotesText") or "NotesBorder"
			if inside and i >= 5 and not has_note then
				hl = "NotesMuted"
			end
			if iso == today then
				hl = "NotesToday"
			end
			if iso == selected then
				hl = iso == today and "NotesActiveBold" or "NotesActive"
			end
			local number = ("%3d"):format(tonumber(iso:sub(9, 10)))
			row[#row + 1] = { number, hl }
			local mark, mark_hl = " ", hl
			if due[iso] then
				mark, mark_hl = "•", due[iso] == "overdue" and "NotesOverdue" or "NotesSoon"
			elseif has_note then
				mark, mark_hl = "·", "NotesLink"
			end
			row[#row + 1] = { mark, iso == selected and "NotesActive" or mark_hl }
			local width = #number + #mark
			spans[#spans + 1] = { from = col, to = col + width, iso = iso }
			col = col + width
		end
		rows[#rows + 1] = row
		cells[#rows] = spans
	end

	return rows, function(row, col)
		for _, span in ipairs(cells[row] or {}) do
			if col >= span.from and col < span.to then
				return span.iso, span.week
			end
		end
	end
end

-- On its own ---------------------------------------------------------------------

local ns = vim.api.nvim_create_namespace("notes_calendar")

--- Open the calendar. With `on_pick`, <CR> calls it with the day (a date picker).
function M.open(opts)
	opts = opts or {}
	local selected = opts.date or D.today()
	local _, note_day = periodic.identify(vim.api.nvim_buf_get_name(0))
	if not opts.date and note_day then
		selected = note_day
	end
	local buf, win = util.float({ "" }, {
		width = 62,
		height = 20,
		title = opts.title or "Calendar",
		footer = opts.on_pick and "Enter pick · q close" or "Enter day · w week · m month · y year · t today · a task",
	})
	vim.bo[buf].filetype = "notescalendar"
	vim.wo[win].cursorline = false
	vim.wo[win].wrap = false

	local function draw()
		local rows = {}
		local month = M.rows(selected:sub(1, 7), selected)
		for _, row in ipairs(month) do
			rows[#rows + 1] = vim.list_extend({ (" "):rep(15) }, row)
		end
		while #rows < 9 do
			rows[#rows + 1] = { "" }
		end
		rows[#rows + 1] = { { "  " .. os.date("%A, %d %B %Y", D.time(selected)), "NotesHeader" }, { "  " .. D.human(selected), "NotesMuted" } }
		local T = require("notes.tasks")
		local count = 0
		local all = vim.list_extend({}, require("notes.index").tasks())
		vim.list_extend(all, require("notes.todoist").rows())
		for _, item in ipairs(all) do
			local task = item.task
			if (task.due == selected or task.scheduled == selected) and not T.is_done(task.status) then
				count = count + 1
				if count <= 5 then
					rows[#rows + 1] = { { item.todoist and "  󰄵 " or "  󰄱 ", T.date_hl(selected) }, util.truncate(util.plain(task.text), 54) }
				end
			end
		end
		if count > 5 then
			rows[#rows + 1] = { { ("  and %d more"):format(count - 5), "NotesMuted" } }
		end
		local entry = require("notes.index").get(periodic.path("daily", selected))
		if entry then
			rows[#rows + 1] = { { ("  󰎞 %d words"):format(entry.words), "NotesLink" } }
			for i = 1, math.min(3, #entry.headings) do
				rows[#rows + 1] = { { "    " .. util.truncate(entry.headings[i].text, 54), "NotesMuted" } }
			end
		elseif count == 0 then
			rows[#rows + 1] = { { "  Nothing here yet", "NotesMuted" } }
		end
		util.render(buf, ns, rows)
	end

	local function map(lhs, fn)
		vim.keymap.set("n", lhs, fn, { buffer = buf, nowait = true })
	end
	local function move(n, unit)
		return function()
			selected = D.add(selected, n * vim.v.count1, unit)
			draw()
		end
	end
	local function close()
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
	end
	local function go(kind)
		return function()
			close()
			periodic.open(kind, selected)
		end
	end
	for lhs, step in pairs({ h = -1, l = 1, k = -7, j = 7, ["<Left>"] = -1, ["<Right>"] = 1, ["<Up>"] = -7, ["<Down>"] = 7 }) do
		map(lhs, move(step, "day"))
	end
	-- Todoist tasks arrive later than the notes' own.
	vim.api.nvim_create_autocmd("User", {
		pattern = "TodoistChanged",
		callback = function()
			if not vim.api.nvim_win_is_valid(win) then
				return true
			end
			draw()
		end,
	})
	map("H", move(-1, "month"))
	map("L", move(1, "month"))
	map("[", move(-1, "month"))
	map("]", move(1, "month"))
	map("K", move(-1, "year"))
	map("J", move(1, "year"))
	map("t", function()
		selected = D.today()
		draw()
	end)
	map("<CR>", function()
		close()
		if opts.on_pick then
			opts.on_pick(selected)
		else
			periodic.open("daily", selected)
		end
	end)
	if not opts.on_pick then
		map("w", go("weekly"))
		map("m", go("monthly"))
		map("y", go("yearly"))
		map("a", function()
			local day = selected
			close()
			util.input({ prompt = "Task for " .. D.human(day) }, function(text)
				local T = require("notes.tasks")
				local line = T.from_text(text)
				if not line:find("📅", 1, true) then
					line = T.set_date(line, "due", day)
				end
				T.add_to_note(T.capture_path(), settings.task_heading, { line })
				util.notify("Added for " .. D.human(day))
			end)
		end)
	end
	draw()
end

return M
