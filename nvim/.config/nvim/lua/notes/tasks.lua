-- Tasks, in the format of Obsidian's Tasks plugin:
--
--   - [ ] Write the intro #thesis ⏫ 🔁 every week ⏳ 2026-11-27 📅 2026-11-30
--
-- Dataview's [due:: 2026-11-30] is understood as well. Completing a recurring
-- task adds its next occurrence above it. (obsidian-tasks.nvim renders the same
-- format, but doesn't do recurrence yet and takes over undo and :w in notes with
-- queries, so this is done here.)

local D = require("notes.date")
local util = require("notes.util")

local M = {}

---@class notes.Task
---@field status string the character between the brackets
---@field text string description, without dates and other metadata
---@field body string everything after the checkbox
---@field due string?
---@field scheduled string?
---@field start string?
---@field created string?
---@field done string?
---@field cancelled string?
---@field priority integer 1 highest ... 4 normal ... 6 lowest
---@field recur string?
---@field tags string[]
---@field line integer
---@field section string?
---@field raw string

local VS = "[\239\184\143]*" -- emoji variation selector
M.emoji = {
	due = { "📅", "📆", "🗓" },
	scheduled = { "⏳", "⌛" },
	start = { "🛫" },
	created = { "➕" },
	done = { "✅" },
	cancelled = { "❌" },
}
M.fields = { "start", "scheduled", "due", "created", "done", "cancelled" }
M.priorities = { "🔺", "⏫", "🔼", nil, "🔽", "⏬" }
M.priority_names = { "highest", "high", "medium", "none", "low", "lowest" }
M.priority_hl = { "NotesPriorityHigh", "NotesPriorityHigh", "NotesPriorityMedium", nil, "NotesPriorityLow", "NotesPriorityLow" }

local DATAVIEW = { due = "due", scheduled = "scheduled", start = "start", created = "created", done = "completion", cancelled = "cancelled" }
local RECUR = "🔁"
local OTHER = { "🆔", "⛔", "🏁" }

local function date_pattern(emoji)
	return emoji .. VS .. "%s*(%d%d%d%d%-%d%d%-%d%d)"
end

function M.is_done(status)
	return status == "x" or status == "X" or status == "-"
end

--- Parse what comes after the checkbox.
---@return notes.Task
function M.parse(body, status)
	local task = { status = status, body = body, priority = 4, tags = {} }
	local text = body
	for field, emojis in pairs(M.emoji) do
		for _, emoji in ipairs(emojis) do
			local date = text:match(date_pattern(emoji))
			if date then
				task[field] = task[field] or date
				text = text:gsub("%s*" .. date_pattern(emoji), "")
			end
		end
		local key = DATAVIEW[field]
		local date = text:match("[%[%(]" .. key .. "::%s*(%d%d%d%d%-%d%d%-%d%d)%s*[%]%)]")
		if date then
			task[field] = task[field] or date
			text = text:gsub("%s*[%[%(]" .. key .. "::%s*%d%d%d%d%-%d%d%-%d%d%s*[%]%)]", "")
		end
	end
	-- Kanban's @{2026-11-30}
	local card = text:match("@{(%d%d%d%d%-%d%d%-%d%d)}")
	if card then
		task.due = task.due or card
		text = text:gsub("%s*@{%d%d%d%d%-%d%d%-%d%d}", "")
	end
	for i = 1, 6 do
		local emoji = M.priorities[i]
		if emoji and text:find(emoji, 1, true) then
			task.priority = i
			text = text:gsub("%s*" .. emoji .. VS, "")
		end
	end
	local prio = text:match("%[priority::%s*(%a+)%s*%]")
	if prio then
		for i, name in ipairs(M.priority_names) do
			if name == prio:lower() then
				task.priority = i
			end
		end
		text = text:gsub("%s*%[priority::%s*%a+%s*%]", "")
	end
	local recur = text:match(RECUR .. VS .. "%s*([%w%s,%d]+)")
	if recur then
		task.recur = vim.trim(recur)
		text = text:gsub("%s*" .. RECUR .. VS .. "%s*[%w%s,%d]+", " ")
	end
	local rep = text:match("[%[%(]repeat::%s*([^%]%)]+)[%]%)]")
	if rep then
		task.recur = task.recur or vim.trim(rep)
		text = text:gsub("%s*[%[%(]repeat::%s*[^%]%)]+[%]%)]", "")
	end
	for _, emoji in ipairs(OTHER) do
		text = text:gsub("%s*" .. emoji .. VS .. "%s*[%w,%-]+", "")
	end
	task.tags = require("notes.index").parse_tags(text)
	task.text = vim.trim((text:gsub("%s+", " ")))
	return task
