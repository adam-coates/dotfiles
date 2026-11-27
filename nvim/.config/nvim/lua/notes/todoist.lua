-- Todoist, next to the tasks in the notes: in the agenda, in ```todoist blocks,
-- on the start screen, and one key to send a task from a note to Todoist.
--
-- Uses Todoist's API v1 (the Sync API v9 that older plugins use is gone). The
-- token comes from $TODOIST_API_TOKEN, or from a file only you can read, written
-- by :TodoistToken. It never goes on a command line, where other programs could
-- see it.

local settings = require("settings")
local util = require("notes.util")
local D = require("notes.date")

local M = {}

local API = vim.env.TODOIST_API_URL or "https://api.todoist.com/api/v1"
local TOKEN_FILE = vim.fn.stdpath("data") .. "/todoist-token"

M.cache = { tasks = {}, projects = {}, time = 0, error = nil, loading = false }

local function opts()
	return settings.todoist or {}
end

function M.token()
	local env = vim.env.TODOIST_API_TOKEN
	if env and env ~= "" then
		return env
	end
	local text = util.read(TOKEN_FILE)
	return text and vim.trim(text) ~= "" and vim.trim(text) or nil
end

function M.enabled()
	return opts().enabled ~= false and M.token() ~= nil
end

-- Requests -------------------------------------------------------------------------

local function encode(text)
	return (tostring(text):gsub("[^%w%-_%.~]", function(c)
		return ("%%%02X"):format(c:byte())
	end))
end

--- Call the API. `done(result, error)` runs on the main loop.
function M.request(method, path, query, body, done)
	local token = M.token()
	if not token then
		return done(nil, "No Todoist token. :TodoistToken sets one.")
	end
	local url = API .. path
	if query and next(query) then
		local parts = {}
		for key, value in vim.spairs(query) do
			parts[#parts + 1] = key .. "=" .. encode(value)
		end
		url = url .. "?" .. table.concat(parts, "&")
	end
	-- curl reads its options from stdin, so the token isn't in the process list.
	local config = {
		'header = "Authorization: Bearer ' .. token .. '"',
		'url = "' .. url:gsub('"', '\\"') .. '"',
		'request = "' .. method .. '"',
		'write-out = "\\n%{http_code}"',
		"silent",
		"max-time = 20",
	}
	local tmp
	if body then
		tmp = vim.fn.tempname()
		util.write(tmp, vim.json.encode(body))
		vim.uv.fs_chmod(tmp, 384)
		vim.list_extend(config, { 'header = "Content-Type: application/json"', 'data-binary = "@' .. tmp .. '"' })
	end
	vim.system({ "curl", "--config", "-" }, { stdin = table.concat(config, "\n") .. "\n", text = true }, function(res)
		if tmp then
			vim.uv.fs_unlink(tmp)
		end
		vim.schedule(function()
			if res.code ~= 0 then
				return done(nil, "Can't reach Todoist (curl " .. res.code .. ")")
			end
			local text, status = (res.stdout or ""):match("^(.*)\n(%d+)$")
			status = tonumber(status)
			if status == 401 or status == 403 then
				return done(nil, "Todoist refused the token. :TodoistToken sets a new one.")
			elseif not status or status >= 400 then
				return done(nil, ("Todoist answered %s: %s"):format(tostring(status), vim.trim(text or ""):sub(1, 200)))
			end
			if text == "" then
				return done(true)
			end
			local ok, data = pcall(vim.json.decode, text, { luanil = { object = true, array = true } })
			done(ok and data or text, not ok and "Todoist sent something unexpected" or nil)
		end)
	end)
end

-- Every page of a list.
local function all_pages(path, query, done, acc)
	acc = acc or {}
	M.request("GET", path, query, nil, function(data, err)
		if err then
			return done(nil, err)
		end
		vim.list_extend(acc, data.results or {})
		if data.next_cursor and #acc < 2000 then
			return all_pages(path, vim.tbl_extend("force", query or {}, { cursor = data.next_cursor }), done, acc)
		end
		done(acc)
	end)
end

-- Tasks as rows the agenda and the query blocks understand ---------------------------

-- Todoist: 4 is p1 (urgent) ... 1 is normal. Here: 1 highest ... 4 normal.
local PRIORITY = { [4] = 2, [3] = 3, [2] = 5, [1] = 4 }

function M.url(id)
	return "https://app.todoist.com/app/task/" .. id
end

--- A Todoist task as { entry, task, todoist } like a task in a note.
function M.row(item)
	local due = type(item.due) == "table" and item.due or nil
	local date = due and type(due.date) == "string" and due.date:sub(1, 10) or nil
	local project = M.cache.projects[item.project_id] or "Todoist"
	local labels = {}
	for _, label in ipairs(item.labels or {}) do
		labels[#labels + 1] = label
	end
	local text = item.content or ""
	for _, label in ipairs(labels) do
		text = text .. " #" .. label
	end
	return {
		todoist = item,
		entry = { name = "󰄵 " .. project, rel = "todoist:" .. item.id, path = M.url(item.id), folder = "Todoist", tags = labels },
		task = {
			status = item.checked and "x" or " ",
			text = text,
			body = text,
			due = date,
			deadline = type(item.deadline) == "table" and item.deadline.date or nil,
			priority = PRIORITY[item.priority] or 4,
			recur = due and due.is_recurring and (due.string or "repeats") or nil,
			tags = labels,
			line = 0,
			raw = "",
			time = due and type(due.datetime) == "string" and due.datetime:match("T(%d%d:%d%d)") or nil,
		},
	}
end

--- The cached tasks as rows.
function M.rows()
	local out = {}
	for _, item in ipairs(M.cache.tasks) do
		out[#out + 1] = M.row(item)
	end
	return out
end

--- Fetch projects and the tasks of the agenda filter, then tell everyone.
function M.refresh(done)
	if not M.enabled() then
		return done and done(false)
	end
	if M.cache.loading then
		return
	end
	M.cache.loading = true
	all_pages("/projects", {}, function(projects, err)
		if projects then
			for _, p in ipairs(projects) do
				M.cache.projects[p.id] = p.name
			end
		end
		all_pages("/tasks/filter", { query = opts().filter or "overdue | next 7 days" }, function(tasks, err2)
			M.cache.loading = false
			M.cache.error = err or err2
			if tasks then
				M.cache.tasks, M.cache.time = tasks, os.time()
			end
			vim.api.nvim_exec_autocmds("User", { pattern = "TodoistChanged", data = {} })
			if done then
				done(tasks ~= nil, M.cache.error)
			end
		end)
	end)
end

--- Refresh when the cache is older than settings.todoist.refresh_minutes.
function M.ensure()
	if M.enabled() and os.time() - M.cache.time > (opts().refresh_minutes or 5) * 60 then
		M.refresh()
	end
end

local function changed(err, message)
	if err then
		return util.notify(err, "error")
	end
	if message then
		util.notify(message)
	end
	M.refresh()
end

-- Changing tasks -----------------------------------------------------------------------

local function drop(id)
	for i, item in ipairs(M.cache.tasks) do
		if item.id == id then
			table.remove(M.cache.tasks, i)
			break
		end
	end
	vim.api.nvim_exec_autocmds("User", { pattern = "TodoistChanged", data = {} })
end

--- Tick off. A recurring task moves on to its next date in Todoist.
function M.close(item)
	if not item.due or not item.due.is_recurring then
		drop(item.id) -- right away; the refresh confirms it
	end
	M.request("POST", "/tasks/" .. item.id .. "/close", nil, nil, function(_, err)
		changed(err)
	end)
end

function M.reopen(item)
	M.request("POST", "/tasks/" .. item.id .. "/reopen", nil, nil, function(_, err)
		changed(err)
	end)
end

--- Change fields: { due_string = "next fri 3pm" } (Todoist reads it), { due_date = "2026-12-01" },
--- { priority = 4 }, { content = "..." }.
function M.update(item, fields, message)
	M.request("POST", "/tasks/" .. item.id, nil, fields, function(_, err)
		changed(err, message)
	end)
end

--- Move a task by `days`. A recurring task keeps its rule.
function M.shift(item, days)
	local due = item.due
	local from = due and due.date and due.date:sub(1, 10) or D.today()
	local target = D.add(from, days, "day")
	if due and due.is_recurring and due.string then
		return M.update(item, { due_string = due.string .. " starting " .. target })
	end
	M.update(item, { due_date = target })
end

--- Add a task with Todoist's Quick Add: "Call Anna tomorrow 3pm p1 #Thesis @phone".
--- `note` (the note it came from) goes into the description.
function M.add(text, note, done)
	M.request("POST", "/tasks/quick", nil, { text = text }, function(item, err)
		if err or type(item) ~= "table" then
			if done then
				done(nil, err)
			end
			return changed(err or "Todoist didn't create the task")
		end
		local function finish()
			if done then
				done(item)
			end
			changed(nil, "Added to Todoist: " .. (item.content or text))
		end
		if note then
			M.request("POST", "/tasks/" .. item.id, nil, { description = "From the note [[" .. note .. "]]" }, function()
				finish()
			end)
		else
			finish()
		end
	end)
end

--- Ask for a task and add it to Todoist, linked to the current note.
function M.capture()
	if not M.token() then
		return M.set_token()
	end
	local entry = require("notes.index").buffer()
	util.input({ prompt = "Todoist (Quick Add: “Call Anna tomorrow 3pm p1 #Project @label”)" }, function(text)
		M.add(text, entry and entry.name)
	end)
end

-- Tasks in notes ----------------------------------------------------------------------------

local LINK = "%(https://app%.todoist%.com/app/task/([%w_-]+)%)"

--- Quick Add text for a task line from a note: its dates and priority in Todoist's words.
function M.quick_text(line)
	local _, _, status, body = require("notes.index").task_parts(line)
	local task = require("notes.tasks").parse(body or line, status or " ")
	local text = util.plain(task.text):gsub("%s*#([%w_/%-]+)", " @%1"):gsub("^%s+", "")
	if task.due or task.scheduled then
		text = text .. " {" .. (task.due or task.scheduled) .. "}"
		if task.scheduled and task.due then
			text = vim.trim(text:gsub(" {[^}]*}$", "")) .. " " .. task.scheduled .. " {" .. task.due .. "}"
		end
	end
	if task.recur then
		text = text .. " " .. task.recur
	end
	local p = ({ [1] = "p1", [2] = "p1", [3] = "p2", [5] = "p3", [6] = "p3" })[task.priority]
	return (p and (text .. " " .. p) or text), task
end

--- Send the task under the cursor to Todoist. The line stays, as a link to it.
function M.send_current()
	if not M.token() then
		return M.set_token()
	end
	local buf, row = vim.api.nvim_get_current_buf(), vim.api.nvim_win_get_cursor(0)[1]
	local line = vim.api.nvim_get_current_line()
	if line:match(LINK) then
		return util.notify("This is in Todoist already")
	end
	local text, task = M.quick_text(line)
	if vim.trim(text) == "" then
		return util.notify("Nothing to send", "warn")
	end
	local entry = require("notes.index").buffer(buf)
	M.add(text, entry and entry.name, function(item)
		if not item or not vim.api.nvim_buf_is_valid(buf) then
			return
		end
		local indent = line:match("^(%s*)") or ""
		local title = util.plain(task.text):gsub("%s*#[%w_/%-]+", "")
		local current = vim.api.nvim_buf_get_lines(buf, row - 1, row, false)[1]
		if current == line then
			vim.api.nvim_buf_set_lines(buf, row - 1, row, false, { ("%s- [%s](%s)"):format(indent, vim.trim(title), M.url(item.id)) })
		end
		table.insert(M.cache.tasks, item)
		M.decorate(buf)
	end)
end

local ns = vim.api.nvim_create_namespace("notes_todoist")
local known = {} -- id -> task, for links in notes, including done ones

--- Show the state of linked Todoist tasks at the end of their line.
function M.decorate(buf)
	buf = buf or vim.api.nvim_get_current_buf()
	if not vim.api.nvim_buf_is_valid(buf) or not M.token() then
		return
	end
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	local wanted = {}
	for _, item in ipairs(M.cache.tasks) do
		known[item.id] = item
	end
	local function draw()
		vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
		for i, line in ipairs(lines) do
			local id = line:match(LINK)
			local item = id and known[id]
			if item then
				local row = M.row(item)
				local chunks = {}
				if item.checked then
					chunks[#chunks + 1] = { " ✓ done", "NotesGreen" }
				elseif row.task.due then
					chunks[#chunks + 1] = { " 󰃭 " .. D.human(row.task.due), require("notes.tasks").date_hl(row.task.due) }
				end
				if row.task.recur and not item.checked then
					chunks[#chunks + 1] = { " 󰑖", "NotesMuted" }
				end
				chunks[#chunks + 1] = { " " .. (M.cache.projects[item.project_id] or ""), "NotesBorder" }
				pcall(vim.api.nvim_buf_set_extmark, buf, ns, i - 1, 0, { virt_text = chunks, virt_text_pos = "eol" })
			end
		end
	end
	for _, line in ipairs(lines) do
		local id = line:match(LINK)
		if id and not known[id] then
			wanted[#wanted + 1] = id
		end
	end
	draw()
	for _, id in ipairs(vim.list_slice(wanted, 1, 20)) do
		M.request("GET", "/tasks/" .. id, nil, nil, function(item)
			if type(item) == "table" and item.id then
				known[item.id] = item
				if vim.api.nvim_buf_is_valid(buf) then
					draw()
				end
			end
		end)
	end
end

--- The Todoist task linked on the cursor line.
function M.at_cursor()
	local id = vim.api.nvim_get_current_line():match(LINK)
	return id and (known[id] or { id = id })
end

-- ```todoist blocks ---------------------------------------------------------------------

