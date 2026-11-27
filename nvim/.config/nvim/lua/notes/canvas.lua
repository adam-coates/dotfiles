-- Canvases: drawings, mind maps and boards of note cards, made in Excalidraw.
--
-- A canvas is an SVG file with the Excalidraw scene inside it. In a note it is an
-- ordinary image, ![[Ideas.svg]], so it shows inline here (and in Obsidian, the
-- browser preview and exports), and Enter on it opens the editor again.
-- The editor is Excalidraw (MIT) in a browser page that this Neovim serves; it
-- loads Excalidraw from esm.sh, so the first time needs a connection.
--
-- (excalidraw.nvim opens .excalidraw files in Chrome's Excalidraw app and doesn't
-- show them in the note; Obsidian's plugin is Obsidian only.)

local util = require("notes.util")
local vault = require("notes.vault")
local index = require("notes.index")

local M = {}

local MARK = "svg-source:excalidraw"
local pending = {} -- rel -> outline for a new mind map

--- Is this file a canvas (an SVG with an Excalidraw scene in it)?
function M.is_canvas(path)
	if not path or not path:lower():match("%.svg$") then
		return false
	end
	local fd = io.open(path, "r")
	if not fd then
		return false
	end
	local head = fd:read(2048) or ""
	fd:close()
	return head:find(MARK, 1, true) ~= nil
end

-- What snacks.image should draw for a canvas: a copy named after its version, so
-- that a changed canvas is drawn again instead of coming from the image cache.
function M.image_path(path)
	local stat = vim.uv.fs_stat(path)
	if not stat or not M.is_canvas(path) then
		return nil
	end
	local dir = vim.fn.stdpath("cache") .. "/notes-canvas"
	local copy = ("%s/%s-%d%09d.svg"):format(dir, vim.fn.sha256(path):sub(1, 12), stat.mtime.sec, stat.mtime.nsec)
	if not vim.uv.fs_stat(copy) then
		vim.fn.mkdir(dir, "p")
		vim.uv.fs_copyfile(path, copy)
	end
	return copy
end

-- Redraw the images of the notes on screen.
local function redraw_images()
	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
		local buf = vim.api.nvim_win_get_buf(win)
		if vim.bo[buf].filetype == "markdown" then
			pcall(vim.api.nvim_exec_autocmds, "BufWinEnter", { buffer = buf, modeline = false })
		end
	end
end

-- Server -------------------------------------------------------------------------------

local server = require("notes.server")
local started = false

-- A canvas path from the page: relative to the vault, an .svg, inside the vault.
local function target(rel)
	if type(rel) ~= "string" or not rel:match("%.svg$") or rel:find("%.%.") or rel:match("^/") then
		return nil
	end
	local path = vim.fs.normalize(vault.abs(rel))
	return vault.rel(path) == rel and path or nil
end

local function start()
	if not server.start() then
		return false
	end
	if started then
		return true
	end
	started = true
	server.route("/canvas", function()
		return server.page("canvas.html")
	end)
	server.route("/scene", function(req)
		local path = target(req.args.id)
		if not path then
			return "400 Bad Request", "text/plain", "not a canvas"
		end
		local text = util.read(path) or ""
		local out = {
			name = vim.fs.basename(path):gsub("%.svg$", ""),
			svg = text,
			outline = pending[req.args.id],
			dark = vim.o.background == "dark",
			colors = require("config.theme").colors(),
		}
		return "200 OK", "application/json; charset=utf-8", vim.json.encode(out)
	end)
	server.route("/save", function(req)
		local path = target(req.args.id)
		if req.method ~= "POST" or not path then
			return "400 Bad Request", "text/plain", "not a canvas"
		end
		local body = req.body or ""
		if not body:match("^%s*<svg") or not body:find(MARK, 1, true) then
			return "400 Bad Request", "text/plain", "not an Excalidraw SVG"
		end
		util.write(path, body)
		pending[req.args.id] = nil
		index.update(path)
		redraw_images()
		return "200 OK", "text/plain", "saved"
	end)
	server.route("/notes", function()
		local out = {}
		for _, entry in ipairs(index.refresh().all()) do
			local excerpt = ""
			local text = util.read(entry.path) or ""
			for n, line in ipairs(util.lines(text)) do
				if n >= entry.body and line:match("%S") and not line:match("^#") and not line:match("^%s*[`~]") then
					excerpt = util.plain(line:gsub("^%s*[-*+>]%s*", ""):gsub("^%[.%]%s*", ""))
					break
				end
			end
			out[#out + 1] = { id = entry.rel, name = entry.name, folder = entry.folder, excerpt = excerpt, tags = entry.tags, mtime = entry.mtime }
		end
		table.sort(out, function(a, b)
			return a.mtime > b.mtime
		end)
		return "200 OK", "application/json; charset=utf-8", vim.json.encode(out)
	end)
	server.route("/open", function(req)
		local entry = index.get(req.args.id or "") or (req.args.name and index.resolve(req.args.name))
		if entry then
			vault.open(entry.path)
			vim.cmd("redraw")
		end
		return "200 OK", "text/plain", entry and "ok" or "unknown note"
	end)
	return true
end

--- Open a canvas in the editor (creating it on the first save).
function M.open(path, opts)
	opts = opts or {}
	local rel = vault.rel(path)
	if not rel or not start() then
		return util.notify("Couldn't open the canvas", "error")
	end
	if opts.outline then
		pending[rel] = opts.outline
	end
	M.url = server.url("/canvas", { id = rel })
	require("notes.browser").open(M.url)
	return M.url
end

-- Creating --------------------------------------------------------------------------------

local function unique(name)
	local dir = vault.folder("canvas")
	local path, n = dir .. "/" .. util.filename(name) .. ".svg", 2
	while vim.uv.fs_stat(path) do
		path = ("%s/%s %d.svg"):format(dir, util.filename(name), n)
		n = n + 1
	end
	return path
end

-- Put ![[name.svg]] on its own line after `row` (1-based).
local function embed(buf, row, path)
	-- With its folder, so it stays unambiguous.
	vim.api.nvim_buf_set_lines(buf, row, row, false, { "", "![[" .. vault.rel(path) .. "]]", "" })
end

--- A new, empty canvas, embedded below the cursor.
function M.new()
	local buf, row = vim.api.nvim_get_current_buf(), vim.api.nvim_win_get_cursor(0)[1]
	util.input({ prompt = "Canvas name" }, function(name)
		local path = unique(name)
		if vault.is_note(vim.api.nvim_buf_get_name(buf)) then
			embed(buf, row, path)
		end
		M.open(path)
	end)
end

--- The outline under the cursor as a tree: the list the cursor is in (or the
--- selected lines), else the note's headings.
function M.outline(buf, first, last)
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	local entry = index.buffer(buf)
	local title = entry and entry.name or "Mind map"
	local function item(line)
		local indent, text = line:match("^(%s*)[-*+]%s+(.*)$")
		if not indent then
			indent, text = line:match("^(%s*)%d+[.)]%s+(.*)$")
		end
		if not indent then
			return nil
		end
		return #indent:gsub("\t", "    "), util.plain(text:gsub("^%[.%]%s+", ""))
	end
	if not first then
		local row = vim.api.nvim_win_get_cursor(0)[1]
		if item(lines[row] or "") or (lines[row] or ""):match("^%s+%S") then
			first, last = row, row
			while first > 1 and (item(lines[first - 1]) or lines[first - 1]:match("^%s+%S")) do
				first = first - 1
			end
			while last < #lines and (item(lines[last + 1]) or lines[last + 1]:match("^%s+%S")) do
				last = last + 1
			end
		end
	end
	if first then
		-- The heading above names the map.
		for i = first - 1, 1, -1 do
			local heading = lines[i]:match("^#+%s+(.-)%s*$")
			if heading then
				title = util.plain(heading)
				break
			end
		end
		local root = { text = title, children = {} }
		local stack = { { indent = -1, node = root } }
		for i = first, last do
			local indent, text = item(lines[i])
			if indent and text ~= "" then
				while #stack > 1 and stack[#stack].indent >= indent do
					table.remove(stack)
				end
				local node = { text = text, children = {} }
				table.insert(stack[#stack].node.children, node)
				stack[#stack + 1] = { indent = indent, node = node }
			end
		end
		return root, last
	end
	-- Headings
	local root = { text = title, children = {} }
	local stack = { { level = 0, node = root } }
	for _, h in ipairs(entry and entry.headings or {}) do
		if not (h.level == 1 and util.plain(h.text) == title) then
			while #stack > 1 and stack[#stack].level >= h.level do
				table.remove(stack)
			end
			local node = { text = util.plain(h.text), children = {} }
			table.insert(stack[#stack].node.children, node)
			stack[#stack + 1] = { level = h.level, node = node }
		end
	end
	return root, vim.api.nvim_win_get_cursor(0)[1]
end

--- A mind map of the list under the cursor (or the selection, or the headings),
--- embedded after it.
function M.mindmap(first, last)
	local buf = vim.api.nvim_get_current_buf()
	local tree, after = M.outline(buf, first, last)
	if #tree.children == 0 then
		return util.notify("Put the cursor in a list (or give the note some headings)", "warn")
	end
	local path = unique(tree.text)
	if vault.is_note(vim.api.nvim_buf_get_name(buf)) then
		embed(buf, after, path)
	end
	M.open(path, { outline = tree })
end

--- Open the canvas whose embed is under the cursor. Returns false if there is none.
function M.open_at_cursor()
	local link = require("notes.hover").link_at_cursor()
	if not link then
		return false
	end
	local rel = index.resolve_file(link.target, index.buffer())
	local path = rel and vault.abs(rel)
	if path and M.is_canvas(path) then
		M.open(path)
		return true
	end
	return false
end

return M