end

--- The date a task is about: due, else scheduled, else start.
function M.happens(task)
	return task.due or task.scheduled or task.start
end

--- Highlight group for a due date.
function M.date_hl(iso, today)
	today = today or D.today()
	if iso < today then
		return "NotesOverdue"
	elseif iso == today then
		return "NotesToday"
	elseif D.diff(today, iso) <= 3 then
		return "NotesSoon"
	end
	return "NotesDate"
end

-- Recurrence -----------------------------------------------------------------------

local WDAY = { sunday = 1, monday = 2, tuesday = 3, wednesday = 4, thursday = 5, friday = 6, saturday = 7 }
local function wday(word)
	for name, n in pairs(WDAY) do
		if #word >= 3 and name:sub(1, #word) == word then
			return n
		end
	end
end

--- The next date after `from` for a rule like "every 2 weeks on Monday".
--- Returns nil when the rule isn't understood.
function M.next_date(rule, from)
	local text = rule:lower():gsub("%s+when done$", ""):gsub("^every%s+", "")
	text = vim.trim(text)
	if text == "weekday" or text == "weekdays" then
		local date = from
		repeat
			date = D.add(date, 1, "day")
			local wd = D.wday(date)
		until wd ~= 1 and wd ~= 7
		return date
	end
	-- "monday", "monday, thursday", "monday and thursday"
	local days = {}
	local all = true
	for word in text:gsub(" and ", " "):gmatch("%a+") do
		local n = wday(word:gsub("s$", "")) or wday(word)
		all = all and n ~= nil
		if n then
			days[n] = true
		end
	end
	if all and next(days) then
		local date = from
		repeat
			date = D.add(date, 1, "day")
		until days[D.wday(date)]
		return date
	end

	local n, unit, rest = text:match("^(%d+) (%a+)%s*(.*)$")
	if not n then
		n, unit, rest = "1", text:match("^(%a+)%s*(.*)$")
	end
	if not unit then
		return nil
	end
	n, unit = tonumber(n), unit:gsub("s$", "")
	if unit == "other" then -- every other week
		n, unit, rest = 2, rest:match("^(%a+)%s*(.*)$")
		unit = unit and unit:gsub("s$", "")
	end
	if unit == "day" then
		return D.add(from, n, "day")
	elseif unit == "week" then
		local on = rest:match("^on (.+)$")
		if not on then
			return D.add(from, 7 * n, "day")
		end
		local wanted = {}
		for word in on:gsub(" and ", " "):gmatch("%a+") do
			wanted[wday(word) or 0] = true
		end
		wanted[0] = nil
		if not next(wanted) then
			return nil
		end
		-- The remaining days of this week, then jump n weeks.
		local week = D.week_start(from, 1)
		local date = from
		for _ = 1, 7 do
			date = D.add(date, 1, "day")
			if D.week_start(date, 1) ~= week then
				break
			end
			if wanted[D.wday(date)] then
				return date
			end
		end
		date = D.add(week, 7 * n, "day")
		for i = 0, 6 do
			local candidate = D.add(date, i, "day")
			if wanted[D.wday(candidate)] then
				return candidate
			end
		end
	elseif unit == "month" or unit == "quarter" then
		local first = D.add(from:sub(1, 7) .. "-01", n, unit)
		local y, m = tonumber(first:sub(1, 4)), tonumber(first:sub(6, 7))
		local last = D.days_in_month(y, m)
		local day = tonumber(rest:match("^on the (%d+)")) or (rest:match("^on the last") and 31) or tonumber(from:sub(9, 10))
		return ("%04d-%02d-%02d"):format(y, m, math.min(day, last))
	elseif unit == "year" then
		return D.add(from, n, "year")
	end
	return nil
