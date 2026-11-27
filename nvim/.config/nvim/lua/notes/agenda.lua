-- The agenda: every open task in the vault by when it is due, in one buffer you can
-- work from.

local settings = require("settings")
local util = require("notes.util")
local index = require("notes.index")
local vault = require("notes.vault")
local D = require("notes.date")
local T = require("notes.tasks")

local M = {}

local ns = vim.api.nvim_create_namespace("notes_agenda")
local state = { buf = nil, items = {}, done = false, filter = nil }

local function groups()
	local today = D.today()
	local horizon = D.add(today, settings.agenda_days, "day")
	local out = {
		{ key = "overdue", label = "󰀦 Overdue", hl = "NotesOverdue", rows = {} },
		{ key = "today", label = "󰃶 Today", hl = "NotesToday", rows = {} },
		{ key = "soon", label = "󰃰 Next " .. settings.agenda_days .. " days", hl = "NotesSoon", rows = {} },
		{ key = "later", label = "󰃮 Later", hl = "NotesHeader", rows = {} },
		{ key = "none", label = "󰃴 No date", hl = "NotesMuted", rows = {} },
		{ key = "done", label = "󰄲 Done today", hl = "NotesGreen", rows = {} },
	}
	local by = {}
	for _, group in ipairs(out) do
		by[group.key] = group.rows
	end
	local rows = vim.list_extend({}, index.refresh().tasks())
	vim.list_extend(rows, require("notes.todoist").rows())
	for _, row in ipairs(rows) do
		local task = row.task
		local match = not state.filter or (task.body .. " " .. row.entry.rel):lower():find(state.filter:lower(), 1, true)
		if match and task.text ~= "" then
			if T.is_done(task.status) then
				if task.done == today then
					table.insert(by.done, row)
				end
			elseif not (task.start and task.start > today) and (task.text ~= "" or row.todoist) then
				local date = task.due or task.scheduled
				if not date then
					table.insert(by.none, row)
				elseif date < today then
					table.insert(by.overdue, row)
				elseif date == today or (task.scheduled and task.scheduled <= today) then
					table.insert(by.today, row)
				elseif date <= horizon then
					table.insert(by.soon, row)
				else
					table.insert(by.later, row)
				end
			end
		end
	end
	for _, group in ipairs(out) do
		for i, row in ipairs(group.rows) do
			row.order = i
		end
		table.sort(group.rows, function(a, b)
			local x, y = T.happens(a.task) or "9", T.happens(b.task) or "9"
			if x ~= y then
				return x < y
			elseif a.task.priority ~= b.task.priority then
				return a.task.priority < b.task.priority
			end
			return a.entry.rel .. ("%05d"):format(a.task.line) < b.entry.rel .. ("%05d"):format(b.task.line)
		end)
	end
	return out
end

--- Numbers for the dashboard and the statusline.
function M.counts()
	local today, overdue, due = D.today(), 0, 0
	local rows = vim.list_extend({}, index.tasks())
	vim.list_extend(rows, require("notes.todoist").rows())
	for _, row in ipairs(rows) do
		local task = row.task
		if not T.is_done(task.status) then
			local date = task.due or task.scheduled
			if date and date < today then
				overdue = overdue + 1
			elseif date == today then
				due = due + 1
			end
		end
	end
	return overdue, due
end

