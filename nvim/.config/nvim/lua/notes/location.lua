-- Where a note belongs. In a vault with ask_location (settings), a note's
-- `location` property names its folder: new notes ask for it and are made there,
-- moving a note updates it, and notes in the inbox can be filed where it says.

local settings = require("settings")
local util = require("notes.util")
local vault = require("notes.vault")

local M = {}

--- Every folder in the vault (relative paths), the inbox first.
function M.folders()
	local root = vault.root()
	local out = {}
	for name, kind in vim.fs.dir(root, { depth = 8, skip = function(dir)
		return not dir:match("^%.")
	end }) do
		if kind == "directory" and not vim.fs.basename(name):match("^%.") then
			out[#out + 1] = name
		end
	end
	local inbox = settings.folders.inbox
	table.sort(out, function(a, b)
		if (a == inbox) ~= (b == inbox) then
			return a == inbox
		end
		return a:lower() < b:lower()
	end)
	return out
end

--- The folder a `location` value means: the folder with that path, or the one
--- whose path ends with it ("Literature Notes", "claustrum_meetings/2025").
--- Returns the folder, or nil and the candidates when it's ambiguous.
function M.resolve(value, folders)
	if type(value) ~= "string" then
		return nil, {}
	end
	value = vim.trim(value):gsub("^/+", ""):gsub("/+$", "")
	if value == "" then
		return nil, {}
	end
	folders = folders or M.folders()
	local lower = value:lower()
	local hits = {}
	for _, folder in ipairs(folders) do
		local f = folder:lower()
		if f == lower then
			return folder, { folder }
		end
		if f:sub(-#lower - 1) == "/" .. lower then
			hits[#hits + 1] = folder
		end
	end
	if #hits == 1 then
		return hits[1], hits
	end
	return nil, hits
end

--- The folder a note is in, relative to the vault ("" at the top).
function M.folder_of(path)
	local rel = vault.rel(path)
	return rel and (rel:match("^(.*)/[^/]+$") or "") or nil
end

--- Pick a folder; typing a path that doesn't exist makes a new folder.
function M.pick(opts, fn)
	opts = opts or {}
	local items = {}
	for _, folder in ipairs(M.folders()) do
		items[#items + 1] = { text = folder, folder = folder }
	end
	Snacks.picker.pick({
		title = opts.title or "Location",
		items = items,
		layout = { preset = "select" },
		format = function(item)
			return { { "󰉋 ", "Directory" }, { item.folder, item.folder == opts.current and "NotesAccent" or "Normal" } }
		end,
		confirm = function(picker, item)
			local typed = vim.trim(picker.input.filter.pattern or "")
			picker:close()
			local folder = item and item.folder or (typed ~= "" and typed:gsub("^/+", ""):gsub("/+$", "")) or nil
			if folder then
				vim.schedule(function()
					fn(folder)
				end)
			end
		end,
	})
end

local function tags_yaml(text)
	local tags = {}
	for tag in (text or ""):gmatch("[^,]+") do
		tag = vim.trim(tag):gsub("^#", "")
		if tag ~= "" then
			tags[#tags + 1] = tag
		end
	end
	return util.yaml_tags(tags) -- a YAML list, like the rest of the notes
end

--- A new note: title, location, tags. Made in its folder from the note template.
function M.new_note(title)
	local function with_title(name)
		M.pick({ title = "Where does “" .. name .. "” belong? (Enter on nothing typed: " .. settings.folders.inbox .. ")" }, function(folder)
			util.input({ prompt = "Tags (comma separated)" }, function(tags)
				local path = vault.abs(folder) .. "/" .. util.filename(name) .. ".md"
				if vim.uv.fs_stat(path) then
					util.notify("There is already a note called " .. name .. " in " .. folder, "warn")
					return vault.open(path)
				end
				vim.fn.mkdir(vim.fs.dirname(path), "p")
				vault.create(path, { template = "note", vars = { title = name, location = folder, tags = tags_yaml(tags) } })
			end)
		end)
	end
	if title and title ~= "" then
		return with_title(title)
	end
	util.input({ prompt = "New note" }, function(name)
		if name and vim.trim(name) ~= "" then
			with_title(vim.trim(name))
		end
	end)
end

--- A person, in the people folder.
function M.new_person()
	util.input({ prompt = "Name" }, function(name)
		if not name or vim.trim(name) == "" then
			return
		end
		local folder = settings.folders.people
		vault.create(vault.abs(folder) .. "/" .. util.filename(vim.trim(name)) .. ".md", { template = "person", vars = { title = vim.trim(name), location = folder } })
	end)
end

--- Move the note in `buf` (or the file at `path`) to `folder`, and set its
--- location property when the vault uses them or the note has one.
function M.move(folder, buf, path)
	buf = buf or (not path and vim.api.nvim_get_current_buf()) or nil
	local src = path or vim.api.nvim_buf_get_name(buf)
	if not vault.is_note(src) then
		return false, "not a note in the vault"
	end
	local dest = vault.abs(folder) .. "/" .. vim.fs.basename(src)
	if vim.fs.normalize(dest) == vim.fs.normalize(src) then
		return false, "already there"
	end
	if vim.uv.fs_stat(dest) then
		return false, "a note with that name is already in " .. folder
	end
	if not buf then
		local loaded = vim.fn.bufnr(src)
		buf = loaded > 0 and vim.api.nvim_buf_is_loaded(loaded) and loaded or nil
	end
	local entry = require("notes.index").get(src)
	local has_location = entry and entry.fm and entry.fm.location ~= nil
	vim.fn.mkdir(vim.fs.dirname(dest), "p")
	if buf then
		vim.api.nvim_buf_call(buf, function()
			vim.cmd("silent! update")
		end)
	end
	local ok, err = vim.uv.fs_rename(src, dest)
	if not ok then
		return false, err
	end
	pcall(function()
		require("obsidian.cache").notes.rename(src, dest)
	end)
	if buf then
		vim.api.nvim_buf_set_name(buf, dest)
		if settings.ask_location or has_location then
			require("notes.refactor").set_property("location", folder, buf)
		end
		vim.api.nvim_buf_call(buf, function()
			vim.cmd("silent! write!")
		end)
	elseif settings.ask_location or has_location then
		local text = util.read(dest) or ""
		local lines = util.lines(text)
		local scratch = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_lines(scratch, 0, -1, false, lines)
		require("notes.refactor").set_property("location", folder, scratch)
		util.write(dest, table.concat(vim.api.nvim_buf_get_lines(scratch, 0, -1, false), "\n") .. (text:sub(-1) == "\n" and "\n" or ""))
		vim.api.nvim_buf_delete(scratch, { force = true })
	end
	local index = require("notes.index")
	index.update(src)
	index.update(dest)
	vim.api.nvim_exec_autocmds("User", { pattern = "NotesChanged", data = {} })
	return true
end

--- Move this note to a folder you pick.
function M.move_current()
	local src = vim.api.nvim_buf_get_name(0)
	if not vault.is_note(src) then
		return util.notify("Not a note in the vault", "warn")
	end
	M.pick({ title = "Move to", current = M.folder_of(src) }, function(folder)
		local ok, err = M.move(folder)
		util.notify(ok and ("Moved to " .. folder) or ("Not moved: " .. err), ok and "info" or "warn")
	end)
end

--- Move this note to the folder its location names (or ask, when it has none).
function M.file_current()
	local src = vim.api.nvim_buf_get_name(0)
	local entry = require("notes.index").get(src)
	local value = entry and entry.fm and entry.fm.location
	local folder, candidates = M.resolve(value)
	if folder then
		local ok, err = M.move(folder)
		return util.notify(ok and ("Filed in " .. folder) or ("Not moved: " .. err), ok and "info" or "warn")
	end
	if #candidates > 1 then
		util.notify("“" .. value .. "” fits more than one folder; pick one", "warn")
	end
	M.move_current()
end

--- Notes in the inbox whose location names another folder, with where they'd go.
function M.inbox_plan()
	local inbox = settings.folders.inbox
	local folders = M.folders()
	local plan = { move = {}, none = {}, unknown = {} }
	for _, entry in ipairs(require("notes.index").all()) do
		if M.folder_of(entry.path) == inbox then
			local value = entry.fm and entry.fm.location
			local folder = M.resolve(value, folders)
			if type(value) ~= "string" or vim.trim(value) == "" then
				plan.none[#plan.none + 1] = entry
			elseif not folder then
				plan.unknown[#plan.unknown + 1] = { entry = entry, location = value }
			elseif folder ~= inbox then
				plan.move[#plan.move + 1] = { entry = entry, folder = folder }
			end
		end
	end
	table.sort(plan.move, function(a, b)
		return a.entry.name < b.entry.name
	end)
	return plan
end

--- File every inbox note whose location names another folder, after asking.
function M.file_inbox()
	local plan = M.inbox_plan()
	if #plan.move == 0 then
		return util.notify(("Nothing to file: %d inbox notes have no location, %d a location that isn't a folder"):format(#plan.none, #plan.unknown))
	end
	local lines = {}
	for _, m in ipairs(plan.move) do
		lines[#lines + 1] = "  " .. m.entry.name .. "  →  " .. m.folder
	end
	local question = ("File %d inbox notes?\n%s"):format(#plan.move, table.concat(lines, "\n"))
	if vim.fn.confirm(question, "&Yes\n&No", 2) ~= 1 then
		return
	end
	local done, failed = 0, {}
	for _, m in ipairs(plan.move) do
		local ok, err = M.move(m.folder, nil, m.entry.path)
		if ok then
			done = done + 1
		else
			failed[#failed + 1] = m.entry.name .. ": " .. err
		end
	end
	local msg = ("Filed %d notes"):format(done)
	if #plan.unknown > 0 then
		msg = msg .. ("; %d have a location that isn't a folder"):format(#plan.unknown)
	end
	if #failed > 0 then
		msg = msg .. "\n" .. table.concat(failed, "\n")
	end
	util.notify(msg, #failed > 0 and "warn" or "info")
end

return M