end

-- Editing one line ------------------------------------------------------------------

--- Split a task line into everything up to the text, and the text.
local function split(line)
	local head, body = line:match("^(%s*[-*+]%s+%[.%]%s+)(.*)$")
	if not head then
		head, body = line:match("^(%s*%d+[.)]%s+%[.%]%s+)(.*)$")
	end
	return head, body
end

function M.set_status(line, status)
	return (line:gsub("^(%s*[-*+%d.)]+%s+%[).(%])", function(a, b)
		return a .. status .. b
	end))
end

-- Add text at the end, but before a ^block-id.
local function append(line, text)
	local rest, block = line:match("^(.-)(%s+%^[%w%-]+)%s*$")
	if rest then
		return rest .. " " .. text .. block
	end
	return (line:gsub("%s+$", "")) .. " " .. text
end

--- Set (or with nil, remove) a date on a task line.
function M.set_date(line, field, iso)
	for _, emoji in ipairs(M.emoji[field]) do
		local pattern = "(%s*)" .. emoji .. VS .. "%s*%d%d%d%d%-%d%d%-%d%d"
		if line:find(pattern) then
			return (line:gsub(pattern, function(space)
				return iso and (space .. M.emoji[field][1] .. " " .. iso) or ""
			end, 1))
		end
	end
	local key = DATAVIEW[field]
	local pattern = "(%s*)([%[%(])" .. key .. "::%s*[^%]%)]*([%]%)])"
	if line:find(pattern) then
		return (line:gsub(pattern, function(space, open, close)
			return iso and (space .. open .. key .. ":: " .. iso .. close) or ""
		end, 1))
	end
	if field == "due" and line:find("@{%d%d%d%d%-%d%d%-%d%d}") then
		return (line:gsub("%s*@{%d%d%d%d%-%d%d%-%d%d}", iso and (" @{" .. iso .. "}") or "", 1))
	end
	return iso and append(line, M.emoji[field][1] .. " " .. iso) or line
end

--- 1 highest ... 4 none ... 6 lowest
function M.set_priority(line, n)
	for i = 1, 6 do
		local emoji = M.priorities[i]
		if emoji then
			line = line:gsub("%s*" .. emoji .. VS, "")
		end
	end
	line = line:gsub("%s*%[priority::%s*%a+%s*%]", "")
	return M.priorities[n] and append(line, M.priorities[n]) or line
end

function M.set_recur(line, rule)
	line = line:gsub("%s*" .. RECUR .. VS .. "%s*[%w%s,]*[%w]", "")
	return rule and append(line, RECUR .. " " .. rule) or line
end

--- Mark a task line done or not done. Returns a list of lines: for a recurring
--- task, its next occurrence comes first.
function M.toggle(line, today)
	today = today or D.today()
	local head, body = split(line)
	if not head then
		return { line }
	end
	local status = head:match("%[(.)%]")
	if M.is_done(status) then
		local undone = M.set_status(line, " ")
		return { M.set_date(M.set_date(undone, "done", nil), "cancelled", nil) }
	end
	return M.complete(line, M.parse(body, status), today)
end

