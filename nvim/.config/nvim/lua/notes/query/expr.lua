-- Expressions for dataview-style queries: a tokenizer, a precedence parser and an
-- evaluator. Covers the parts of Dataview's language people use in notes; see
-- query/dql.lua for the queries around them.

local D = require("notes.date")

local M = {}

-- Values -----------------------------------------------------------------------
-- nil is NULL; strings, numbers and booleans are themselves; everything else is
-- a table with a `kind`.

M.NULL = setmetatable({ kind = "null" }, {
	__tostring = function()
		return "—"
	end,
})
local NULL = M.NULL

function M.list(items)
	return { kind = "list", items = items }
end

function M.link(target, display, entry)
	return { kind = "link", target = target, display = display, entry = entry }
end

--- A date from "2026-11-25" or "2026-11-25T10:30", or from a timestamp.
function M.date(value)
	if type(value) == "number" then
		return { kind = "date", iso = os.date("%Y-%m-%d", value), ts = value }
	end
	local iso = value:match("^(%d%d%d%d%-%d%d%-%d%d)")
	if iso and D.valid(iso) then
		local h, m, s = value:match("^%d+%-%d+%-%d+[T ](%d%d):(%d%d):?(%d*)")
		local base = D.time(iso) - 12 * 3600
		if h then
			base = base + tonumber(h) * 3600 + tonumber(m) * 60 + (tonumber(s) or 0)
		end
		return { kind = "date", iso = iso, ts = base, clock = h and (h .. ":" .. m) or nil }
	end
	local ym = value:match("^(%d%d%d%d%-%d%d)$")
	return ym and M.date(ym .. "-01") or nil
end

function M.kind(v)
	if v == nil or v == NULL then
		return "null"
	elseif type(v) == "table" then
		return v.kind or "object"
	end
	return type(v)
end

--- A frontmatter or inline-field value as a query value.
function M.from(raw, resolve)
	if raw == nil or raw == vim.NIL then
		return NULL
	elseif type(raw) == "string" then
		local text = vim.trim(raw)
		local target = text:match("^!?%[%[([^%]]+)%]%]$")
		if target then
			local path, display = target:match("^(.-)|(.*)$")
			return M.link(path or target, display, resolve and resolve(path or target))
		end
		if text:match("^%d%d%d%d%-%d%d%-%d%d") then
			return M.date(text) or raw
		end
		return raw
	elseif type(raw) == "table" then
		if raw.kind then
			return raw
		elseif vim.islist(raw) then
			return M.list(vim.tbl_map(function(item)
				return M.from(item, resolve)
			end, raw))
		end
		local map = {}
		for key, value in pairs(raw) do
			map[tostring(key):lower()] = M.from(value, resolve)
		end
		return { kind = "object", map = map }
	end
	return raw
end