local blocks = {} -- filter -> { time, rows, error, loading }

--- A block's text: a bare filter, or the YAML of Obsidian's Todoist plugin
--- (filter, name, sorting), so the same block works in both.
function M.parse_block(text, note)
	local spec = { sorting = {} }
	if not text:match("^%s*filter%s*:") and not text:match("\n%s*filter%s*:") then
		spec.filter = vim.trim((text:gsub("\n", " ")))
	else
		local in_sorting = false
		for line in (text .. "\n"):gmatch("([^\n]*)\n") do
			local key, value = line:match("^%s*([%w_]+)%s*:%s*(.-)%s*$")
			if key then
				in_sorting = key == "sorting" and value == ""
				value = value:gsub('^"(.*)"$', "%1"):gsub("^'(.*)'$", "%1")
				if key == "filter" or key == "name" then
					spec[key] = value
				elseif key == "sorting" and value ~= "" then
					for item in value:gmatch("[%w]+") do
						spec.sorting[#spec.sorting + 1] = item
					end
				end
			elseif in_sorting then
				local item = line:match("^%s*%-%s*[\"']?([%w]+)")
				if item then
					spec.sorting[#spec.sorting + 1] = item
				end
			end
		end
	end
	spec.filter = (spec.filter or ""):gsub("{{filename}}", note and note.name or "")
	return spec
end

local SORT = {
	date = function(r)
		return r.task.due or "9999"
	end,
	priority = function(r)
		return r.task.priority
	end,
	alphabetical = function(r)
		return r.task.text:lower()
	end,
	order = function(r)
		return r.todoist.child_order or 0
	end,
	dateAdded = function(r)
		return r.todoist.added_at or ""
	end,
	deadline = function(r)
		return r.task.deadline or "9999"
	end,
}

--- Rows for a block, from the cache (fetching in the background when stale).
function M.query(text, note)
	local spec = M.parse_block(text, note)
	local filter = spec.filter
	if not M.token() then
		return { error = "No Todoist token. :TodoistToken sets one." }
	end
	local cached = blocks[filter]
	if not cached or (os.time() - cached.time > 60 and not cached.loading) then
		blocks[filter] = cached or { time = 0, rows = {}, loading = true }
		blocks[filter].loading = true
		all_pages("/tasks/filter", { query = filter }, function(tasks, err)
			local rows = {}
			for _, item in ipairs(tasks or {}) do
				rows[#rows + 1] = M.row(item)
			end
			blocks[filter] = { time = os.time(), rows = rows, error = err, loaded = true }
			vim.api.nvim_exec_autocmds("User", { pattern = "TodoistChanged", data = {} })
		end)
	end
	local state = blocks[filter]
	if state.error then
		return { error = state.error }
	end
	if not state.loaded then
		return { type = "task", groups = { { tasks = {} } }, count = 0, loading = true }
	end
	local rows = vim.list_extend({}, state.rows)
	local keys = {}
	for _, name in ipairs(#spec.sorting > 0 and spec.sorting or { "date", "priority" }) do
		local base, dir = name:match("^(%l+%u?%l*)(%u%l+)$")
		base = base and SORT[base] and base or name:gsub("Ascending$", "")
		if SORT[base] then
			keys[#keys + 1] = { fn = SORT[base], desc = name:match("Descending$") ~= nil and dir ~= nil }
		end
	end
	for i, row in ipairs(rows) do
		row.order = i
	end
	table.sort(rows, function(a, b)
		for _, key in ipairs(keys) do
			local x, y = key.fn(a), key.fn(b)
			if x ~= y then
				if key.desc then
					return x > y
				end
				return x < y
			end
		end
		return a.order < b.order
	end)
	return { type = "task", groups = { { name = spec.name, tasks = rows } }, count = #rows, flat = true }
end

function M.forget_queries()
	for _, state in pairs(blocks) do
		state.time = 0
	end
end

-- Setting up -------------------------------------------------------------------------------

function M.set_token()
	vim.ui.input({ prompt = "Todoist API token (Settings › Integrations › Developer)" }, function(token)
		token = token and vim.trim(token) or ""
		if token == "" then
			return
		end
		util.write(TOKEN_FILE, token .. "\n")
		vim.uv.fs_chmod(TOKEN_FILE, 384) -- 0600
		M.request("GET", "/projects", { limit = 1 }, nil, function(_, err)
			if err then
				return util.notify(err, "error")
			end
			util.notify("Todoist is connected")
			M.refresh()
		end)
	end)
end

function M.setup()
	local group = vim.api.nvim_create_augroup("notes_todoist", { clear = true })
	vim.api.nvim_create_autocmd({ "BufWinEnter", "BufWritePost" }, {
		group = group,
		pattern = "*.md",
		callback = function(ev)
			if M.enabled() then
				local text = table.concat(vim.api.nvim_buf_get_lines(ev.buf, 0, -1, false), "\n")
				if text:find("app.todoist.com/app/task/", 1, true) then
					M.decorate(ev.buf)
				end
			end
		end,
	})
	vim.api.nvim_create_autocmd("User", {
		group = group,
		pattern = "TodoistChanged",
		callback = function()
			for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
				local buf = vim.api.nvim_win_get_buf(win)
				if vim.bo[buf].filetype == "markdown" then
					M.decorate(buf)
					require("notes.blocks").refresh(buf)
				end
			end
			vim.cmd.redrawstatus()
		end,
	})
	vim.api.nvim_create_autocmd("FocusGained", { group = group, callback = M.ensure })
	vim.api.nvim_create_user_command("TodoistToken", M.set_token, { desc = "Connect Todoist" })
	vim.api.nvim_create_user_command("Todoist", function(args)
		if args.args ~= "" then
			M.add(args.args, (require("notes.index").buffer() or {}).name)
		else
			M.capture()
		end
	end, { nargs = "*", desc = "Add a task to Todoist (Quick Add syntax)" })
	if M.enabled() then
		vim.defer_fn(M.refresh, 1500)
	end
	local minutes = opts().refresh_minutes or 5
	local timer = assert(vim.uv.new_timer())
	timer:start(minutes * 60000, minutes * 60000, vim.schedule_wrap(M.ensure))
end

return M