function M.complete(line, task, today)
	local done = M.set_date(M.set_status(line, "x"), "done", today)
	if not task.recur then
		return { done }
	end
	local when_done = task.recur:lower():match("when done$") ~= nil
	local base = M.happens(task)
	local from = (when_done or not base) and today or base
	local target = M.next_date(task.recur, from)
	if not target then
		util.notify("Can't work out the next date for “" .. task.recur .. "”", "warn")
		return { done }
	end
	local shift = D.diff(base or today, target)
	local fresh = M.set_status(line, " ")
	if base then
		for _, field in ipairs({ "due", "scheduled", "start" }) do
			if task[field] then
				fresh = M.set_date(fresh, field, D.add(task[field], shift, "day"))
			end
		end
	else
		fresh = M.set_date(fresh, "due", target)
	end
	fresh = M.set_date(fresh, "created", task.created and today or nil)
	fresh = fresh:gsub("%s+%^[%w%-]+%s*$", "") -- a block id stays with the original
	return { fresh, done }
end

-- Editing notes -----------------------------------------------------------------------

--- Change a task where it is written. `fn` gets the line and returns the lines to
--- put in its place. The task is found by its exact text, so a note that changed
--- in the meantime is never edited in the wrong spot.
function M.edit(path, lnum, raw, fn)
	local buf = vim.fn.bufnr("^" .. vim.fn.escape(path, "\\[]^$.*~") .. "$")
	local loaded = buf ~= -1 and vim.api.nvim_buf_is_loaded(buf)
	local lines
	if loaded then
		lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	else
		local text = util.read(path)
		if not text then
			return util.notify("Can't read " .. path, "error")
		end
		lines = util.lines(text)
	end
	if lines[lnum] ~= raw then
		lnum = nil
		for i, line in ipairs(lines) do
			if line == raw then
				lnum = i
				break
			end
		end
		if not lnum then
			util.notify("That task was changed in the meantime; refreshing", "warn")
			require("notes.index").refresh()
			return false
		end
	end
	local new = fn(raw)
	if #new == 1 and new[1] == raw then
		return false
	end
	if loaded then
		vim.api.nvim_buf_set_lines(buf, lnum - 1, lnum, false, new)
		vim.api.nvim_buf_call(buf, function()
			vim.cmd("silent noautocmd update")
		end)
	else
		local out = vim.list_slice(lines, 1, lnum - 1)
		vim.list_extend(out, new)
		vim.list_extend(out, vim.list_slice(lines, lnum + 1))
		util.write(path, table.concat(out, "\n") .. "\n")
	end
	require("notes.index").update(path)
	vim.api.nvim_exec_autocmds("User", { pattern = "NotesChanged", data = { path = path } })
	return true
end

-- On the cursor line --------------------------------------------------------------

local function current()
	local line = vim.api.nvim_get_current_line()
	local head, body = split(line)
	if not head then
		return nil, line
	end
	return M.parse(body, head:match("%[(.)%]")), line
end