--- An inline field's text: numbers, booleans and comma lists too.
function M.from_field(text, resolve)
	if tonumber(text) then
		return tonumber(text)
	elseif text == "true" or text == "false" then
		return text == "true"
	elseif text:find("%]%]%s*,%s*!?%[%[") then
		local items = {}
		for item in text:gmatch("%[%[[^%]]+%]%]") do
			items[#items + 1] = M.from(item, resolve)
		end
		return M.list(items)
	end
	return M.from(text, resolve)
end

function M.truthy(v)
	local kind = M.kind(v)
	if kind == "null" then
		return false
	elseif kind == "boolean" then
		return v
	elseif kind == "number" then
		return v ~= 0
	elseif kind == "string" then
		return v ~= ""
	elseif kind == "list" then
		return #v.items > 0
	end
	return true
end

function M.tostring(v)
	local kind = M.kind(v)
	if kind == "null" then
		return "—"
	elseif kind == "list" then
		return table.concat(vim.tbl_map(M.tostring, v.items), ", ")
	elseif kind == "link" then
		return v.display or (v.entry and v.entry.name) or vim.fs.basename(v.target)
	elseif kind == "date" then
		return v.clock and (v.iso .. " " .. v.clock) or v.iso
	elseif kind == "dur" then
		local parts = {}
		for _, unit in ipairs({ { "months", "month" }, { "days", "day" }, { "hours", "hour" }, { "minutes", "minute" } }) do
			local n = v[unit[1]]
			if n and n ~= 0 then
				parts[#parts + 1] = n .. " " .. unit[2] .. (math.abs(n) == 1 and "" or "s")
			end
		end
		return #parts > 0 and table.concat(parts, ", ") or "0 days"
	elseif kind == "number" then
		return v == math.floor(v) and ("%d"):format(v) or (("%.2f"):format(v):gsub("0+$", ""):gsub("%.$", ""))
	elseif kind == "task" then
		return v.task.text
	elseif kind == "object" then
		return v.entry and v.entry.name or "{…}"
	elseif kind == "boolean" then
		return v and "true" or "false"
	end
	return tostring(v)
end

local ORDER = { null = 0, boolean = 1, number = 2, string = 3, date = 4, dur = 5, link = 6, list = 7, object = 8, task = 9 }

local function dur_days(v)
	return (v.months or 0) * 30.44 + (v.days or 0) + (v.hours or 0) / 24 + (v.minutes or 0) / 1440
end

--- -1, 0 or 1
function M.compare(a, b)
	local ka, kb = M.kind(a), M.kind(b)
	-- A date compared with text that is a date
	if ka == "date" and kb == "string" then
		b, kb = M.date(b) or b, M.date(b) and "date" or kb
	elseif kb == "date" and ka == "string" then
		a, ka = M.date(a) or a, M.date(a) and "date" or ka
	elseif ka == "link" and kb == "string" then
		a, ka = M.tostring(a), "string"
	elseif kb == "link" and ka == "string" then
		b, kb = M.tostring(b), "string"
	end
	if ka ~= kb then
		return ORDER[ka] < ORDER[kb] and -1 or 1
	end
	if ka == "null" then
		return 0
	elseif ka == "boolean" then
		return a == b and 0 or (a and 1 or -1)
	elseif ka == "date" then
		if not (a.clock and b.clock) then -- whole days, unless both have a time
			return a.iso < b.iso and -1 or (a.iso > b.iso and 1 or 0)
		end
		a, b = a.ts, b.ts
	elseif ka == "dur" then
		a, b = dur_days(a), dur_days(b)
	elseif ka == "link" then
		a = (a.entry and a.entry.rel or a.target):lower()
		b = (b.entry and b.entry.rel or b.target):lower()
	elseif ka == "list" then
		for i = 1, math.max(#a.items, #b.items) do
			local x, y = a.items[i], b.items[i]
			if x == nil or y == nil then
				return x == nil and -1 or 1
			end
			local c = M.compare(x, y)
			if c ~= 0 then
				return c
			end
		end
		return 0
	elseif ka == "string" then
		local la, lb = a:lower(), b:lower()
		if la ~= lb then
			return la < lb and -1 or 1
		end
	elseif ka ~= "number" then
		a, b = M.tostring(a), M.tostring(b)
	end
	return a < b and -1 or (a > b and 1 or 0)
end

function M.equal(a, b)
	if type(a) == "string" and type(b) == "string" then
		return a == b
	end
	return M.compare(a, b) == 0
end

-- Tokens ---------------------------------------------------------------------------

local function tokenize(src)
	local tokens, i = {}, 1
	local function push(kind, value, len)
		tokens[#tokens + 1] = { kind = kind, value = value, at = i }
		i = i + len
	end
	while i <= #src do
		local rest = src:sub(i)
		local space = rest:match("^%s+")
		if space then
			i = i + #space
		elseif rest:match("^%[%[") then
			local body = rest:match("^%[%[([^%]]*)%]%]")
			if not body then
				error("unfinished [[link]]", 0)
			end
			push("link", body, #body + 4)
		elseif rest:match('^["]') then
			local out, j = {}, 2
			while true do
				local c = rest:sub(j, j)
				if c == "" then
					error("unfinished string", 0)
				elseif c == "\\" then
					out[#out + 1], j = rest:sub(j + 1, j + 1), j + 2
				elseif c == '"' then
					break
				else
					out[#out + 1], j = c, j + 1
				end
			end
			push("string", table.concat(out), j)
		elseif rest:match("^#[%w_/%-\128-\255]+") then
			local tag = rest:match("^#([%w_/%-\128-\255]+)")
			push("tag", tag, #tag + 1)
		elseif rest:match("^%d+%.?%d*") then
			local num = rest:match("^%d+%.%d+") or rest:match("^%d+")
			push("number", tonumber(num), #num)
		elseif rest:match("^[%a_\128-\255]") then
			local word = rest:match("^[%a_\128-\255][%w_\128-\255]*")
			-- due-date is one name, but a - b is a subtraction
			while true do
				local more = rest:sub(#word + 1):match("^%-[%a_\128-\255][%w_\128-\255]*")
				if not more then
					break
				end
				word = word .. more
			end
			push("name", word, #word)
		else
			local op = rest:match("^=>") or rest:match("^[!<>=]=") or rest:match("^<>") or rest:match("^&&") or rest:match("^||") or rest:sub(1, 1)
			if not ("=> == != <= >= <> && ||"):find(op, 1, true) and not op:match("^[=<>+%-*/%%!()%[%],.:{}&|]$") then
				error("unexpected “" .. op .. "”", 0)
			end
			push("op", op, #op)
		end
	end
	tokens[#tokens + 1] = { kind = "end", at = #src + 1 }
	return tokens
end
M.tokenize = tokenize

-- Parser ---------------------------------------------------------------------------

local Parser = {}
Parser.__index = Parser

function M.parser(src)
	return setmetatable({ tokens = tokenize(src), pos = 1, src = src }, Parser)
end

function Parser:peek(offset)
	return self.tokens[self.pos + (offset or 0)] or self.tokens[#self.tokens]
end

function Parser:next()
	local token = self:peek()
	self.pos = self.pos + 1
	return token
end

function Parser:is(kind, value)
	local token = self:peek()
	if token.kind ~= kind then
		return false
	end
	if value == nil then
		return true
	end
	return kind == "name" and token.value:lower() == value or token.value == value
end

function Parser:accept(kind, value)
	if self:is(kind, value) then
		return self:next()
	end
end

function Parser:expect(kind, value)
	local token = self:accept(kind, value)
	if not token then
		local got = self:peek()
		error(("expected “%s”, got “%s”"):format(value or kind, tostring(got.value or "end")), 0)
	end
	return token
end

local function binary(self, sub, ops)
	local left = sub(self)
	while true do
		local token = self:peek()
		local op = token.kind == "op" and ops[token.value] or (token.kind == "name" and ops[token.value:lower()])
		if not op then
			return left
		end
		self:next()
		left = { op = op, left, sub(self) }
	end
end

function Parser:expr()
	return binary(self, function(s)
		return binary(s, s.comparison, { ["and"] = "and", ["&&"] = "and", ["&"] = "and" })
	end, { ["or"] = "or", ["||"] = "or", ["|"] = "or" })
end

function Parser:comparison()
	return binary(self, self.sum, { ["="] = "=", ["=="] = "=", ["!="] = "!=", ["<>"] = "!=", ["<"] = "<", [">"] = ">", ["<="] = "<=", [">="] = ">=" })
end

function Parser:sum()
	return binary(self, self.product, { ["+"] = "+", ["-"] = "-" })
end

function Parser:product()
	return binary(self, self.unary, { ["*"] = "*", ["/"] = "/", ["%"] = "%" })
end

function Parser:unary()
	if self:accept("op", "!") or (self:is("name", "not") and self:next()) then
		return { op = "not", self:unary() }
	elseif self:accept("op", "-") then
		return { op = "neg", self:unary() }
	end
	return self:postfix()
end

function Parser:postfix()
	local node = self:primary()
	while true do
		if self:accept("op", ".") then
			local name = self:next()
			if name.kind ~= "name" then
				error("expected a field name after “.”", 0)
			end
			node = { op = "get", node, { op = "const", name.value } }
		elseif self:is("op", "[") then
			self:next()
			local index = self:expr()
			self:expect("op", "]")
			node = { op = "get", node, index }
		else
			return node
		end
	end
end

local DUR = {
	s = "minutes", sec = "minutes", second = "minutes", seconds = "minutes",
	m = "minutes", min = "minutes", mins = "minutes", minute = "minutes", minutes = "minutes",
	h = "hours", hr = "hours", hrs = "hours", hour = "hours", hours = "hours",
	d = "days", day = "days", days = "days",
	w = "weeks", wk = "weeks", wks = "weeks", week = "weeks", weeks = "weeks",
	mo = "months", month = "months", months = "months",
	y = "years", yr = "years", yrs = "years", year = "years", years = "years",
}

function M.duration(text)
	local out = { kind = "dur", months = 0, days = 0, hours = 0, minutes = 0 }
	local found = false
	for amount, unit in text:gmatch("([%d%.]+)%s*(%a+)") do
		local key, n = DUR[unit:lower()], tonumber(amount)
		if not key or not n then
			return nil
		end
		found = true
		if key == "weeks" then
			out.days = out.days + n * 7
		elseif key == "years" then
			out.months = out.months + n * 12
		else
			out[key] = out[key] + n
		end
	end
	return found and out or nil
end

function Parser:primary()
	local token = self:next()
	if token.kind == "number" or token.kind == "string" then
		return { op = "const", token.value }
	elseif token.kind == "tag" then
		return { op = "const", "#" .. token.value }
	elseif token.kind == "link" then
		return { op = "link", token.value }
	elseif token.kind == "op" and token.value == "(" then
		-- (a, b) => expr
		local save, names = self.pos, {}
		while self:is("name") do
			names[#names + 1] = self:next().value
			if not self:accept("op", ",") then
				break
			end
		end
		if self:accept("op", ")") and self:accept("op", "=>") then
			return { op = "lambda", names, self:expr() }
		end
		self.pos = save
		local node = self:expr()
		self:expect("op", ")")
		return node
	elseif token.kind == "op" and token.value == "[" then
		local items = {}
		while not self:is("op", "]") do
			items[#items + 1] = self:expr()
			if not self:accept("op", ",") then
				break
			end
		end
		self:expect("op", "]")
		return { op = "list", items }
	elseif token.kind == "name" then
		local name = token.value
		local lower = name:lower()
		if lower == "true" or lower == "false" then
			return { op = "const", lower == "true" }
		elseif lower == "null" then
			return { op = "const", NULL }
		end
		if self:is("op", "(") then
			self:next()
			-- date(today) and dur(3 days) take words, not expressions
			if lower == "date" or lower == "dur" then
				local depth, first, j = 1, self:peek().at, self.pos
				while depth > 0 do
					local t = self.tokens[j]
					if not t or t.kind == "end" then
						error("missing “)” after " .. lower, 0)
					end
					if t.kind == "op" and t.value == "(" then
						depth = depth + 1
					elseif t.kind == "op" and t.value == ")" then
						depth = depth - 1
					end
					j = j + 1
				end
				local raw = vim.trim(self.src:sub(first, self.tokens[j - 1].at - 1))
				local literal = lower == "date" and M.date_literal(raw) or lower == "dur" and M.duration(raw)
				if literal then
					self.pos = j
					return { op = "literal", lower, raw }
				end
			end
			local args = {}
			while not self:is("op", ")") do
				args[#args + 1] = self:expr()
				if not self:accept("op", ",") then
					break
				end
			end
			self:expect("op", ")")
			return { op = "call", lower, args }
		elseif self:is("op", "=>") then
			self:next()
			return { op = "lambda", { name }, self:expr() }
		end
		return { op = "field", name }
	end
	error("unexpected “" .. tostring(token.value or "end of query") .. "”", 0)
end

function M.date_literal(raw)
	local today = D.today()
	local word = raw:lower():gsub('^"(.*)"$', "%1")
	if word == "now" then
		local date = M.date(os.time())
		date.clock = os.date("%H:%M")
		return date
	end
	local y, m = tonumber(today:sub(1, 4)), tonumber(today:sub(6, 7))
	local special = {
		today = today,
		tomorrow = D.add(today, 1, "day"),
		yesterday = D.add(today, -1, "day"),
		sow = D.week_start(today, 1),
		["start-of-week"] = D.week_start(today, 1),
		eow = D.add(D.week_start(today, 1), 6, "day"),
		["end-of-week"] = D.add(D.week_start(today, 1), 6, "day"),
		som = today:sub(1, 7) .. "-01",
		["start-of-month"] = today:sub(1, 7) .. "-01",
		eom = ("%04d-%02d-%02d"):format(y, m, D.days_in_month(y, m)),
		["end-of-month"] = ("%04d-%02d-%02d"):format(y, m, D.days_in_month(y, m)),
		soy = y .. "-01-01",
		["start-of-year"] = y .. "-01-01",
		eoy = y .. "-12-31",
		["end-of-year"] = y .. "-12-31",
	}
	return M.date(special[word] or word)
end

function M.parse(src)
	local parser = M.parser(src)
	local node = parser:expr()
	if parser:peek().kind ~= "end" then
		error("unexpected “" .. tostring(parser:peek().value) .. "”", 0)
	end
	return node
end

-- Evaluation -----------------------------------------------------------------------
-- ctx: get(name) -> value, resolve(target) -> entry

local function add_dur(date, dur, sign)
	local iso = date.iso
	if (dur.months or 0) ~= 0 then
		iso = D.add(iso, sign * dur.months, "month")
	end
	if (dur.days or 0) ~= 0 then
		iso = D.add(iso, sign * math.floor(dur.days), "day")
	end
	local out = M.date(iso .. (date.clock and ("T" .. date.clock) or ""))
	local secs = sign * ((dur.hours or 0) * 3600 + (dur.minutes or 0) * 60)
	if secs ~= 0 then
		out = M.date(out.ts + secs)
		out.clock = os.date("%H:%M", out.ts)
	end
	return out
end

local function arith(op, a, b)
	local ka, kb = M.kind(a), M.kind(b)
	if ka == "null" or kb == "null" then
		if op == "+" and (ka == "string" or kb == "string") then
			return (ka == "null" and "" or M.tostring(a)) .. (kb == "null" and "" or M.tostring(b))
		end
		return NULL
	end
	if op == "+" then
		if ka == "date" and kb == "dur" then
			return add_dur(a, b, 1)
		elseif ka == "dur" and kb == "date" then
			return add_dur(b, a, 1)
		elseif ka == "dur" and kb == "dur" then
			return { kind = "dur", months = a.months + b.months, days = a.days + b.days, hours = a.hours + b.hours, minutes = a.minutes + b.minutes }
		elseif ka == "number" and kb == "number" then
			return a + b
		elseif ka == "list" then
			local items = vim.list_extend({}, a.items)
			vim.list_extend(items, kb == "list" and b.items or { b })
			return M.list(items)
		end
		return M.tostring(a) .. M.tostring(b)
	elseif op == "-" then
		if ka == "date" and kb == "dur" then
			return add_dur(a, b, -1)
		elseif ka == "date" and kb == "date" then
			return { kind = "dur", months = 0, days = D.diff(b.iso, a.iso), hours = 0, minutes = 0 }
		elseif ka == "dur" and kb == "dur" then
			return { kind = "dur", months = a.months - b.months, days = a.days - b.days, hours = a.hours - b.hours, minutes = a.minutes - b.minutes }
		end
	end
	if ka == "string" and tonumber(a) then
		a, ka = tonumber(a), "number"
	end
	if kb == "string" and tonumber(b) then
		b, kb = tonumber(b), "number"
	end
	if ka ~= "number" or kb ~= "number" then
		error(("can't use “%s” on %s and %s"):format(op, ka, kb), 0)
	end
	if op == "-" then
		return a - b
	elseif op == "*" then
		return a * b
	elseif op == "/" then
		return b == 0 and NULL or a / b
	end
	return b == 0 and NULL or a % b
end

local function items_of(v)
	if M.kind(v) == "list" then
		return v.items
	elseif M.kind(v) == "null" then
		return {}
	end
	return { v }
end

local function numbers(v)
	local out = {}
	for _, item in ipairs(items_of(v)) do
		local n = type(item) == "number" and item or tonumber(M.tostring(item))
		if n then
			out[#out + 1] = n
		end
	end
	return out
end

-- contains(): lists by element (recursing), text by substring
local function contains(haystack, needle, fold)
	local kind = M.kind(haystack)
	if kind == "list" then
		for _, item in ipairs(haystack.items) do
			if contains(item, needle, fold) and (M.kind(item) ~= "string" or fold == "any") or M.equal(item, needle) then
				return true
			end
			if type(item) == "string" and type(needle) == "string" then
				local a, b = item, needle
				if fold then
					a, b = a:lower(), b:lower()
				end
				-- Tags: contains(file.tags, "#a") is true for #a/b
				if a == b or (b:sub(1, 1) == "#" and a:sub(1, #b + 1) == b .. "/") then
					return true
				end
			end
		end
		return false
	elseif kind == "null" then
		return false
	elseif kind == "object" and haystack.map then
		return haystack.map[M.tostring(needle):lower()] ~= nil
	elseif kind == "link" and M.kind(needle) == "link" then
		return M.equal(haystack, needle)
	end
	local a, b = M.tostring(haystack), M.tostring(needle)
	if fold then
		a, b = a:lower(), b:lower()
	end
	return a:find(b, 1, true) ~= nil
end

-- A regular expression with Vim's engine.
local function regex(pattern)
	local ok, re = pcall(vim.regex, "\\v" .. pattern:gsub("%(%?:", "%%("):gsub("\\b", "%%(<|>)"):gsub("([=@&~<])", "\\%1"):gsub("\\\\([=@&~<])", "\\%1"))
	if not ok then
		error("bad regular expression “" .. pattern .. "”", 0)
	end
	return re
end
M.regex = regex

local F = {}
M.functions = F

function F.contains(a, b)
	return contains(a, b)
end
function F.icontains(a, b)
	return contains(a, b, true)
end
function F.econtains(a, b)
	if M.kind(a) == "list" then
		for _, item in ipairs(a.items) do
			if M.equal(item, b) then
				return true
			end
		end
		return false
	end
	return contains(a, b)
end
F.containsword = function(a, b)
	return (" " .. M.tostring(a):lower():gsub("%W", " ") .. " "):find(" " .. M.tostring(b):lower() .. " ", 1, true) ~= nil
end
function F.length(v)
	local kind = M.kind(v)
	if kind == "list" then
		return #v.items
	elseif kind == "null" then
		return 0
	end
	return vim.fn.strchars(M.tostring(v))
end
function F.lower(v)
	return vim.fn.tolower(M.tostring(v))
end
function F.upper(v)
	return vim.fn.toupper(M.tostring(v))
end
function F.default(v, d)
	return M.kind(v) == "null" and d or v
end
F.ldefault = F.default
function F.choice(c, a, b)
	if M.truthy(c) then
		return a
	end
	return b == nil and NULL or b
end
F["if"] = F.choice
function F.join(v, sep)
	return table.concat(vim.tbl_map(M.tostring, items_of(v)), sep and M.tostring(sep) or ", ")
end
function F.split(v, sep)
	return M.list(vim.split(M.tostring(v), sep and M.tostring(sep) or ",", { plain = true }))
end
function F.startswith(a, b)
	return vim.startswith(M.tostring(a), M.tostring(b))
end
function F.endswith(a, b)
	return vim.endswith(M.tostring(a), M.tostring(b))
end
function F.replace(a, b, c)
	return (M.tostring(a):gsub(vim.pesc(M.tostring(b)), (M.tostring(c):gsub("%%", "%%%%"))))
end
function F.regexmatch(pattern, v)
	local text = M.tostring(v)
	local s, e = regex(M.tostring(pattern)):match_str(text)
	return s == 0 and e == #text
end
function F.regextest(pattern, v)
	return regex(M.tostring(pattern)):match_str(M.tostring(v)) ~= nil
end
function F.substring(v, a, b)
	return vim.fn.strcharpart(M.tostring(v), a, b and (b - a) or nil)
end
function F.truncate(v, n, suffix)
	local text = M.tostring(v)
	if vim.fn.strchars(text) <= n then
		return text
	end
	return vim.fn.strcharpart(text, 0, n) .. (suffix and M.tostring(suffix) or "…")
end
function F.round(v, digits)
	if type(v) ~= "number" then
		return NULL
	end
	local scale = 10 ^ (digits or 0)
	return math.floor(v * scale + 0.5) / scale
end
function F.floor(v)
	return math.floor(v)
end
function F.ceil(v)
	return math.ceil(v)
end
function F.abs(v)
	return math.abs(v)
end
function F.sum(v)
	local total = 0
	for _, n in ipairs(numbers(v)) do
		total = total + n
	end
	return total
end
function F.average(v)
	local list = numbers(v)
	return #list > 0 and F.sum(v) / #list or NULL
end
local function extreme(sign)
	return function(...)
		local best
		for _, arg in ipairs({ ... }) do
			for _, item in ipairs(items_of(arg)) do
				if M.kind(item) ~= "null" and (best == nil or M.compare(item, best) * sign > 0) then
					best = item
				end
			end
		end
		return best == nil and NULL or best
	end
end
F.min, F.max = extreme(-1), extreme(1)
function F.number(v)
	return tonumber(M.tostring(v):match("-?%d+%.?%d*")) or NULL
end
function F.string(v)
	return M.tostring(v)
end
F["typeof"] = function(v)
	return M.kind(v)
end
function F.list(...)
	return M.list({ ... })
end
F.array = F.list
function F.link(target, display)
	if M.kind(target) == "link" then
		return M.link(target.target, display and M.tostring(display) or target.display, target.entry)
	end
	return M.link(M.tostring(target), display and M.tostring(display), require("notes.index").resolve(M.tostring(target)))
end
F.elink = function(_, display)
	return display and M.tostring(display) or NULL
end
function F.date(v)
	local kind = M.kind(v)
	if kind == "date" then
		return v
	elseif kind == "link" then
		return M.date((v.entry and v.entry.name or v.target):match("%d%d%d%d%-%d%d%-%d%d") or "") or NULL
	end
	return M.date(M.tostring(v)) or NULL
end
function F.dur(v)
	return M.kind(v) == "dur" and v or M.duration(M.tostring(v)) or NULL
end
function F.dateformat(v, fmt)
	v = F.date(v)
	if M.kind(v) ~= "date" then
		return NULL
	end
	local strf = fmt:gsub("yyyy", "%%Y"):gsub("yy", "%%y"):gsub("MMMM", "%%B"):gsub("MMM", "%%b"):gsub("MM", "%%m"):gsub("dd", "%%d"):gsub("EEEE", "%%A"):gsub("EEE", "%%a"):gsub("HH", "%%H"):gsub("mm", "%%M"):gsub("WW", "%%V"):gsub("kkkk", "%%G")
	return os.date(strf, v.ts)
end
F.striptime = function(v)
	v = F.date(v)
	return M.kind(v) == "date" and M.date(v.iso) or NULL
end
function F.reverse(v)
	local out = {}
	for i = #items_of(v), 1, -1 do
		out[#out + 1] = items_of(v)[i]
	end
	return M.list(out)
end
function F.sort(v, fn)
	local out = vim.list_extend({}, items_of(v))
	table.sort(out, function(a, b)
		if type(fn) == "function" then
			a, b = fn(a), fn(b)
		end
		return M.compare(a, b) < 0
	end)
	return M.list(out)
end
function F.unique(v)
	local out = {}
	for _, item in ipairs(items_of(v)) do
		local seen = false
		for _, other in ipairs(out) do
			seen = seen or M.equal(item, other)
		end
		if not seen then
			out[#out + 1] = item
		end
	end
	return M.list(out)
end
function F.nonnull(v)
	return M.list(vim.tbl_filter(function(item)
		return M.kind(item) ~= "null"
	end, items_of(v)))
end
function F.flat(v)
	local out = {}
	for _, item in ipairs(items_of(v)) do
		vim.list_extend(out, items_of(item))
	end
	return M.list(out)
end
function F.filter(v, fn)
	return M.list(vim.tbl_filter(function(item)
		return M.truthy(fn(item))
	end, items_of(v)))
end
function F.map(v, fn)
	return M.list(vim.tbl_map(fn, items_of(v)))
end
local function quantifier(want, all)
	return function(v, fn)
		for _, item in ipairs(items_of(v)) do
			local ok = M.truthy(type(fn) == "function" and fn(item) or (fn == nil and item) or false)
			if ok ~= all then
				return want
			end
		end
		return not want
	end
end
F.any = quantifier(true, false)
F.all = quantifier(false, true)
F.none = function(v, fn)
	return not F.any(v, fn)
end
function F.slice(v, a, b)
	local items = items_of(v)
	return M.list(vim.list_slice(items, (a or 0) + 1, b or #items))
end
function F.nonempty(v)
	return M.truthy(v)
end

function M.get(object, key)
	local kind = M.kind(object)
	if kind == "null" then
		return NULL
	elseif kind == "list" then
		if type(key) == "number" then
			local item = object.items[key + 1]
			return item == nil and NULL or item
		end
		-- list.field collects that field from every item
		local out = {}
		for _, item in ipairs(object.items) do
			local value = M.get(item, key)
			vim.list_extend(out, M.kind(value) == "list" and value.items or { value })
		end
		return M.list(out)
	elseif kind == "link" then
		if not object.entry then
			return NULL
		end
		return M.get(require("notes.query.page").page(object.entry), key)
	elseif kind == "date" then
		local y, m, d = object.iso:match("(%d+)-(%d+)-(%d+)")
		local parts = { year = tonumber(y), month = tonumber(m), day = tonumber(d), weekyear = tonumber(os.date("%V", object.ts)), week = tonumber(os.date("%V", object.ts)), weekday = (tonumber(os.date("%w", object.ts)) + 6) % 7 + 1, hour = tonumber(os.date("%H", object.ts)), minute = tonumber(os.date("%M", object.ts)) }
		return parts[tostring(key):lower()] or NULL
	elseif kind == "dur" then
		local days = dur_days(object)
		local parts = { days = math.floor(days), hours = math.floor(days * 24), weeks = math.floor(days / 7), months = math.floor(days / 30.44), years = math.floor(days / 365.25), minutes = math.floor(days * 1440) }
		return parts[tostring(key):lower()] or NULL
	elseif kind == "object" or kind == "task" then
		local value
		if object.get then
			value = object.get(tostring(key))
		elseif object.map then
			value = object.map[tostring(key):lower()]
		end
		return value == nil and NULL or value
	end
	return NULL
end

function M.eval(node, ctx)
	local op = node.op
	if op == "const" then
		return node[1]
	elseif op == "field" then
		local value = ctx.get(node[1])
		return value == nil and NULL or value
	elseif op == "link" then
		local path, display = node[1]:match("^(.-)|(.*)$")
		local target = (path or node[1]):gsub("#.*$", "")
		if target == "" then
			return ctx.this and M.link(ctx.this.name, nil, ctx.this) or NULL
		end
		return M.link(target, display, ctx.resolve and ctx.resolve(target))
	elseif op == "literal" then
		return node[1] == "date" and M.date_literal(node[2]) or M.duration(node[2])
	elseif op == "list" then
		return M.list(vim.tbl_map(function(item)
			return M.eval(item, ctx)
		end, node[1]))
	elseif op == "get" then
		return M.get(M.eval(node[1], ctx), M.eval(node[2], ctx))
	elseif op == "lambda" then
		return function(...)
			local args = { ... }
			return M.eval(node[2], {
				this = ctx.this,
				resolve = ctx.resolve,
				get = function(name)
					for i, param in ipairs(node[1]) do
						if param == name then
							return args[i]
						end
					end
					return ctx.get(name)
				end,
			})
		end
	elseif op == "call" then
		local fn = F[node[1]]
		if not fn then
			error("unknown function “" .. node[1] .. "”", 0)
		end
		local args = {}
		for i, arg in ipairs(node[2]) do
			args[i] = M.eval(arg, ctx)
		end
		local ok, value = pcall(fn, unpack(args, 1, #node[2]))
		if not ok then
			error(node[1] .. "(): " .. tostring(value):gsub("^[^:]+:%d+: ", ""), 0)
		end
		return value == nil and NULL or value
	elseif op == "and" then
		local a = M.eval(node[1], ctx)
		return M.truthy(a) and M.truthy(M.eval(node[2], ctx))
	elseif op == "or" then
		local a = M.eval(node[1], ctx)
		return M.truthy(a) or M.truthy(M.eval(node[2], ctx))
	elseif op == "not" then
		return not M.truthy(M.eval(node[1], ctx))
	elseif op == "neg" then
		return arith("-", 0, M.eval(node[1], ctx))
	end
	local a, b = M.eval(node[1], ctx), M.eval(node[2], ctx)
	if op == "=" then
		return M.equal(a, b)
	elseif op == "!=" then
		return not M.equal(a, b)
	elseif op == "<" or op == ">" or op == "<=" or op == ">=" then
		-- Nothing is smaller or larger than a missing value.
		if M.kind(a) == "null" or M.kind(b) == "null" then
			return false
		end
		local c = M.compare(a, b)
		return op == "<" and c < 0 or op == ">" and c > 0 or op == "<=" and c <= 0 or op == ">=" and c >= 0
	end
	return arith(op, a, b)
end

return M
