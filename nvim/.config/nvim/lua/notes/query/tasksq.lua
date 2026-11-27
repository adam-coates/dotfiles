-- Queries of Obsidian's Tasks plugin, one instruction per line:
--
--   not done
--   due before in two weeks
--   (tags include #work) OR (path includes Projects)
--   group by due
--   sort by priority
--   limit 20

local D = require("notes.date")
local T = require("notes.tasks")
local index = require("notes.index")

local M = {}

local FIELD = { due = "due", scheduled = "scheduled", starts = "start", start = "start", created = "created", done = "done", cancelled = "cancelled" }

local function text_filter(get)
	return function(op, value)
		value = vim.trim(value)
		local lower = value:lower()
		if op == "includes" or op == "include" then
			return function(row)
				return get(row):lower():find(lower, 1, true) ~= nil
			end
		elseif op == "does not include" or op == "do not include" then
			return function(row)
				return get(row):lower():find(lower, 1, true) == nil
			end
		end
		local body, flags = value:match("^/(.*)/(%a*)$")
		local re = require("notes.query.expr").regex((flags or ""):find("i") and ("\\c" .. body) or (body or value))
		local negate = op:find("not") ~= nil
		return function(row)
			return (re:match_str(get(row)) ~= nil) ~= negate
		end
	end
end

local TEXT = {
	path = function(r)
		return r.entry.rel
	end,
	folder = function(r)
		return r.entry.folder .. "/"
	end,
	root = function(r)
		return r.entry.rel:match("^([^/]+)/") or "/"
	end,
	filename = function(r)
		return r.entry.name .. ".md"
	end,
	description = function(r)
		return r.task.text
	end,
	heading = function(r)
		return r.task.section or ""
	end,
	recurrence = function(r)
		return r.task.recur or ""
	end,
	["status.name"] = function(r)
		return ({ [" "] = "Todo", ["/"] = "In Progress", x = "Done", X = "Done", ["-"] = "Cancelled" })[r.task.status] or "Todo"
	end,
}

local STATUS = { [" "] = "TODO", ["/"] = "IN_PROGRESS", x = "DONE", X = "DONE", ["-"] = "CANCELLED", [">"] = "TODO", ["!"] = "TODO" }

local function happens(task, fn)
	for _, field in ipairs({ "due", "scheduled", "start" }) do
		if task[field] and fn(task[field]) then
			return true
		end
	end
	return false
end

-- "this week", "next month", "2026-W48", "2026-11" as a first and last day
local function range(text)
	local today = D.today()
	local which, unit = text:match("^(%a+) (%a+)$")
	local shift = which == "this" and 0 or which == "next" and 1 or which == "last" and -1 or nil
	if shift then
		if unit == "week" then
			local first = D.add(D.week_start(today, 1), 7 * shift, "day")
			return first, D.add(first, 6, "day")
		elseif unit == "month" or unit == "quarter" then
			local y, m = tonumber(today:sub(1, 4)), tonumber(today:sub(6, 7))
			if unit == "quarter" then
				m = math.floor((m - 1) / 3) * 3 + 1
			end
			local first = D.add(("%04d-%02d-01"):format(y, m), shift, unit)
			return first, D.add(D.add(first, 1, unit), -1, "day")
		elseif unit == "year" then
			local y = tonumber(today:sub(1, 4)) + shift
			return y .. "-01-01", y .. "-12-31"
		end
	end
	local y, w = text:match("^(%d%d%d%d)%-w(%d%d)$")
	if y then
		local first = D.add(D.week_start(y .. "-01-04", 1), (tonumber(w) - 1) * 7, "day")
		return first, D.add(first, 6, "day")
	end
	if text:match("^%d%d%d%d%-%d%d$") then
		local first = text .. "-01"
		return first, D.add(D.add(first, 1, "month"), -1, "day")
	end
	local a, b = text:match("^(%S+) (%S+)$")
	if a and D.is(a) and D.is(b) then
		return a, b
	end
end

local function date_filter(field, op, value)
	value = vim.trim(value:lower())
	local first, last = range(value)
	if not first then
		first = D.parse(value)
		last = first
	end
	if not first then
		error("not a date: “" .. value .. "”", 0)
	end
	local test
	if op == "before" then
		test = function(d)
			return d < first
		end
	elseif op == "after" then
		test = function(d)
			return d > last
		end
	elseif op == "on or before" or op == "in or before" then
		test = function(d)
			return d <= last
		end
	elseif op == "on or after" or op == "in or after" then
		test = function(d)
			return d >= first
		end
	else
		test = function(d)
			return d >= first and d <= last
		end
	end
	return function(row)
		if field == "happens" then
			return happens(row.task, test)
		end
		local date = row.task[field]
		if field == "start" and not date then
			return true -- tasks without a start date have always started
		end
		return date ~= nil and test(date)
	end
end

local filter

-- "(a) AND (b) OR NOT (c)": split on operators outside parentheses.
local function boolean(line)
	local parts, depth, start, i = {}, 0, 1, 1
	local function push(stop)
		local part = vim.trim(line:sub(start, stop))
		if part ~= "" then
			parts[#parts + 1] = part
		end
	end
	while i <= #line do
		local c = line:sub(i, i)
		if c == "(" then
			depth = depth + 1
		elseif c == ")" then
			depth = depth - 1
		elseif depth == 0 then
			local op = line:sub(i):match("^(AND NOT)%f[%W]") or line:sub(i):match("^(OR NOT)%f[%W]") or line:sub(i):match("^(AND)%f[%W]") or line:sub(i):match("^(OR)%f[%W]") or line:sub(i):match("^(XOR)%f[%W]")
			if op and (i == 1 or line:sub(i - 1, i - 1):match("[%s%)]")) then
				push(i - 1)
				parts[#parts + 1] = { op }
				i = i + #op
				start = i
				goto continue
			end
		end
		i = i + 1
		::continue::
	end
	push(#line)
	if #parts < 2 then
		return nil
	end
	local function operand(part)
		return filter(part)
	end
	if type(parts[1]) ~= "string" then
		return nil
	end
	-- AND binds tighter than OR
	local ors = { { operand(parts[1]) } }
	local k = 2
	while k <= #parts do
		local op, rhs = parts[k], parts[k + 1]
		if type(op) ~= "table" or type(rhs) ~= "string" then
			error("can't read “" .. line .. "”", 0)
		end
		local fn = operand(rhs)
		if op[1]:find("NOT") then
			local inner = fn
			fn = function(row)
				return not inner(row)
			end
		end
		if vim.startswith(op[1], "AND") then
			table.insert(ors[#ors], fn)
		else
			ors[#ors + 1] = { fn }
		end
		k = k + 2
	end
	return function(row)
		for _, ands in ipairs(ors) do
			local ok = true
			for _, fn in ipairs(ands) do
				ok = ok and fn(row)
			end
			if ok then
				return true
			end
		end
		return false
	end
end

filter = function(line)
	line = vim.trim(line)
	-- Only strip parentheses that enclose the whole line.
	if line:match("^%b()$") then
		return filter(line:sub(2, -2))
	end
	local negated = line:match("^NOT%s+(.+)$")
	if negated then
		local inner = filter(negated)
		return function(row)
			return not inner(row)
		end
	end
	local bool = boolean(line)
	if bool then
		return bool
	end

	local lower = line:lower()
	if lower == "done" then
		return function(row)
			return T.is_done(row.task.status)
		end
	elseif lower == "not done" then
		return function(row)
			return not T.is_done(row.task.status)
		end
	elseif lower == "is recurring" or lower == "is not recurring" then
		return function(row)
			return (row.task.recur ~= nil) == (lower == "is recurring")
		end
	elseif lower == "exclude sub-items" then
		return function(row)
			return (row.task.indent or 0) == 0
		end
	elseif lower == "has tags" or lower == "has tag" then
		return function(row)
			return #row.task.tags > 0
		end
	elseif lower == "no tags" or lower == "no tag" then
		return function(row)
			return #row.task.tags == 0
		end
	end

	local type_op, type_value = line:match("^status%.type%s+(is%s?n?o?t?)%s+(%S+)$")
	if type_op then
		return function(row)
			return ((STATUS[row.task.status] or "TODO") == type_value:upper()) == (vim.trim(type_op) == "is")
		end
	end

	local has, which = lower:match("^(has) (%a+) date$")
	if not has then
		has, which = lower:match("^(no) (%a+) date$")
	end
	if has and (FIELD[which] or which == "happens") then
		return function(row)
			local value
			if which == "happens" then
				value = T.happens(row.task)
			else
				value = row.task[FIELD[which]]
			end
			return (value ~= nil) == (has == "has")
		end
	end

	local word, rest = line:match("^([%a%.]+)%s+(.+)$")
	word = word and word:lower()
	if word and (FIELD[word] or word == "happens") then
		for _, op in ipairs({ "on or before", "on or after", "in or before", "in or after", "before", "after", "on", "in" }) do
			if rest:lower():sub(1, #op + 1) == op .. " " then
				return date_filter(word == "happens" and word or FIELD[word], op, rest:sub(#op + 2))
			end
		end
		return date_filter(word == "happens" and word or FIELD[word], "on", rest)
	end

	if word == "priority" then
		local cmp, name = rest:lower():match("^is%s+(%a+)%s+(%a+)$")
		if not cmp then
			cmp, name = "", rest:lower():match("^is%s+(%a+)$")
		end
		local level
		for i, n in ipairs(T.priority_names) do
			if n == name then
				level = i
			end
		end
		if not level then
			error("unknown priority “" .. rest .. "”", 0)
		end
		return function(row)
			local p = row.task.priority
			if cmp == "above" then
				return p < level
			elseif cmp == "below" then
				return p > level
			elseif cmp == "not" then
				return p ~= level
			end
			return p == level
		end
	end

	if word == "tag" or word == "tags" then
		local op, value = rest:match("^(includes?)%s+(.+)$")
		if not op then
			op, value = rest:match("^(do[es]* not include)%s+(.+)$")
		end
		if op then
			local want = value:lower():gsub("^#", "")
			local negate = op:find("not") ~= nil
			return function(row)
				local hit = false
				for _, tag in ipairs(row.task.tags) do
					hit = hit or tag:lower():find(want, 1, true) ~= nil
				end
				return hit ~= negate
			end
		end
	end

	if word and TEXT[word] then
		for _, op in ipairs({ "includes", "does not include", "regex matches", "regex does not match" }) do
			if rest:sub(1, #op + 1) == op .. " " then
				return text_filter(TEXT[word])(op, rest:sub(#op + 2))
			end
		end
	end
	error("don't understand “" .. line .. "”", 0)
end

-- Sorting and grouping --------------------------------------------------------------

local function urgency(task)
	local today, score = D.today(), 0
	if task.due then
		local late = D.diff(task.due, today)
		score = score + 12 * math.max(0.2, math.min(1, (late + 14) / 21 * 0.8 + 0.2))
	end
	if task.scheduled and task.scheduled <= today then
		score = score + 5
	end
	if task.start and task.start > today then
		score = score - 3
	end
	return score + ({ 9, 6, 3.9, 1.95, 0, -1.8 })[task.priority]
end
M.urgency = urgency

local LAST = "9999-99-99"
local KEY = {
	due = function(r)
		return r.task.due or LAST
	end,
	scheduled = function(r)
		return r.task.scheduled or LAST
	end,
	start = function(r)
		return r.task.start or LAST
	end,
	created = function(r)
		return r.task.created or LAST
	end,
	done = function(r)
		return r.task.done or LAST
	end,
	happens = function(r)
		return T.happens(r.task) or LAST
	end,
	priority = function(r)
		return r.task.priority
	end,
	urgency = function(r)
		return -urgency(r.task)
	end,
	path = function(r)
		return r.entry.rel:lower()
	end,
	filename = function(r)
		return r.entry.name:lower()
	end,
	description = function(r)
		return r.task.text:lower()
	end,
	heading = function(r)
		return (r.task.section or ""):lower()
	end,
	status = function(r)
		return T.is_done(r.task.status) and 1 or 0
	end,
	tag = function(r)
		return (r.task.tags[1] or "~"):lower()
	end,
}
KEY["status.type"], KEY["status.name"] = KEY.status, KEY.status

local function day_name(iso)
	return iso and (iso .. " " .. os.date("%A", D.time(iso))) or nil
end
local GROUP = {
	due = function(r)
		return day_name(r.task.due) or "No due date"
	end,
	scheduled = function(r)
		return day_name(r.task.scheduled) or "No scheduled date"
	end,
	start = function(r)
		return day_name(r.task.start) or "No start date"
	end,
	done = function(r)
		return day_name(r.task.done) or "Not done"
	end,
	happens = function(r)
		return day_name(T.happens(r.task)) or "No date"
	end,
	priority = function(r)
		return "Priority " .. r.task.priority .. ": " .. T.priority_names[r.task.priority]
	end,
	path = function(r)
		return r.entry.rel:gsub("%.md$", "")
	end,
	folder = function(r)
		return r.entry.folder ~= "" and r.entry.folder or "/"
	end,
	root = function(r)
		return r.entry.rel:match("^([^/]+)/") or "/"
	end,
	filename = function(r)
		return r.entry.name
	end,
	backlink = function(r)
		return r.entry.name .. (r.task.section and (" > " .. r.task.section) or "")
	end,
	heading = function(r)
		return r.task.section or "(no heading)"
	end,
	tags = function(r)
		return r.task.tags[1] and ("#" .. r.task.tags[1]) or "(no tags)"
	end,
	recurring = function(r)
		return r.task.recur and "Recurring" or "Not recurring"
	end,
	status = function(r)
		return T.is_done(r.task.status) and "Done" or "Todo"
	end,
}
GROUP["status.type"], GROUP["status.name"], GROUP.tag = GROUP.status, TEXT["status.name"], GROUP.tags

local function sorted(rows, keys)
	for i, row in ipairs(rows) do
		row.order = i
	end
	table.sort(rows, function(a, b)
		for _, key in ipairs(keys) do
			local x, y = KEY[key.name](a), KEY[key.name](b)
			if x ~= y then
				if key.reverse then
					return x > y
				end
				return x < y
			end
		end
		return a.order < b.order
	end)
	return rows
end

function M.parse(text)
	local q = { filters = {}, sort = {}, group = {}, hide = {} }
	for _, raw in ipairs(vim.split(text, "\n")) do
		local line = vim.trim(raw)
		local lower = line:lower()
		if line == "" or line:sub(1, 1) == "#" then
			goto continue
		end
		local name, rev = lower:match("^sort by ([%w%.]+)%s*(%a*)$")
		if name then
			name = name == "tags" and "tag" or name
			if not KEY[name] then
				error("can't sort by “" .. name .. "”", 0)
			end
			table.insert(q.sort, { name = name, reverse = rev == "reverse" })
			goto continue
		end
		name, rev = lower:match("^group by ([%w%.]+)%s*(%a*)$")
		if name then
			if not GROUP[name] then
				error("can't group by “" .. name .. "”", 0)
			end
			table.insert(q.group, { name = name, reverse = rev == "reverse" })
			goto continue
		end
		local n = lower:match("^limit t?o?%s*(%d+)") or lower:match("^limit (%d+)")
		if n then
			q.limit = tonumber(n)
			goto continue
		end
		local hidden = lower:match("^hide (.+)$")
		if hidden then
			q.hide[hidden] = true
			goto continue
		end
		if lower == "short mode" or lower == "short" then
			q.short = true
			goto continue
		elseif lower == "full mode" or lower == "full" or lower == "explain" or lower:match("^show ") or lower:match("^ignore ") then
			goto continue
		end
		table.insert(q.filters, filter(line))
		::continue::
	end
	return q
end

function M.run(q)
	local rows = {}
	for _, item in ipairs(index.tasks()) do
		local row = { entry = item.entry, task = item.task }
		local ok = row.task.text ~= "" or row.task.body ~= ""
		for _, fn in ipairs(q.filters) do
			ok = ok and fn(row)
		end
		if ok then
			rows[#rows + 1] = row
		end
	end
	local keys = vim.list_extend({}, q.sort)
	if #keys == 0 then
		keys = { { name = "status" }, { name = "urgency" }, { name = "due" }, { name = "priority" }, { name = "path" } }
	end
	sorted(rows, keys)
	local total = #rows
	if q.limit then
		rows = vim.list_slice(rows, 1, q.limit)
	end
	local result = { type = "task", groups = {}, count = #rows, total = total, short = q.short, hide = q.hide, flat = true }
	if #q.group == 0 then
		result.groups[1] = { tasks = rows }
		return result
	end
	local by, order = {}, {}
	for _, row in ipairs(rows) do
		local names = {}
		for i, g in ipairs(q.group) do
			names[i] = GROUP[g.name](row)
		end
		local name = table.concat(names, " · ")
		if not by[name] then
			by[name] = {}
			order[#order + 1] = name
		end
		table.insert(by[name], row)
	end
	table.sort(order, function(a, b)
		-- "No due date" goes last
		local na, nb = a:match("^No ") ~= nil, b:match("^No ") ~= nil
		if na ~= nb then
			return nb
		end
		if q.group[1].reverse then
			return a > b
		end
		return a < b
	end)
	for _, name in ipairs(order) do
		table.insert(result.groups, { name = name, tasks = by[name] })
	end
	return result
end

function M.query(text)
	local ok, result = pcall(function()
		return M.run(M.parse(text))
	end)
	if ok then
		return result
	end
	return { error = (tostring(result):gsub("^[^:]+%.lua:%d+: ", "")) }
end

return M
