-- An in-memory index of every note: links, tags, headings, tasks, properties.
--
-- obsidian.nvim has its own cache, but it is internal and leaves out what the
-- panels and queries need (inline fields, task dates, where each link is). Notes
-- are re-read only when their size or modification time changes, so refreshing a
-- vault of a few thousand notes costs one stat per file.

local util = require("notes.util")
local vault = require("notes.vault")

local M = {}

---@class notes.Link
---@field target string note name or path, without anchor
---@field anchor string? heading or ^block
---@field display string?
---@field embed boolean
---@field line integer
---@field col integer 1-based byte column
---@field text string the whole line

---@class notes.Entry
---@field path string absolute
---@field rel string relative to the vault
---@field name string file name without .md
---@field folder string "" for the vault root
---@field mtime integer
---@field ctime integer
---@field size integer
---@field fm table frontmatter
---@field fields table inline key:: value fields
---@field aliases string[]
---@field tags string[]
---@field headings { level: integer, text: string, line: integer }[]
---@field links notes.Link[]
---@field tasks notes.Task[]
---@field blocks table<string, integer>
---@field words integer

M.entries = {} ---@type table<string, notes.Entry> by rel
M.files = {} ---@type table<string, string> other files: lower-case name -> rel
M.version = 0 -- changes whenever anything in the index does

local root ---@type string?
local derived = {} -- things computed from the entries, dropped on change
local scanned = false

local IGNORE = { [".git"] = true, [".obsidian"] = true, [".trash"] = true, ["node_modules"] = true, [".stfolder"] = true, [".sync"] = true }

local function changed()
	M.version = M.version + 1
	derived = {}
end

-- Parsing ----------------------------------------------------------------------

local function yaml(lines)
	local ok, mod = pcall(require, "obsidian.yaml")
	if not ok then
		return {}
	end
	local parsed, data = pcall(mod.loads, table.concat(lines, "\n"))
	return parsed and type(data) == "table" and data or {}
end

local function as_list(value)
	if type(value) == "table" then
		return vim.islist(value) and value or {}
	elseif type(value) == "string" then
		return vim.split(value, "[,%s]+", { trimempty = true })
	elseif value ~= nil and value ~= vim.NIL then
		return { tostring(value) }
	end
	return {}
end