--- The first tasks of the agenda, for the dashboard.
function M.upcoming(n)
	local out = {}
	for _, group in ipairs(groups()) do
		if group.key == "overdue" or group.key == "today" or group.key == "soon" then
			for _, row in ipairs(group.rows) do
				if #out < n then
					out[#out + 1] = row
				end
			end
		end
	end
	return out
end

--- Draw. With `follow`, keep the cursor on that task, wherever it moved to.
function M.render(follow)
	if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
		return
	end
	local rows = {}
	state.items = {}
	rows[#rows + 1] = { { "  Agenda", "NotesTitle" }, { "  " .. os.date("%A, %d %B %Y"), "NotesMuted" }, { state.filter and ("   filter: " .. state.filter) or "", "NotesSoon" } }
	rows[#rows + 1] = { "" }
	local empty = true
	for _, group in ipairs(groups()) do
		if #group.rows > 0 then
			empty = false
			rows[#rows + 1] = { { "  " .. group.label, group.hl }, { "  " .. #group.rows, "NotesMuted" } }
			for _, row in ipairs(group.rows) do
				local chunks = { "    " }
				vim.list_extend(chunks, require("notes.blocks").task_chunks(row, { source = true }))
				rows[#rows + 1] = chunks
				state.items[#rows] = row
			end
			rows[#rows + 1] = { "" }
		end
	end
	if empty then
		rows[#rows + 1] = { { state.filter and "  Nothing matches" or "  Nothing to do. <leader>ta adds a task.", "NotesMuted" } }
	end
	local todoist = require("notes.todoist")
	local notice
	if todoist.cache.error then
		notice = { { "  󰄵 " .. todoist.cache.error, "NotesError" } }
	elseif not todoist.token() and (require("settings").todoist or {}).enabled ~= false then
		notice = { { "  󰄵 Todoist isn't connected. :TodoistToken connects it (or set enabled = false in settings.todoist).", "NotesMuted" } }
	elseif todoist.cache.loading and todoist.cache.time == 0 then
		notice = { { "  󰄵 Fetching Todoist…", "NotesMuted" } }
	end
	if notice then
		table.insert(rows, 2, notice)
		-- Rows below moved down one.
		local moved = {}
		for row, value in pairs(state.items) do
			moved[row + 1] = value
		end
		state.items = moved
	end
	rows[#rows + 1] = { { "  x done  c cycle  <CR> go  d due  s scheduled  > < move a day  p priority  a add  A Todoist  gx open in Todoist  f filter  r refresh  q close", "NotesBorder" } }
	local win = vim.fn.bufwinid(state.buf)
	local pos = win ~= -1 and vim.api.nvim_win_get_cursor(win) or nil
	util.render(state.buf, ns, rows)
	if pos then
		local line = math.min(pos[1], #rows)
		if type(follow) == "table" and follow.task then
			for row, item in pairs(state.items) do
				if item.entry.rel == follow.entry.rel and item.task.text == follow.task.text then
					line = row
				end
			end
		end
		pcall(vim.api.nvim_win_set_cursor, win, { line, pos[2] })
	end
end

local function item()
	return state.items[vim.api.nvim_win_get_cursor(0)[1]]
end

local function change(fn, stay, todoist)
	return function()
		local row = item()
		if not row then
			return
		end
		if row.todoist then
			if todoist then
				todoist(row.todoist, row)
			else
				require("notes.util").notify("Not for Todoist tasks", "warn")
			end
			return
		end
		T.edit(row.entry.path, row.task.line, row.task.raw, function(line)
			return fn(line, row.task)
		end)
		M.render(not stay and row or nil)
	end
end

-- Move to the previous or next task.
local function hop(step)
	return function()
		local row = vim.api.nvim_win_get_cursor(0)[1]
		local last = vim.api.nvim_buf_line_count(0)
		repeat
			row = row + step
		until row < 1 or row > last or state.items[row]
		if state.items[row] then
			vim.api.nvim_win_set_cursor(0, { row, 4 })
		end
	end
end

local function keymaps(buf)
	local function map(lhs, fn, desc)
		vim.keymap.set("n", lhs, fn, { buffer = buf, nowait = true, desc = desc })
	end
	map("<CR>", function()
		local row = item()
		if row and row.todoist then
			-- The note it came from, if it says so; otherwise Todoist itself.
			local note = (row.todoist.description or ""):match("%[%[([^%]|#]+)")
			local entry = note and index.resolve(note)
			if entry then
				vault.open(entry.path)
			else
				vim.ui.open(require("notes.todoist").url(row.todoist.id))
			end
		elseif row then
			vault.open(row.entry.path, { line = row.task.line })
		end
	end, "Go to task (Todoist: its note, or Todoist)")
	map("gx", function()
		local row = item()
		if row and row.todoist then
			vim.ui.open(require("notes.todoist").url(row.todoist.id))
		end
	end, "Open in Todoist")
	map("<C-v>", function()
		local row = item()
		if row then
			vault.open(row.entry.path, { line = row.task.line, cmd = "vsplit" })
		end
	end, "Go to task in a split")
	map("x", change(function(line)
		return T.toggle(line)
	end, true, function(item)
		require("notes.todoist").close(item)
	end), "Done / not done")
	map("c", change(function(line, task)
		local order = { [" "] = "/", ["/"] = " ", x = " ", X = " ", ["-"] = " " }
		return { T.set_status(line, order[task.status] or " ") }
	end), "In progress / to do")
	local function move(days)
		return change(function(line, task)
			local field = task.due and "due" or (task.scheduled and "scheduled" or "due")
			return { T.set_date(line, field, D.add(task[field] or D.today(), days * vim.v.count1, "day")) }
		end, false, function(item)
			require("notes.todoist").shift(item, days * vim.v.count1)
		end)
	end
	map(">", move(1), "A day later")
	map("<", move(-1), "A day earlier")
	local function ask(field)
		return function()
			local row = item()
			if not row then
				return
			end
			if row.todoist then
				-- Todoist reads dates itself: "next fri 3pm", "every monday".
				return vim.ui.input({ prompt = "Due (as you'd type it in Todoist; “no date” clears)", default = row.todoist.due and row.todoist.due.string or "" }, function(text)
					if text and vim.trim(text) ~= "" then
						require("notes.todoist").update(row.todoist, { due_string = vim.trim(text) })
					end
				end)
			end
			T.ask_date(field:gsub("^%l", string.upper) .. " date", row.task[field], function(date)
				T.edit(row.entry.path, row.task.line, row.task.raw, function(line)
					return { T.set_date(line, field, date) }
				end)
				M.render(row)
			end)
		end
	end
	map("d", ask("due"), "Due date")
	map("s", ask("scheduled"), "Scheduled date")
	map("p", change(function(line, task)
		local order = { [1] = 4, [2] = 1, [3] = 2, [4] = 3, [5] = 4, [6] = 5 }
		return { T.set_priority(line, order[task.priority]) }
	end, false, function(item)
		require("notes.todoist").update(item, { priority = item.priority % 4 + 1 })
	end), "Raise priority")
	map("A", function()
		require("notes.todoist").capture()
	end, "Add a task to Todoist")
	map("a", function()
		T.capture()
	end, "Add a task")
	map("f", function()
		vim.ui.input({ prompt = "Filter (text, #tag or folder; empty clears)", default = state.filter }, function(text)
			if text then
				state.filter = vim.trim(text) ~= "" and vim.trim(text) or nil
				M.render()
			end
		end)
	end, "Filter")
	map("r", function()
		require("notes.todoist").refresh()
		M.render()
	end, "Refresh")
	map("]", hop(1), "Next task")
	map("[", hop(-1), "Previous task")
	map("q", function()
		local alt = vim.fn.bufnr("#")
		if #vim.api.nvim_tabpage_list_wins(0) > 1 and vim.w.notes_agenda_split then
			vim.cmd.close()
		elseif alt ~= -1 and alt ~= buf and vim.api.nvim_buf_is_valid(alt) then
			vim.api.nvim_set_current_buf(alt)
		else
			vim.cmd.bdelete()
		end
	end, "Close")
end

function M.open(opts)
	opts = opts or {}
	if opts.filter ~= nil then
		state.filter = opts.filter or nil
	end
	local win = vault.main_win()
	if win then
		vim.api.nvim_set_current_win(win)
	end
	if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
		state.buf = vim.api.nvim_create_buf(false, true)
		vim.bo[state.buf].bufhidden = "hide"
		vim.bo[state.buf].filetype = "notesagenda"
		vim.api.nvim_buf_set_name(state.buf, "notes://agenda")
		keymaps(state.buf)
		vim.api.nvim_create_autocmd("User", {
			pattern = { "NotesChanged", "TodoistChanged" },
			callback = function()
				if state.buf and vim.api.nvim_buf_is_valid(state.buf) and vim.fn.bufwinid(state.buf) ~= -1 then
					M.render()
				end
			end,
		})
		vim.api.nvim_create_autocmd("BufEnter", {
			buffer = state.buf,
			callback = vim.schedule_wrap(function()
				M.render()
			end),
		})
	end
	require("notes.todoist").ensure()
	vim.api.nvim_set_current_buf(state.buf)
	vim.wo.wrap, vim.wo.spell, vim.wo.conceallevel, vim.wo.number, vim.wo.relativenumber = false, false, 0, false, false
	vim.wo.signcolumn, vim.wo.foldcolumn = "no", "0"
	M.render()
	for row = 1, vim.api.nvim_buf_line_count(state.buf) do
		if state.items[row] then
			vim.api.nvim_win_set_cursor(0, { row, 4 })
			break
		end
	end
end

return M
