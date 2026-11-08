-- Joplin notes in Neovim: search, read, edit and create.
--
-- Talks to the Joplin desktop app's local API (Web Clipper service), so edits
-- sync to Joplin Server like any change made in Joplin. With the app closed,
-- search and reading fall back to Joplin's local database, read-only.
--
--   <leader>oz  search notes (title and body), Enter opens the note
--   <leader>on  new note in the inbox
--   :w          in a note buffer saves it back to Joplin

local M = {}

local joplin_dir = vim.env.HOME .. "/.config/joplin-desktop"

M.config = {
	port = 41184,
	token = nil, -- read from Joplin's settings.json
	database = joplin_dir .. "/database.sqlite",
	inbox = "e29d0819f7d14dbd8fa34fbe22525bc8", -- "00 - Inbox", for new notes
}

local function settings()
	local ok, data = pcall(function()
		return vim.json.decode(table.concat(vim.fn.readfile(joplin_dir .. "/settings.json"), "\n"))
	end)
	return ok and data or {}
end

local function token()
	M.config.token = M.config.token or settings()["api.token"]
	return M.config.token
end

-- API ------------------------------------------------------------------------

local function url(path, query)
	local params = { "token=" .. (token() or "") }
	for k, v in pairs(query or {}) do
		params[#params + 1] = k .. "=" .. vim.uri_encode(tostring(v), "rfc3986")
	end
	return ("http://localhost:%d/%s?%s"):format(M.config.port, path, table.concat(params, "&"))
end

-- Returns the decoded JSON, or nil and an error message.
local function api(method, path, query, body)
	local cmd = { "curl", "-s", "-m", "5", "-X", method, "-w", "\n%{http_code}", url(path, query) }
	if body then
		vim.list_extend(cmd, { "-H", "Content-Type: application/json", "--data-binary", "@-" })
	end
	local res = vim.system(cmd, { text = true, stdin = body and vim.json.encode(body) or nil }):wait()
	if res.code ~= 0 then
		return nil, "Joplin isn't running (no answer on port " .. M.config.port .. ")"
	end
	local text, status = res.stdout:match("^(.*)\n(%d+)$")
	if status ~= "200" then
		return nil, ("Joplin API %s %s: HTTP %s %s"):format(method, path, tostring(status), (text or ""):sub(1, 120))
	end
	local ok, data = pcall(vim.json.decode, text)
	return ok and data or text
end

function M.running()
	local res = vim.system({ "curl", "-s", "-m", "1", ("http://localhost:%d/ping"):format(M.config.port) }, { text = true }):wait()
	return res.code == 0 and res.stdout:find("JoplinClipperServer") ~= nil
end

-- Read-only database fallback -----------------------------------------------

local function sql_string(s)
	return "'" .. s:gsub("'", "''") .. "'"
end

local function db(query)
	local res = vim.system({ "sqlite3", "-readonly", "-json", "file:" .. M.config.database .. "?mode=ro", query }, { text = true }):wait()
	if res.code ~= 0 then
		return nil, "Couldn't read Joplin's database: " .. vim.trim(res.stderr)
	end
	local ok, rows = pcall(vim.json.decode, res.stdout ~= "" and res.stdout or "[]")
	return ok and rows or {}
end

-- "dog walk" -> "dog*" "walk*" : every word, matched as a prefix (FTS4 wants
-- the * inside the quotes)
local function fts_query(text)
	local words = {}
	for word in text:lower():gmatch("[^%s\"']+") do
		words[#words + 1] = '"' .. word .. '*"'
	end
	return table.concat(words, " ")
end

local function db_search(text)
	local where = "n.deleted_time = 0"
	local from = "notes n"
	if text ~= "" then
		from = "notes_fts f join notes n on n.id = f.id"
		where = where .. " and notes_fts match " .. sql_string(fts_query(text))
	end
	return db(("select n.id, n.title, n.parent_id, n.updated_time from %s where %s order by n.updated_time desc limit 100"):format(from, where))
end

-- Notes ----------------------------------------------------------------------

local folders = nil
local function folder_names()
	if folders then
		return folders
	end
	local names, page = {}, 1
	if M.running() then
		repeat
			local res = api("GET", "folders", { fields = "id,title", page = page, limit = 100 })
			for _, f in ipairs(res and res.items or {}) do
				names[f.id] = f.title
			end
			page = page + 1
		until not (res and res.has_more)
	else
		for _, f in ipairs(db("select id, title from folders") or {}) do
			names[f.id] = f.title
		end
	end
	folders = names
	return names
end

-- Notes matching text (title and body), newest first.
function M.search(text)
	if not M.running() then
		return db_search(text)
	end
	local res, err
	if text == "" then
		res, err = api("GET", "notes", { fields = "id,title,parent_id,updated_time", order_by = "updated_time", order_dir = "DESC", limit = 100 })
	else
		-- Joplin's search syntax: a trailing * matches word prefixes while typing.
		res, err = api("GET", "search", { query = text .. "*", type = "note", fields = "id,title,parent_id,updated_time", limit = 100 })
	end
	if not res then
		return nil, err
	end
	return res.items or {}
end

function M.get(id)
	if M.running() then
		return api("GET", "notes/" .. id, { fields = "id,title,body,parent_id,updated_time" })
	end
	local rows, err = db("select id, title, body, parent_id, updated_time from notes where id = " .. sql_string(id))
	return rows and rows[1], err
end

-- Buffers --------------------------------------------------------------------

local function notify(msg, level)
	vim.notify(msg, level or vim.log.levels.INFO, { title = "Joplin" })
end

local function save(buf, force)
	local note = vim.b[buf].joplin
	local body = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
	if not M.running() then
		return notify("Not saved: Joplin isn't running. Start Joplin and :w again.", vim.log.levels.ERROR)
	end

	if note.id then
		-- Refuse to overwrite changes made elsewhere since the note was opened.
		local current = api("GET", "notes/" .. note.id, { fields = "updated_time" })
		if current and current.updated_time ~= note.updated_time and not force then
			return notify("Not saved: the note changed in Joplin since you opened it. :w! overwrites it.", vim.log.levels.WARN)
		end
		local res, err = api("PUT", "notes/" .. note.id, nil, { body = body })
		if not res then
			return notify(err, vim.log.levels.ERROR)
		end
		note.updated_time = res.updated_time
	else
		local res, err = api("POST", "notes", nil, { title = note.title, body = body, parent_id = note.parent_id })
		if not res then
			return notify(err, vim.log.levels.ERROR)
		end
		note.id, note.updated_time = res.id, res.updated_time
		M.tag(note.id, note.tags or {})
		pcall(vim.api.nvim_buf_set_name, buf, ("joplin://%s [%s]"):format(note.title, note.id:sub(1, 8)))
	end
	vim.b[buf].joplin = note
	vim.bo[buf].modified = false
	notify("Saved to Joplin: " .. note.title)
end

-- A markdown buffer for a note; :w saves it through the API.
local function open_buffer(note, lines)
	local buf = vim.api.nvim_create_buf(true, false)
	local name = note.id and ("joplin://%s [%s]"):format(note.title, note.id:sub(1, 8)) or ("joplin://" .. note.title)
	pcall(vim.api.nvim_buf_set_name, buf, name)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].buftype = "acwrite"
	vim.bo[buf].swapfile = false
	vim.bo[buf].filetype = "markdown"
	vim.bo[buf].modified = note.id == nil
	vim.b[buf].joplin = note
	vim.api.nvim_create_autocmd("BufWriteCmd", {
		buffer = buf,
		callback = function(ev)
			save(ev.buf, vim.v.cmdbang == 1)
		end,
	})
	vim.api.nvim_set_current_buf(buf)
	return buf
end

function M.open(id)
	local note, err = M.get(id)
	if not note then
		return notify(err or ("Note not found: " .. id), vim.log.levels.ERROR)
	end
	-- Reuse the buffer if this note is already open.
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		local open = vim.b[buf].joplin
		if open and open.id == id then
			return vim.api.nvim_set_current_buf(buf)
		end
	end
	open_buffer({ id = note.id, title = note.title, parent_id = note.parent_id, updated_time = note.updated_time }, vim.split(note.body or "", "\n"))
	if not M.running() then
		vim.bo.readonly = true
		notify("Joplin isn't running: opened read-only from its database.", vim.log.levels.WARN)
	end
end

-- Picker ---------------------------------------------------------------------

function M.pick()
	local offline = not M.running()
	if offline then
		notify("Joplin isn't running: searching its database read-only.", vim.log.levels.WARN)
	end
	local names = folder_names()
	local bodies = {}
	Snacks.picker.pick({
		title = offline and "Joplin notes (read-only)" or "Joplin notes",
		live = true,
		finder = function(_, ctx)
			local notes, err = M.search(ctx.filter.search or "")
			if not notes then
				notify(err, vim.log.levels.ERROR)
				return {}
			end
			return vim.tbl_map(function(n)
				return { id = n.id, title = n.title, folder = names[n.parent_id] or "", updated = n.updated_time, text = n.title }
			end, notes)
		end,
		format = function(item)
			return {
				{ item.title, "SnacksPickerFile" },
				{ "  " .. item.folder, "Comment" },
			}
		end,
		preview = function(ctx)
			local id = ctx.item.id
			if not bodies[id] then
				local note = M.get(id)
				bodies[id] = note and note.body or ""
			end
			ctx.preview:reset()
			ctx.preview:set_lines(vim.split(bodies[id], "\n"))
			ctx.preview:highlight({ ft = "markdown" })
		end,
		confirm = function(picker, item)
			picker:close()
			if item then
				vim.schedule(function()
					M.open(item.id)
				end)
			end
		end,
	})
end

-- New note -------------------------------------------------------------------

-- Adds tag names to a note, creating tags that don't exist yet.
function M.tag(note_id, tags)
	for _, name in ipairs(tags) do
		local found = api("GET", "search", { query = name, type = "tag", fields = "id,title" })
		local tag = found and found.items and found.items[1]
		if not tag then
			tag = api("POST", "tags", nil, { title = name })
		end
		if tag and tag.id then
			api("POST", "tags/" .. tag.id .. "/notes", nil, { id = note_id })
		end
	end
end

-- Asks for a title, location and tags, then opens a new note. The first :w
-- creates it in the inbox; later writes update it.
function M.new()
	local title = vim.fn.input("Note title: ")
	if title == "" then
		return notify("Title cannot be empty", vim.log.levels.WARN)
	end
	local location = vim.fn.input("Location: ")
	local tags = {}
	for tag in vim.fn.input("Tags (comma separated): "):gmatch("[^,]+") do
		tags[#tags + 1] = vim.trim(tag)
	end
	open_buffer({ title = title, parent_id = M.config.inbox, tags = tags }, {
		"---",
		"title: " .. title,
		"tags: [" .. table.concat(tags, ", ") .. "]",
		"location: " .. location,
		"date: " .. os.date("%Y-%m-%d"),
		"---",
		"",
		"# " .. title,
		"",
		"",
	})
	vim.api.nvim_win_set_cursor(0, { 10, 0 })
	vim.cmd("startinsert")
end

function M.setup(opts)
	M.config = vim.tbl_extend("force", M.config, opts or {})
	vim.keymap.set("n", "<leader>oz", M.pick, { desc = "Search Joplin notes" })
	vim.keymap.set("n", "<leader>on", M.new, { desc = "New Joplin note" })
end

return M