--- Blank out `inline code`, keeping every column where it was.
local function without_code(line)
	if not line:find("`", 1, true) then
		return line
	end
	return (line:gsub("(`+)(.-)%1", function(ticks, body)
		return (" "):rep(#ticks * 2 + #body)
	end))
end

local function decode(target)
	return (target:gsub("%%(%x%x)", function(h)
		return string.char(tonumber(h, 16))
	end))
end

--- Every wiki and markdown link to something in the vault, in one line.
---@return notes.Link[]
function M.parse_links(line, lnum)
	local links = {}
	local clean = without_code(line)
	if clean:find("[[", 1, true) then
		for s, bang, body, e in clean:gmatch("()(!?)%[%[([^%[%]]+)%]%]()") do
			local target, display = body:match("^(.-)\\?|(.*)$")
			target = target or body
			local path, anchor = target:match("^([^#]*)#(.*)$")
			links[#links + 1] = {
				target = vim.trim(path or target),
				anchor = anchor,
				display = display,
				embed = bang == "!",
				line = lnum,
				col = s,
				stop = e - 1,
				text = line,
				kind = "wiki",
			}
		end
	end
	if clean:find("](", 1, true) then
		for s, bang, display, dest, e in clean:gmatch("()(!?)%[([^%[%]]*)%]%(([^()%s]+[^()]*)%)()") do
			dest = dest:gsub("^<(.*)>$", "%1"):gsub('%s+".*"$', "")
			if not dest:match("^%a[%w+.-]*:") and not dest:match("^#") then
				local path, anchor = dest:match("^([^#]*)#(.*)$")
				links[#links + 1] = {
					target = decode(path or dest):gsub("%.md$", ""),
					anchor = anchor and decode(anchor),
					display = display,
					embed = bang == "!",
					line = lnum,
					col = s,
					stop = e - 1,
					text = line,
					kind = "markdown",
				}
			end
		end
	end
	return links
end

--- Tags in one line of text (not frontmatter), without the #.
function M.parse_tags(line)
	local tags = {}
	if not line:find("#", 1, true) then
		return tags
	end
	local clean = without_code(line):gsub("%[%[.-%]%]", " "):gsub("%]%(.-%)", " ")
	for before, tag in (" " .. clean):gmatch("([%s%(,;])#([%w_/%-\128-\255]+)") do
		if before and tag:match("[%a_\128-\255]") then
			tags[#tags + 1] = (tag:gsub("[/%-]+$", ""))
		end
	end
	return tags
end

-- Checkboxes that are tasks. Others ([?], [i], ["], ...) are just fancy bullets.
local STATUSES = { [" "] = true, ["/"] = true, x = true, X = true, ["-"] = true, ["!"] = true, [">"] = true, ["<"] = true }

local TASK = "^(%s*)([-*+])%s+%[(.)%]%s+(.*)$"
local TASK_NUM = "^(%s*)(%d+[.)])%s+%[(.)%]%s+(.*)$"

--- Is the line a task? Returns indent, marker, status, text.
function M.task_parts(line)
	local indent, marker, status, text = line:match(TASK)
	if not indent then
		indent, marker, status, text = line:match(TASK_NUM)
	end
	return indent, marker, status, text
end

---@return notes.Entry
function M.parse(path, lines, stat)
	local rel = vault.rel(path) or path
	local entry = {
		path = path,
		rel = rel,
		name = vim.fs.basename(rel):gsub("%.md$", ""),
		folder = rel:match("^(.*)/[^/]*$") or "",
		mtime = stat and stat.mtime.sec or os.time(),
		ctime = stat and (stat.birthtime and stat.birthtime.sec > 0 and stat.birthtime.sec or stat.ctime.sec) or os.time(),
		size = stat and stat.size or 0,
		nsec = stat and stat.mtime.nsec or 0,
		fm = {},
		fields = {},
		aliases = {},
		tags = {},
		headings = {},
		links = {},
		tasks = {},
		blocks = {},
		words = 0,
		body = 1,
	}
	local seen_tags = {}
	local function add_tag(tag)
		tag = tag:gsub("^#", "")
		if tag ~= "" and not seen_tags[tag:lower()] then
			seen_tags[tag:lower()] = true
			entry.tags[#entry.tags + 1] = tag
		end
	end

	local start = 1
	if lines[1] and lines[1]:match("^%-%-%-%s*$") then
		for i = 2, #lines do
			if lines[i]:match("^%-%-%-%s*$") or lines[i]:match("^%.%.%.%s*$") then
				entry.fm = yaml(vim.list_slice(lines, 2, i - 1))
				for j = 2, i - 1 do
					for _, link in ipairs(M.parse_links(lines[j], j)) do
						link.property = true
						entry.links[#entry.links + 1] = link
					end
				end
				start = i + 1
				break
			end
		end
	end
	entry.body = start
	for _, tag in ipairs(as_list(entry.fm.tags or entry.fm.tag)) do
		add_tag(tostring(tag))
	end
	local aliases = entry.fm.aliases or entry.fm.alias
	if type(aliases) == "string" then
		aliases = { aliases }
	end
	for _, alias in ipairs(type(aliases) == "table" and aliases or {}) do
		entry.aliases[#entry.aliases + 1] = tostring(alias)
	end

	local fence, section, comment = nil, nil, false
	local tasks = package.loaded["notes.tasks"] or require("notes.tasks")
	for i = start, #lines do
		local line = lines[i]
		local ticks = line:match("^%s*>?%s*([`~][`~][`~]+)")
		if fence then
			if ticks and ticks:sub(1, 1) == fence:sub(1, 1) and #ticks >= #fence and line:match("^%s*>?%s*[`~]+%s*$") then
				fence = nil
			end
		elseif ticks then
			fence = ticks
		elseif line:match("^%%%%%s*$") then
			comment = not comment
		elseif not comment and line ~= "" then
			local hashes, text = line:match("^(#+)%s+(.-)%s*#*%s*$")
			if hashes and #hashes <= 6 then
				section = text
				entry.headings[#entry.headings + 1] = { level = #hashes, text = text, line = i }
			end
			for _, link in ipairs(M.parse_links(line, i)) do
				entry.links[#entry.links + 1] = link
			end
			for _, tag in ipairs(M.parse_tags(line)) do
				add_tag(tag)
			end
			local indent, _, status, body = M.task_parts(line)
			if indent and STATUSES[status] then
				local task = tasks.parse(body, status)
				task.line, task.indent, task.section, task.raw = i, #(indent:gsub("\t", "    ")), section, line
				entry.tasks[#entry.tasks + 1] = task
			elseif line:find("::", 1, true) then
				local key, value = without_code(line):match("^%s*[-*+]?%s*%**([%w_ %-/\128-\255]+)%**::%s+(.+)$")
				if key and #key < 40 then
					entry.fields[vim.trim(key)] = vim.trim(value)
				end
			end
			if line:find("::", 1, true) then
				for key, value in without_code(line):gmatch("[%[%(]([%w_ %-]+)::%s*([^%]%)]*)[%]%)]") do
					entry.fields[vim.trim(key)] = vim.trim(value)
				end
			end
			local block = line:match("%s%^([%w%-]+)%s*$") or line:match("^%^([%w%-]+)%s*$")
			if block then
				entry.blocks[block] = i
			end
			local _, words = line:gsub("%S+", "")
			entry.words = entry.words + words
		end
	end
	return entry
end

-- Scanning ------------------------------------------------------------------------

local function walk(dir, rel, out, depth)
	depth = depth or 0
	if rel == require("settings").folders.export .. "/" then
		return
	end
	local handle = depth < 24 and vim.uv.fs_scandir(dir) -- depth: symlink loops
	if not handle then
		return
	end
	while true do
		local name, kind = vim.uv.fs_scandir_next(handle)
		if not name then
			break
		end
		if kind == "directory" or kind == "link" and vim.fn.isdirectory(dir .. "/" .. name) == 1 then
			if not IGNORE[name] and name:sub(1, 1) ~= "." then
				walk(dir .. "/" .. name, rel .. name .. "/", out, depth + 1)
			end
		elseif name:sub(1, 1) ~= "." then
			out[#out + 1] = rel .. name
		end
	end
end

local function check_root()
	local now = vault.root()
	if now ~= root then
		root, M.entries, M.files, scanned = now, {}, {}, false
		changed()
	end
	return root
end

local function load_file(rel)
	local path = root .. "/" .. rel
	local stat = vim.uv.fs_stat(path)
	if not stat or stat.type ~= "file" then
		return nil
	end
	local old = M.entries[rel]
	if old and old.mtime == stat.mtime.sec and old.nsec == stat.mtime.nsec and old.size == stat.size then
		return old, false
	end
	local text = util.read(path)
	if not text then
		return nil
	end
	return M.parse(path, util.lines(text), stat), true
end

--- Bring the index up to date. Cheap when nothing changed.
function M.refresh()
	check_root()
	local list, entries, files, dirty = {}, {}, {}, false
	walk(root, "", list)
	for _, rel in ipairs(list) do
		if rel:match("%.md$") then
			local entry, new = load_file(rel)
			if entry then
				entries[rel] = entry
				dirty = dirty or new
			end
		else
			files[vim.fs.basename(rel):lower()] = rel
		end
	end
	for rel in pairs(M.entries) do
		dirty = dirty or not entries[rel]
	end
	M.entries, M.files = entries, files
	if dirty or not scanned then
		changed()
	end
	scanned = true
	return M
end

--- The index, scanned at least once.
function M.ensure()
	check_root()
	if not scanned then
		M.refresh()
	end
	return M
end

--- Re-read one note (after it was written or deleted).
function M.update(path)
	check_root()
	local rel = vault.rel(path)
	if not rel or not scanned then
		return
	end
	if not rel:match("%.md$") then
		M.files[vim.fs.basename(rel):lower()] = vim.uv.fs_stat(path) and rel or nil
		return
	end
	local entry, new = load_file(rel)
	if entry == nil then
		if M.entries[rel] then
			M.entries[rel] = nil
			changed()
		end
	elseif new then
		M.entries[rel] = entry
		changed()
	end
end

--- The entry for a buffer, parsed from its current (perhaps unsaved) text.
function M.buffer(buf)
	buf = buf == nil and vim.api.nvim_get_current_buf() or buf
	local path = vim.api.nvim_buf_get_name(buf)
	if not vault.is_note(path) then
		return nil
	end
	local entry = M.get(path)
	if entry and not vim.bo[buf].modified then
		return entry
	end
	return M.parse(vim.fs.normalize(path), vim.api.nvim_buf_get_lines(buf, 0, -1, false), vim.uv.fs_stat(path))
end

-- Asking ----------------------------------------------------------------------------

--- Entry by absolute or relative path.
function M.get(path)
	M.ensure()
	return M.entries[path] or M.entries[vault.rel(path) or ""]
end

local function memo(key, fn)
	M.ensure()
	if derived[key] == nil then
		derived[key] = fn()
	end
	return derived[key]
end

--- All entries, sorted by path. Templates are left out unless asked for.
function M.all(opts)
	return memo(opts and opts.templates and "all+" or "all", function()
		local skip = require("settings").folders.templates .. "/"
		local out = {}
		for rel, entry in pairs(M.entries) do
			if (opts and opts.templates) or rel:sub(1, #skip) ~= skip then
				out[#out + 1] = entry
			end
		end
		table.sort(out, function(a, b)
			return a.rel < b.rel
		end)
		return out
	end)
end

local function names()
	return memo("names", function()
		local by_path, by_name, by_alias = {}, {}, {}
		for _, entry in ipairs(M.all({ templates = true })) do
			by_path[entry.rel:gsub("%.md$", ""):lower()] = entry
			local key = entry.name:lower()
			by_name[key] = by_name[key] or {}
			table.insert(by_name[key], entry)
			for _, alias in ipairs(entry.aliases) do
				by_alias[alias:lower()] = by_alias[alias:lower()] or entry
			end
			local id = entry.fm.id
			if type(id) == "string" or type(id) == "number" then
				by_alias[tostring(id):lower()] = by_alias[tostring(id):lower()] or entry
			end
		end
		return { path = by_path, name = by_name, alias = by_alias }
	end)
end

--- The note a link points to: by path, then name (shortest path wins), then id
--- or alias.
---@param from notes.Entry? the note the link is in
function M.resolve(target, from)
	if target == "" then
		return from
	end
	local key = vim.trim(target):gsub("%.md$", ""):gsub("^%./", ""):lower()
	local n = names()
	if from and from.folder ~= "" and key:find("/", 1, true) then
		local near = vim.fs.normalize(from.folder .. "/" .. key):lower()
		if n.path[near] then
			return n.path[near]
		end
	end
	if n.path[key] then
		return n.path[key]
	end
	local hits = n.name[vim.fs.basename(key)]
	if hits then
		local best
		for _, entry in ipairs(hits) do
			local rel = entry.rel:gsub("%.md$", ""):lower()
			if key == vim.fs.basename(key) or rel:sub(-#key - 1) == "/" .. key then
				if from and entry.folder == from.folder then
					return entry
				end
				if not best or #entry.rel < #best.rel then
					best = entry
				end
			end
		end
		if best then
			return best
		end
	end
	return n.alias[key]
end

--- Other file (image, pdf, ...) a link points to, relative to the vault.
function M.resolve_file(target, from)
	M.ensure()
	local path = target:gsub("^%./", "")
	for _, base in ipairs({ from and from.folder or "", "" }) do
		local full = vim.fs.normalize(root .. "/" .. base .. "/" .. path)
		if path ~= "" and vim.uv.fs_stat(full) then
			return vault.rel(full)
		end
	end
	return M.files[vim.fs.basename(path):lower()]
end

--- rel -> list of { entry, link } pointing at it.
local function inlinks()
	return memo("inlinks", function()
		local out = {}
		for _, entry in ipairs(M.all()) do
			for _, link in ipairs(entry.links) do
				local to = M.resolve(link.target, entry)
				if to and to ~= entry then
					out[to.rel] = out[to.rel] or {}
					table.insert(out[to.rel], { entry = entry, link = link })
				end
			end
		end
		return out
	end)
end

function M.backlinks(entry)
	return inlinks()[entry.rel] or {}
end

--- Distinct notes this note links to.
function M.outlinks(entry)
	local out, seen = {}, {}
	for _, link in ipairs(entry.links) do
		local to = M.resolve(link.target, entry)
		if to and to.rel ~= entry.rel and not seen[to.rel] then
			seen[to.rel] = true
			out[#out + 1] = to
		end
	end
	return out
end

--- Links that lead nowhere: { entry, link }.
function M.broken()
	return memo("broken", function()
		local out = {}
		for _, entry in ipairs(M.all()) do
			for _, link in ipairs(entry.links) do
				if link.target ~= "" and not M.resolve(link.target, entry) and not M.resolve_file(link.target, entry) then
					out[#out + 1] = { entry = entry, link = link }
				end
			end
		end
		return out
	end)
end

--- Notes nothing links to and that link to nothing.
function M.orphans()
	return memo("orphans", function()
		return vim.tbl_filter(function(entry)
			return #M.backlinks(entry) == 0 and #M.outlinks(entry) == 0
		end, M.all())
	end)
end

--- tag -> entries. Nested tags count for their parents (#a/b is also #a).
function M.tags()
	return memo("tags", function()
		local out = {}
		for _, entry in ipairs(M.all()) do
			local seen = {}
			for _, tag in ipairs(entry.tags) do
				local path = nil
				for part in tag:gmatch("[^/]+") do
					path = path and (path .. "/" .. part) or part
					if not seen[path:lower()] then
						seen[path:lower()] = true
						out[path] = out[path] or {}
						table.insert(out[path], entry)
					end
				end
			end
		end
		return out
	end)
end

--- Every task in the vault: { entry, task }.
function M.tasks()
	return memo("tasks", function()
		local out = {}
		for _, entry in ipairs(M.all()) do
			for _, task in ipairs(entry.tasks) do
				out[#out + 1] = { entry = entry, task = task }
			end
		end
		return out
	end)
end

--- Plain-text mentions of a note's name or aliases elsewhere that aren't links.
--- Calls back with a list of { entry, line, col, text, word }.
function M.mentions(entry, callback)
	M.ensure()
	local words = {}
	for _, name in ipairs(vim.list_extend({ entry.name }, entry.aliases)) do
		if #name >= 3 and not name:match("^%d+$") then
			words[#words + 1] = name
		end
	end
	if #words == 0 then
		return callback({})
	end
	local cmd = { "rg", "--json", "-i", "-w", "-F", "--glob", "*.md", "--glob", "!" .. require("settings").folders.templates .. "/**" }
	for _, word in ipairs(words) do
		vim.list_extend(cmd, { "-e", word })
	end
	vim.system(vim.list_extend(cmd, { "--", root }), { text = true }, function(res)
		vim.schedule(function()
			local out = {}
			for line in (res.stdout or ""):gmatch("[^\n]+") do
				local ok, item = pcall(vim.json.decode, line)
				if ok and item.type == "match" and item.data.path.text and item.data.lines.text then
					local other = M.get(item.data.path.text)
					if other and other.rel ~= entry.rel and item.data.line_number >= other.body then
						local text = item.data.lines.text:gsub("[\r\n]+$", "")
						local clean = without_code(text)
						local blocked = {}
						for _, pattern in ipairs({ "()!?%[%[.-%]%]()", "()!?%[[^%]]*%]%([^)]*%)()", "()%a+://%S+()", "()#[%w_/%-]+()" }) do
							for s, e in clean:gmatch(pattern) do
								blocked[#blocked + 1] = { s, e - 1 }
							end
						end
						for _, sub in ipairs(item.data.submatches) do
							local s = sub.start + 1
							local free = not clean:match("^%s*[`~][`~][`~]") and clean:sub(s, s + 1):match("%S") ~= nil
							for _, b in ipairs(blocked) do
								free = free and not (s >= b[1] and s <= b[2])
							end
							if free then
								out[#out + 1] = { entry = other, line = item.data.line_number, col = s, text = text, word = text:sub(s, sub["end"]) }
								break
							end
						end
					end
				end
			end
			callback(out)
		end)
	end)
end

return M
