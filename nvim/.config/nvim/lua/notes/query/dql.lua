-- Dataview queries:
--
--   TABLE rating AS "Rating", file.mday AS "Edited"
--   FROM #book AND -"Archive"
--   WHERE rating >= 4
--   SORT rating DESC
--   LIMIT 10
--
-- LIST, TABLE and TASK with FROM, WHERE, SORT, GROUP BY, FLATTEN and LIMIT.
-- (dynomark.nvim does something similar, but needs an external program, has its
-- own query language and hasn't moved since 2025.)

local X = require("notes.query.expr")
local P = require("notes.query.page")
local index = require("notes.index")

local M = {}

local CLAUSE = { from = true, where = true, sort = true, group = true, flatten = true, limit = true }

local function at_clause(p)
	local token = p:peek()
	return token.kind == "end" or (token.kind == "name" and CLAUSE[token.value:lower()] ~= nil)
end

-- The query text of the expression that was just parsed, for column names.
local function source(p, from)
	return vim.trim(p.src:sub(p.tokens[from].at, p:peek().at - 1))
end

-- FROM ---------------------------------------------------------------------------

local source_or

local function source_unary(p)
	if p:accept("op", "!") or p:accept("op", "-") then
		return { "not", source_unary(p) }
	elseif p:accept("op", "(") then
		local node = source_or(p)
		p:expect("op", ")")
		return node
	end
	local token = p:next()
	if token.kind == "tag" then
		return { "tag", token.value }
	elseif token.kind == "string" then
		return { "folder", token.value }
	elseif token.kind == "link" then
		return { "inlinks", token.value }
	elseif token.kind == "name" and token.value:lower() == "outgoing" then
		p:expect("op", "(")
		local link = p:expect("link")
		p:expect("op", ")")
		return { "outlinks", link.value }
	end
	error("FROM needs a #tag, a \"folder\" or a [[link]], got “" .. tostring(token.value or "end") .. "”", 0)
end

local function source_and(p)
	local node = source_unary(p)
	while p:is("name", "and") or p:is("op", "&&") or p:is("op", "&") do
		p:next()
		node = { "and", node, source_unary(p) }
	end
	return node
end

source_or = function(p)
	local node = source_and(p)
	while p:is("name", "or") or p:is("op", "||") or p:is("op", "|") do
		p:next()
		node = { "or", node, source_and(p) }
	end
	return node
end

local function match_source(node, entry, this)
	local kind = node[1]
	if kind == "not" then
		return not match_source(node[2], entry, this)
	elseif kind == "and" then
		return match_source(node[2], entry, this) and match_source(node[3], entry, this)
	elseif kind == "or" then
		return match_source(node[2], entry, this) or match_source(node[3], entry, this)
	elseif kind == "tag" then
		local want = node[2]:lower()
		for _, tag in ipairs(entry.tags) do
			tag = tag:lower()
			if tag == want or vim.startswith(tag, want .. "/") then
				return true
			end
		end
		return false
	elseif kind == "folder" then
		local want = node[2]:gsub("/$", "")
		return want == "" or entry.folder == want or vim.startswith(entry.folder, want .. "/") or entry.rel == want .. ".md" or entry.rel == want
	end
	local target = (node[2]:match("^(.-)|") or node[2]):gsub("#.*$", "")
	local note = target == "" and this or index.resolve(target, this)
	if not note then
		return false
	end
	local list = kind == "inlinks" and index.outlinks(entry) or index.outlinks(note)
	local wanted = kind == "inlinks" and note.rel or entry.rel
	for _, other in ipairs(list) do
		if other.rel == wanted then
			return true
		end
	end
	return false
end

-- Parsing --------------------------------------------------------------------------

function M.parse(text)
	text = text:gsub("\r", ""):gsub("([^:])//[^\n]*", "%1"):gsub("^//[^\n]*", "")
	local p = X.parser(text)
	local kind = p:next()
	local q = { type = kind.kind == "name" and kind.value:lower() or "", clauses = {}, columns = {} }
	if not ({ list = true, table = true, task = true })[q.type] then
		if q.type == "calendar" then
			error("CALENDAR queries aren't supported; <leader>dc opens the calendar", 0)
		end
		error("a query starts with LIST, TABLE or TASK", 0)
	end
	if p:is("name", "without") then
		p:next()
		if not (p:is("name", "id") and p:next()) then
			error("expected “WITHOUT ID”", 0)
		end
		q.without_id = true
	end
	while not at_clause(p) do
		local from = p.pos
		local column = { expr = p:expr() }
		column.name = source(p, from)
		if p:is("name", "as") then
			p:next()
			local name = p:next()
			column.name = tostring(name.value)
		end
		q.columns[#q.columns + 1] = column
		if not p:accept("op", ",") then
			break
		end
	end
	while p:peek().kind ~= "end" do
		local token = p:next()
		local word = token.kind == "name" and token.value:lower() or ""
		if word == "from" then
			q.from = source_or(p)
		elseif word == "where" then
			table.insert(q.clauses, { "where", p:expr() })
		elseif word == "sort" then
			local keys = {}
			repeat
				local key = { expr = p:expr() }
				local dir = p:peek()
				if dir.kind == "name" and ({ asc = true, ascending = true, desc = true, descending = true })[dir.value:lower()] then
					p:next()
					key.desc = vim.startswith(dir.value:lower(), "desc")
				end
				keys[#keys + 1] = key
			until not p:accept("op", ",")
			table.insert(q.clauses, { "sort", keys })
		elseif word == "group" or word == "flatten" then
			if word == "group" then
				if not (p:is("name", "by") and p:next()) then
					error("expected “GROUP BY”", 0)
				end
			end
			local from = p.pos
			local node = p:expr()
			local name = source(p, from)
			if p:is("name", "as") then
				p:next()
				name = tostring(p:next().value)
			end
			table.insert(q.clauses, { word, node, name })
		elseif word == "limit" then
			local n = p:expect("number")
			table.insert(q.clauses, { "limit", n.value })
		else
			error("unexpected “" .. tostring(token.value) .. "”", 0)
		end
	end
	return q
end

-- Running ---------------------------------------------------------------------------

-- A row is a page or task plus the variables FLATTEN and GROUP BY added.
local function row_get(row, this)
	return function(name)
		local lower = name:lower()
		if row.vars[lower] ~= nil then
			return row.vars[lower]
		elseif lower == "this" then
			return this and P.page(this) or X.NULL
		elseif row.value then
			return row.value.get(name)
		end
		return X.NULL
	end
end

local function context(row, this)
	local entry = row.entry
	return {
		this = this,
		get = row_get(row, this),
		resolve = function(target)
			return index.resolve(target, entry or this)
		end,
	}
end

function M.run(q, this)
	local rows = {}
	for _, entry in ipairs(index.all()) do
		if not q.from or match_source(q.from, entry, this) then
			if q.type == "task" then
				for _, task in ipairs(entry.tasks) do
					rows[#rows + 1] = { entry = entry, task = task, value = P.task(entry, task), vars = {} }
				end
			else
				rows[#rows + 1] = { entry = entry, value = P.page(entry), vars = {} }
			end
		end
	end

	local grouped = false
	for _, clause in ipairs(q.clauses) do
		local kind = clause[1]
		if kind == "where" then
			rows = vim.tbl_filter(function(row)
				return X.truthy(X.eval(clause[2], context(row, this)))
			end, rows)
		elseif kind == "flatten" then
			local out, name = {}, clause[3]:lower()
			for _, row in ipairs(rows) do
				local value = X.eval(clause[2], context(row, this))
				local items = X.kind(value) == "list" and value.items or { value }
				for _, item in ipairs(items) do
					out[#out + 1] = { entry = row.entry, task = row.task, value = row.value, vars = vim.tbl_extend("force", row.vars, { [name] = item }) }
				end
			end
			rows = out
		elseif kind == "sort" then
			for _, row in ipairs(rows) do
				row.keys = {}
				for i, key in ipairs(clause[2]) do
					row.keys[i] = X.eval(key.expr, context(row, this))
				end
			end
			for i, row in ipairs(rows) do
				row.order = i -- table.sort isn't stable
			end
			table.sort(rows, function(a, b)
				for i, key in ipairs(clause[2]) do
					local c = X.compare(a.keys[i], b.keys[i])
					if c ~= 0 then
						if key.desc then
							return c > 0
						end
						return c < 0
					end
				end
				return a.order < b.order
			end)
		elseif kind == "group" then
			grouped = true
			local groups = {}
			for _, row in ipairs(rows) do
				local key = X.eval(clause[2], context(row, this))
				local group
				for _, g in ipairs(groups) do
					if X.equal(g.key, key) then
						group = g
						break
					end
				end
				if not group then
					group = { key = key, rows = {} }
					groups[#groups + 1] = group
				end
				table.insert(group.rows, row)
			end
			table.sort(groups, function(a, b)
				return X.compare(a.key, b.key) < 0
			end)
			rows = {}
			for _, group in ipairs(groups) do
				local members = vim.tbl_map(function(row)
					return { kind = row.task and "task" or "object", task = row.task, entry = row.entry, get = row_get(row, this) }
				end, group.rows)
				rows[#rows + 1] = {
					members = group.rows,
					vars = { key = group.key, [clause[3]:lower()] = group.key, rows = X.list(members) },
				}
			end
		elseif kind == "limit" then
			rows = vim.list_slice(rows, 1, clause[2])
		end
	end

	if q.type == "task" then
		local result = { type = "task", groups = {}, count = 0 }
		local function add(name, list, entry)
			result.groups[#result.groups + 1] = { name = name, entry = entry, tasks = list }
			result.count = result.count + #list
		end
		if grouped then
			for _, row in ipairs(rows) do
				add(X.tostring(row.vars.key), vim.tbl_filter(function(r)
					return r.task ~= nil
				end, row.members))
			end
		else
			local by, order = {}, {}
			for _, row in ipairs(rows) do
				if not by[row.entry] then
					by[row.entry] = {}
					order[#order + 1] = row.entry
				end
				table.insert(by[row.entry], row)
			end
			for _, entry in ipairs(order) do
				add(entry.name, by[entry], entry)
			end
		end
		return result
	end

	local result = { type = q.type, headers = {}, rows = {}, count = #rows }
	if not q.without_id then
		result.headers[1] = { name = grouped and "Group" or "File" }
	end
	for _, column in ipairs(q.columns) do
		table.insert(result.headers, { name = column.name })
	end
	for _, row in ipairs(rows) do
		local cells = {}
		if not q.without_id then
			cells[1] = grouped and row.vars.key or X.link(row.entry.name, nil, row.entry)
		end
		for _, column in ipairs(q.columns) do
			cells[#cells + 1] = X.eval(column.expr, context(row, this))
		end
		result.rows[#result.rows + 1] = { cells = cells, entry = row.entry, members = row.members }
	end
	return result
end

--- Parse and run. Returns a result, or { error = message }.
function M.query(text, this)
	local ok, result = pcall(function()
		return M.run(M.parse(text), this)
	end)
	if ok then
		return result
	end
	return { error = (tostring(result):gsub("^[^:]+%.lua:%d+: ", "")) }
end

--- An inline query: `= this.rating`
function M.inline(text, this)
	local ok, value = pcall(function()
		local row = { entry = this, value = P.page(this), vars = {} }
		return X.eval(X.parse(text), context(row, this))
	end)
	if ok then
		return X.tostring(value)
	end
	return nil, (tostring(value):gsub("^[^:]+%.lua:%d+: ", ""))
end

return M