local function replace(lines)
	local row = vim.api.nvim_win_get_cursor(0)[1]
	vim.api.nvim_buf_set_lines(0, row - 1, row, false, lines)
	if #lines > 1 then -- stay on the original
		vim.api.nvim_win_set_cursor(0, { row + #lines - 1, vim.api.nvim_win_get_cursor(0)[2] })
	end
end

function M.on_task()
	return current() ~= nil
end

--- Toggle the task under the cursor; make the line a task when it isn't one.
function M.toggle_current()
	local task, line = current()
	if task then
		return replace(M.toggle(line))
	end
	local indent, marker, rest = line:match("^(%s*)([-*+])%s+(.*)$")
	if not indent then
		indent, rest = line:match("^(%s*)(.*)$")
		marker = "-"
	end
	replace({ indent .. marker .. " [ ] " .. rest })
	if rest == "" then
		vim.cmd("startinsert!")
	end
end

--- The same over a visual selection (done unless all of it is done).
function M.toggle_range(first, last)
	for row = last, first, -1 do
		local line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1]
		if split(line) then
			vim.api.nvim_buf_set_lines(0, row - 1, row, false, M.toggle(line))
		end
	end
end

--- Step through statuses: to do, in progress, done, cancelled.
function M.cycle_current()
	local task, line = current()
	if not task then
		return M.toggle_current()
	end
	local order = { [" "] = "/", ["/"] = "x", x = "-", ["-"] = " " }
	local next_status = order[task.status] or " "
	if next_status == "x" then
		return replace(M.complete(line, task, D.today()))
	end
	line = M.set_status(line, next_status)
	line = M.set_date(line, "done", nil)
	line = M.set_date(line, "cancelled", next_status == "-" and D.today() or nil)
	replace({ line })
end

--- Ask for a date in plain words. An empty answer removes it.
function M.ask_date(prompt, default, fn)
	vim.ui.input({ prompt = prompt .. " (tomorrow, fri, +3d, 1 dec; empty removes)", default = default }, function(text)
		if text == nil then
			return
		end
		text = vim.trim(text)
		if text == "" then
			return fn(nil)
		end
		local date = D.parse(text)
		if not date then
			return util.notify("Not a date: " .. text, "warn")
		end
		fn(date)
	end)
end

function M.date_current(field)
	local task, line = current()
	if not task then
		M.toggle_current()
		task, line = current()
		if not task then
			return
		end
	end
	local buf, row = vim.api.nvim_get_current_buf(), vim.api.nvim_win_get_cursor(0)[1]
	M.ask_date(field:gsub("^%l", string.upper) .. " date", task[field], function(date)
		vim.api.nvim_buf_set_lines(buf, row - 1, row, false, { M.set_date(line, field, date) })
	end)
end

function M.priority_current()
	local task, line = current()
	if not task then
		return util.notify("Not on a task", "warn")
	end
	local items = {}
	for i, name in ipairs(M.priority_names) do
		items[i] = { n = i, label = (M.priorities[i] or "  ") .. "  " .. name }
	end
	vim.ui.select(items, {
		prompt = "Priority",
		format_item = function(item)
			return item.label
		end,
	}, function(item)
		if item then
			replace({ M.set_priority(line, item.n) })
		end
	end)
end

function M.recur_current()
	local task, line = current()
	if not task then
		return util.notify("Not on a task", "warn")
	end
	vim.ui.input({ prompt = "Repeat (every week, every 2 days, every month on the 1st, ...)", default = task.recur or "every " }, function(rule)
		if rule == nil then
			return
		end
		rule = vim.trim(rule)
		if rule ~= "" and not M.next_date(rule, D.today()) then
			return util.notify("Can't understand “" .. rule .. "”", "warn")
		end
		replace({ M.set_recur(line, rule ~= "" and rule or nil) })
	end)
end

-- Capturing ----------------------------------------------------------------------------

--- Turn a sentence into a task line:
---   "Call Anna tomorrow !high #phone"  ->  - [ ] Call Anna #phone ⏫ 📅 2026-11-26
---   "Water the plants every 3 days"    ->  - [ ] Water the plants 🔁 every 3 days 📅 ...
function M.from_text(text, today)
	today = today or D.today()
	local priority, recur
	text = text:gsub("^%s*[-*+]%s+%[.%]%s*", "")
	local words = { ["!highest"] = 1, ["!high"] = 2, ["!medium"] = 3, ["!low"] = 5, ["!lowest"] = 6, ["!!!"] = 1, ["!!"] = 2, ["!"] = 3 }
	text = (" " .. text .. " "):gsub("%s(!%S*)%f[%s]", function(word)
		if words[word:lower()] then
			priority = words[word:lower()]
			return ""
		end
	end)
	text = vim.trim(text)
	local before, rule, after = text:match("^(.-)%f[%a]([Ee]very%s+.-)%s*(#.*)$")
	if not before then
		before, rule = text:match("^(.-)%f[%a]([Ee]very%s+.+)$")
		after = ""
	end
	if rule then
		-- The longest start of "every ..." that makes sense as a rule.
		local parts = vim.split(rule, "%s+")
		for n = #parts, 2, -1 do
			local candidate = table.concat(parts, " ", 1, n):lower()
			if M.next_date(candidate, today) then
				recur = candidate
				text = vim.trim(before .. " " .. table.concat(parts, " ", n + 1) .. " " .. after)
				break
			end
		end
	end
	local date, rest = D.extract(text, today)
	text = date and rest or text
	if recur and not date then
		date = M.next_date(recur, D.add(today, -1, "day"))
	end
	local line = "- [ ] " .. vim.trim((text:gsub("%s+", " ")))
	if priority then
		line = M.set_priority(line, priority)
	end
	if recur then
		line = M.set_recur(line, recur)
	end
	if date then
		line = M.set_date(line, "due", date)
	end
	return line
end

--- Insert lines under a heading in a list of lines: after the last list item
--- of that section, or in a new section at the end.
function M.insert_under(lines, heading, new)
	local out = vim.deepcopy(lines)
	if not heading or heading == "" then
		vim.list_extend(out, new)
		return out
	end
	local at, level
	for i, line in ipairs(lines) do
		local hashes, text = line:match("^(#+)%s+(.-)%s*$")
		if hashes then
			if at and #hashes <= level then
				break
			elseif not at and text:lower() == heading:lower() then
				at, level = i, #hashes
			end
		elseif at and line:match("^%s*[-*+]%s") then
			at = i
		elseif at and line:match("^%s+%S") and lines[at]:match("^%s*[-*+]%s") then
			at = i -- continuation of a list item
		elseif at and lines[at]:match("^%s*[-*+]%s") and line:match("%S") then
			break -- text after the list
		end
	end
	if not at then
		while #out > 0 and out[#out]:match("^%s*$") do
			table.remove(out)
		end
		vim.list_extend(out, { "", "## " .. heading, "" })
		vim.list_extend(out, new)
		return out
	end
	if lines[at]:match("^#") then
		-- An empty section: leave one blank line after the heading.
		if not (lines[at + 1] or ""):match("^%s*$") or lines[at + 1] == nil then
			table.insert(out, at + 1, "")
		end
		at = at + 1
	end
	for i, line in ipairs(new) do
		table.insert(out, at + i, line)
	end
	local following = out[at + #new + 1]
	if following and following:match("^#+%s") then
		table.insert(out, at + #new + 1, "")
	end
	return out
end

--- Add lines to a note on disk (or its buffer), under a heading.
function M.add_to_note(path, heading, new)
	local buf = vim.fn.bufnr("^" .. vim.fn.escape(path, "\\[]^$.*~") .. "$")
	if buf ~= -1 and vim.api.nvim_buf_is_loaded(buf) then
		local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, M.insert_under(lines, heading, new))
		vim.api.nvim_buf_call(buf, function()
			vim.cmd("silent noautocmd update")
		end)
	else
		local text = util.read(path) or ""
		local lines = text == "" and {} or util.lines(text)
		util.write(path, table.concat(M.insert_under(lines, heading, new), "\n") .. "\n")
	end
	require("notes.index").update(path)
	vim.api.nvim_exec_autocmds("User", { pattern = "NotesChanged", data = { path = path } })
end

--- Where new tasks go (settings.task_capture).
function M.capture_path()
	local settings, vault = require("settings"), require("notes.vault")
	if settings.task_capture == "daily" then
		return require("notes.periodic").ensure("daily", D.today())
	elseif settings.task_capture == "inbox" then
		return vault.folder("inbox") .. "/Tasks.md"
	end
	return vault.abs((settings.task_capture:gsub("%.md$", "")) .. ".md")
end

function M.capture()
	if require("settings").task_capture == "todoist" then
		return require("notes.todoist").capture()
	end
	util.input({ prompt = "Task (“Call Anna tomorrow !high #phone”)" }, function(text)
		local line = M.from_text(text)
		local path = M.capture_path()
		M.add_to_note(path, require("settings").task_heading, { line })
		util.notify("Added to " .. vim.fs.basename(path):gsub("%.md$", "") .. "\n" .. line:gsub("^- %[ %] ", ""))
	end)
end

return M
