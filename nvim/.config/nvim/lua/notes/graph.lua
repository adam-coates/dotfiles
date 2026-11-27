-- The graph, in the browser and live: it follows the note you are in, updates when
-- notes change, and clicking a node opens that note here.
--
-- The page is served by Neovim itself, on this machine only, behind a random token
-- that changes every session. It can read note names, tags and links, and ask for a
-- note of the index to be opened. Nothing else.

local util = require("notes.util")
local vault = require("notes.vault")
local index = require("notes.index")

local M = {}

local current ---@type string?

-- Data -----------------------------------------------------------------------------

function M.data()
	index.refresh()
	local nodes, links, seen = {}, {}, {}
	local function node(id, name, kind, extra)
		if not seen[id] then
			seen[id] = vim.tbl_extend("force", { id = id, name = name, kind = kind }, extra or {})
			nodes[#nodes + 1] = seen[id]
		end
		return id
	end
	for _, entry in ipairs(index.all()) do
		node(entry.rel, entry.name, "note", { folder = entry.folder, words = entry.words, tags = entry.tags, mtime = entry.mtime })
	end
	for _, entry in ipairs(index.all()) do
		local done = {}
		local function link(target, kind)
			if not done[target] then
				done[target] = true
				links[#links + 1] = { s = entry.rel, t = target, kind = kind }
			end
		end
		for _, l in ipairs(entry.links) do
			if l.target ~= "" then
				local to = index.resolve(l.target, entry)
				if to and to.rel ~= entry.rel and seen[to.rel] then
					link(to.rel, "link")
				elseif not to then
					local file = index.resolve_file(l.target, entry)
					if file then
						link(node("file:" .. file, vim.fs.basename(file), "file"), "file")
					else
						link(node("missing:" .. l.target:lower(), l.target, "missing"), "missing")
					end
				end
			end
		end
		for _, tag in ipairs(entry.tags) do
			link(node("tag:" .. tag:lower(), "#" .. tag, "tag"), "tag")
		end
	end
	return {
		vault = vault.name(),
		nodes = nodes,
		links = links,
		current = current,
		colors = require("config.theme").colors(),
		dark = vim.o.background ~= "light",
	}
end

-- Server ---------------------------------------------------------------------------

local server = require("notes.server")
local started = false

local function start()
	if not server.start() then
		return false
	end
	if started then
		return true
	end
	started = true
	server.route("/", function()
		return server.page("graph.html")
	end)
	server.route("/data", function()
		return "200 OK", "application/json; charset=utf-8", vim.json.encode(M.data())
	end)
	server.route("/open", function(req)
		local entry = index.get(req.args.id or "")
		if entry then
			vault.open(entry.path)
			vim.cmd("redraw")
		end
		return "200 OK", "text/plain", entry and "ok" or "unknown note"
	end)

	local group = vim.api.nvim_create_augroup("notes_graph", { clear = true })
	vim.api.nvim_create_autocmd("BufEnter", {
		group = group,
		pattern = "*.md",
		callback = function(ev)
			local rel = vault.rel(ev.match)
			if rel and rel ~= current then
				current = rel
				server.send("graph", "current", { id = rel })
			end
		end,
	})
	local changed = util.debounce(400, function()
		server.send("graph", "changed", {})
	end)
	vim.api.nvim_create_autocmd("BufWritePost", { group = group, pattern = "*.md", callback = changed })
	vim.api.nvim_create_autocmd("User", { group = group, pattern = "NotesChanged", callback = changed })
	vim.api.nvim_create_autocmd("ColorScheme", { group = group, callback = changed })
	return true
end

--- Open the graph. opts.mode: "local" starts with the current note's neighbourhood.
function M.open(opts)
	opts = opts or {}
	local rel = vault.rel(vim.api.nvim_buf_get_name(0))
	if rel and rel:match("%.md$") then
		current = rel
	end
	if not start() then
		return util.notify("Couldn't start the graph server", "error")
	end
	M.url = server.url("/", opts.mode == "local" and { ["local"] = 1 } or nil)
	require("notes.browser").open(M.url)
	return M.url
end

-- In the terminal ------------------------------------------------------------------

--- The neighbourhood of the current note as a tree: what links here and what it
--- links to, two steps out.
function M.tree()
	local entry = index.buffer()
	if not entry then
		return util.notify("Not in a note", "warn")
	end
	local ns = vim.api.nvim_create_namespace("notes_graph_tree")
	local rows, targets = {}, {}
	local function add(row, target)
		rows[#rows + 1] = row
		targets[#rows] = target
	end
	local function unique(list)
		local out, seen = {}, {}
		for _, e in ipairs(list) do
			if not seen[e.rel] then
				seen[e.rel] = true
				out[#out + 1] = e
			end
		end
		return out
	end
	local function inbound(e)
		return unique(vim.tbl_map(function(hit)
			return hit.entry
		end, index.backlinks(e)))
	end
	local function branch(list, next_list, skip)
		for i, e in ipairs(list) do
			local last = i == #list
			add({ { last and "  └─ " or "  ├─ ", "NotesBorder" }, { e.name, "NotesLink" } }, e)
			local more = vim.tbl_filter(function(x)
				return x.rel ~= skip.rel and x.rel ~= e.rel
			end, next_list(e))
			for j = 1, math.min(#more, 4) do
				add({ { last and "     " or "  │  ", "NotesBorder" }, { j == math.min(#more, 4) and #more <= 4 and "└─ " or "├─ ", "NotesBorder" }, { more[j].name, "NotesMuted" } }, more[j])
			end
			if #more > 4 then
				add({ { last and "     " or "  │  ", "NotesBorder" }, { ("└─ and %d more"):format(#more - 4), "NotesBorder" } })
			end
		end
	end
	local back, out = inbound(entry), index.outlinks(entry)
	add({ { "  󰌹 Links here", "NotesHeader" }, { " " .. #back, "NotesMuted" } })
	branch(back, inbound, entry)
	add({ "" })
	add({ { "  󰎞 " .. entry.name, "NotesTitle" } }, entry)
	add({ "" })
	add({ { "  󰏌 Links to", "NotesHeader" }, { " " .. #out, "NotesMuted" } })
	branch(out, index.outlinks, entry)
	local buf, win = util.float(vim.tbl_map(function()
		return ""
	end, rows), { width = 64, height = math.min(#rows, 30), title = "Neighbourhood", footer = "<CR> open · q close" })
	util.render(buf, ns, rows)
	vim.wo[win].cursorline = true
	vim.keymap.set("n", "<CR>", function()
		local target = targets[vim.api.nvim_win_get_cursor(win)[1]]
		if target then
			vim.api.nvim_win_close(win, true)
			vault.open(target.path)
		end
	end, { buffer = buf })
end

return M
