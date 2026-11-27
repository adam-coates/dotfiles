-- Notes and tasks as objects that queries can read: file.name, file.tags, any
-- frontmatter property, any inline field.

local X = require("notes.query.expr")
local index = require("notes.index")

local M = {}

local function normal(key)
	return (key:lower():gsub("[%s_]+", "-"))
end

local function link_to(entry)
	return X.link(entry.name, nil, entry)
end

--- A task as a query value.
function M.task(entry, task)
	local T = require("notes.tasks")
	return {
		kind = "task",
		task = task,
		entry = entry,
		get = function(key)
			key = key:lower()
			if key == "completed" or key == "fullycompleted" then
				return T.is_done(task.status)
			elseif key == "checked" then
				return task.status ~= " "
			elseif key == "status" or key == "line" then
				return task[key]
			elseif key == "text" then
				return task.body
			elseif key == "description" then
				return task.text
			elseif key == "due" or key == "scheduled" or key == "start" or key == "created" or key == "done" or key == "completion" then
				local date = task[key == "completion" and "done" or key]
				return date and X.date(date) or X.NULL
			elseif key == "priority" then
				return task.priority
			elseif key == "recurrence" or key == "repeat" then
				return task.recur or X.NULL
			elseif key == "tags" then
				return X.list(vim.tbl_map(function(tag)
					return "#" .. tag
				end, task.tags))
			elseif key == "section" or key == "header" then
				return task.section or X.NULL
			elseif key == "path" then
				return entry.rel
			elseif key == "link" then
				return X.link(entry.name, task.section, entry)
			end
			local value = M.page(entry).get(key)
			return value
		end,
	}
end

local FILE = {
	name = function(e)
		return e.name
	end,
	path = function(e)
		return e.rel
	end,
	folder = function(e)
		return e.folder
	end,
	ext = function()
		return "md"
	end,
	link = link_to,
	size = function(e)
		return e.size
	end,
	ctime = function(e)
		return X.date(e.ctime)
	end,
	cday = function(e)
		return X.date(e.ctime)
	end,
	mtime = function(e)
		local date = X.date(e.mtime)
		date.clock = os.date("%H:%M", e.mtime)
		return date
	end,
	mday = function(e)
		return X.date(e.mtime)
	end,
	words = function(e)
		return e.words
	end,
	tags = function(e)
		local out, seen = {}, {}
		for _, tag in ipairs(e.tags) do
			local path
			for part in tag:gmatch("[^/]+") do
				path = path and (path .. "/" .. part) or part
				if not seen[path] then
					seen[path] = true
					out[#out + 1] = "#" .. path
				end
			end
		end
		return X.list(out)
	end,
	etags = function(e)
		return X.list(vim.tbl_map(function(tag)
			return "#" .. tag
		end, e.tags))
	end,
	aliases = function(e)
		return X.list(e.aliases)
	end,
	inlinks = function(e)
		local out, seen = {}, {}
		for _, hit in ipairs(index.backlinks(e)) do
			if not seen[hit.entry.rel] then
				seen[hit.entry.rel] = true
				out[#out + 1] = link_to(hit.entry)
			end
		end
		return X.list(out)
	end,
	outlinks = function(e)
		return X.list(vim.tbl_map(link_to, index.outlinks(e)))
	end,
	tasks = function(e)
		return X.list(vim.tbl_map(function(task)
			return M.task(e, task)
		end, e.tasks))
	end,
	headings = function(e)
		return X.list(vim.tbl_map(function(h)
			return h.text
		end, e.headings))
	end,
	day = function(e)
		local iso = e.name:match("%d%d%d%d%-%d%d%-%d%d")
		return iso and X.date(iso) or (type(e.fm.date) == "string" and X.date(e.fm.date)) or X.NULL
	end,
	frontmatter = function(e)
		return X.from(e.fm)
	end,
	starred = function()
		return false
	end,
}
FILE.lists = FILE.tasks

local function file(entry)
	return {
		kind = "object",
		entry = entry,
		get = function(key)
			local fn = FILE[key:lower()]
			return fn and fn(entry) or X.NULL
		end,
	}
end

local cache, cache_version = {}, -1

--- A note as a query value.
function M.page(entry)
	if cache_version ~= index.version then
		cache, cache_version = {}, index.version
	end
	local page = cache[entry]
	if page then
		return page
	end
	local function resolve(target)
		return index.resolve((target:gsub("#.*$", "")), entry)
	end
	local props
	page = {
		kind = "object",
		entry = entry,
		get = function(key)
			local lower = key:lower()
			if lower == "file" then
				return file(entry)
			end
			if not props then
				props = {}
				for k, v in pairs(entry.fields) do
					props[normal(k)] = X.from_field(v, resolve)
				end
				for k, v in pairs(entry.fm) do
					props[normal(tostring(k))] = X.from(v, resolve)
				end
			end
			local value = props[normal(key)]
			return value == nil and X.NULL or value
		end,
	}
	cache[entry] = page
	return page
end

return M
