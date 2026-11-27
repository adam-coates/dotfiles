-- Pickers over the index, for what obsidian.nvim's own pickers don't cover.

local util = require("notes.util")
local vault = require("notes.vault")
local index = require("notes.index")
local D = require("notes.date")
local T = require("notes.tasks")

local M = {}

local function open(picker, item, cmd)
	picker:close()
	if item then
		vim.schedule(function()
			vault.open(item.file, { line = item.pos and item.pos[1], cmd = cmd })
		end)
	end
end

local ACTIONS = {
	open_split = function(picker, item)
		open(picker, item, "split")
	end,
	open_vsplit = function(picker, item)
		open(picker, item, "vsplit")
	end,
	insert_link = function(picker, item)
		picker:close()
		if item then
			vim.schedule(function()
				vim.api.nvim_put({ "[[" .. item.name .. "]]" }, "c", true, true)
			end)
		end
	end,
}
local KEYS = {
	["<C-x>"] = { "open_split", mode = { "i", "n" } },
	["<C-v>"] = { "open_vsplit", mode = { "i", "n" } },
	["<C-l>"] = { "insert_link", mode = { "i", "n" } },
}

local function ago(time)
	return D.human(D.iso(time))
end

local function note_items(entries)
	return vim.tbl_map(function(entry)
		return {
			text = entry.name .. " " .. table.concat(entry.aliases, " ") .. " " .. entry.folder,
			file = entry.path,
			name = entry.name,
			entry = entry,
		}
	end, entries)
end

local function note_format(item)
	local e = item.entry
	local out = { { e.name, "NotesLink" } }
	if e.folder ~= "" then
		out[#out + 1] = { "  " .. e.folder, "NotesMuted" }
	end
	out[#out + 1] = { "  " .. ago(e.mtime), "NotesBorder" }
	return out
end

--- Pick from a list of notes.
function M.notes(entries, title)
	if #entries == 0 then
		return util.notify("No notes: " .. title)
	end
	Snacks.picker.pick({
		title = title,
		items = note_items(entries),
		format = note_format,
		preview = "file",
		actions = ACTIONS,
		win = { input = { keys = KEYS } },
		confirm = open,
	})
end

local function by_time(entries)
	local out = vim.list_extend({}, entries)
	table.sort(out, function(a, b)
		return a.mtime > b.mtime
	end)
	return out
end

--- The quick switcher: notes by name or alias, most recent first. <CR> on a name
--- that doesn't exist creates it, <S-CR> (or <C-n>) always creates.
function M.switch(opts)
	opts = opts or {}
	local here = vim.fs.normalize(vim.api.nvim_buf_get_name(0))
	local used = {}
	for i, path in ipairs(vim.v.oldfiles) do
		used[path] = used[path] or (1e9 - i)
	end
	local items = {}
	for _, entry in ipairs(index.refresh().all()) do
		local rank = entry.mtime
		local info = vim.fn.getbufinfo(entry.path)[1]
		if info then
			rank = math.max(rank, info.lastused)
		end
		local function add(name, alias)
			items[#items + 1] = { text = name .. " " .. entry.folder, file = entry.path, name = entry.name, entry = entry, label = name, alias = alias, rank = entry.path == here and 0 or rank }
		end
		add(entry.name)
		for _, alias in ipairs(entry.aliases) do
			add(alias, true)
		end
	end
	table.sort(items, function(a, b)
		if a.rank ~= b.rank then
			return a.rank > b.rank
		end
		return a.label < b.label
	end)
	local function create(picker)
		local name = vim.trim(picker.input.filter.pattern or "")
		picker:close()
		if name ~= "" then
			vim.schedule(function()
				local folder, title = name:match("^(.*)/([^/]+)$")
				local dir = folder and vault.abs(folder) or vault.folder("inbox")
				vault.create(dir .. "/" .. util.filename(title or name) .. ".md", { template = "note" })
			end)
		end
	end
	Snacks.picker.pick({
		title = opts.title or "Notes  (<S-CR> creates)",
		items = items,
		format = function(item)
			local out = { { item.label, "NotesLink" } }
			if item.alias then
				out[#out + 1] = { " → " .. item.entry.name, "NotesMuted" }
			end
			if item.entry.folder ~= "" then
				out[#out + 1] = { "  " .. item.entry.folder, "NotesBorder" }
			end
			return out
		end,
		matcher = { frecency = true, sort_empty = false },
		preview = "file",
		actions = vim.tbl_extend("force", ACTIONS, { create = create }),
		win = {
			input = {
				keys = vim.tbl_extend("force", KEYS, {
					["<S-CR>"] = { "create", mode = { "i", "n" } },
					["<C-n>"] = { "create", mode = { "i", "n" } },
				}),
			},
		},
		confirm = function(picker, item)
			if not item then
				return create(picker)
			end
			open(picker, item)
		end,
	})
end

--- Search the text of all notes.
function M.grep(opts)
	Snacks.picker.grep(vim.tbl_extend("force", {
		title = "Search notes",
		cwd = vault.root(),
		glob = "*.md",
		actions = ACTIONS,
		win = { input = { keys = { ["<C-x>"] = KEYS["<C-x>"], ["<C-v>"] = KEYS["<C-v>"] } } },
	}, opts or {}))
end

--- Pick a note and put a link to it at the cursor. With `embed`, an embed.
function M.insert_link(embed)
	local items = {}
	for _, entry in ipairs(index.refresh().all()) do
		items[#items + 1] = { text = entry.name .. " " .. table.concat(entry.aliases, " "), file = entry.path, name = entry.name, entry = entry }
		for _, h in ipairs(embed and entry.headings or {}) do
			items[#items + 1] = { text = entry.name .. " " .. h.text, file = entry.path, pos = { h.line, 0 }, name = entry.name .. "#" .. h.text, entry = entry, heading = h.text }
		end
	end
	local win, pos = vim.api.nvim_get_current_win(), vim.api.nvim_win_get_cursor(0)
	Snacks.picker.pick({
		title = embed and "Embed" or "Insert link",
		items = items,
		format = function(item)
			return { { item.entry.name, "NotesLink" }, { item.heading and (" › " .. item.heading) or "", "NotesText" }, { "  " .. item.entry.folder, "NotesBorder" } }
		end,
		preview = "file",
		confirm = function(picker, item)
			picker:close()
			if item then
				vim.schedule(function()
					vim.api.nvim_set_current_win(win)
					vim.api.nvim_win_set_cursor(win, pos)
					local text = (embed and "!" or "") .. "[[" .. item.name .. "]]"
					vim.api.nvim_put({ text }, "c", vim.fn.col("$") > 1 and pos[2] >= vim.fn.col("$") - 2, true)
				end)
			end
		end,
	})
end

--- Notes by last change.
function M.recent()
	M.notes(by_time(index.refresh().all()), "Recently edited")
end

function M.orphans()
	M.notes(by_time(index.refresh().orphans()), "Orphans (no links in or out)")
end

function M.random()
	local all = index.all()
	if #all > 0 then
		vault.open(all[math.random(#all)].path)
	end
end

function M.untagged()
	M.notes(
		by_time(vim.tbl_filter(function(entry)
			return #entry.tags == 0
		end, index.refresh().all())),
		"Notes without tags"
	)
end

--- Notes edited on this day in earlier weeks, months and years (by daily note and
--- creation date).
function M.on_this_day()
	local today = D.today()
	local entries = vim.tbl_filter(function(entry)
		local iso = entry.name:match("%d%d%d%d%-%d%d%-%d%d") or (type(entry.fm.created) == "string" and entry.fm.created:match("%d%d%d%d%-%d%d%-%d%d")) or nil
		return iso ~= nil and iso < today and (iso:sub(6) == today:sub(6) or (iso:sub(9) == today:sub(9)))
	end, index.refresh().all())
	M.notes(entries, "On this day")
end

--- Every heading in the vault.
function M.headings()
	local items = {}
	for _, entry in ipairs(by_time(index.refresh().all())) do
		for _, h in ipairs(entry.headings) do
			items[#items + 1] = { text = h.text .. " " .. entry.name, file = entry.path, pos = { h.line, 0 }, heading = h, name = entry.name .. "#" .. h.text }
		end
	end
	Snacks.picker.pick({
		title = "Headings",
		items = items,
		format = function(item)
			return {
				{ ("#"):rep(item.heading.level) .. " ", "NotesMuted" },
				{ util.plain(item.heading.text), "RenderMarkdownH" .. item.heading.level },
				{ "  " .. item.name:match("^(.-)#"), "NotesBorder" },
			}
		end,
		preview = "file",
		actions = ACTIONS,
		win = { input = { keys = KEYS } },
		confirm = open,
	})
end

--- Links to notes that don't exist. <CR> goes to the link, <C-n> creates the note.
function M.broken()
	local items = {}
	for _, hit in ipairs(index.refresh().broken()) do
		items[#items + 1] = {
			text = hit.link.target .. " " .. hit.entry.name,
			file = hit.entry.path,
			pos = { hit.link.line, hit.link.col - 1 },
			target = hit.link.target,
			name = hit.entry.name,
		}
	end
	if #items == 0 then
		return util.notify("No broken links")
	end
	Snacks.picker.pick({
		title = "Broken links  (<C-n> creates the note)",
		items = items,
		format = function(item)
			return { { item.target, "NotesLinkMissing" }, { "  in ", "NotesBorder" }, { item.name, "NotesMuted" } }
		end,
		preview = "file",
		actions = {
			create = function(picker, item)
				picker:close()
				if item then
					vim.schedule(function()
						vault.create(vault.folder("inbox") .. "/" .. util.filename(vim.fs.basename(item.target)) .. ".md", { template = "note" })
					end)
				end
			end,
		},
		win = { input = { keys = { ["<C-n>"] = { "create", mode = { "i", "n" } } } } },
		confirm = open,
	})
end

--- Notes with a tag (or one below it).
function M.tag(tag)
	for name, entries in pairs(index.tags()) do
		if name:lower() == tag:lower() then
			return M.notes(by_time(entries), "#" .. name)
		end
	end
	util.notify("No notes with #" .. tag)
end

--- All tags as a tree, with counts.
function M.tags()
	local items = {}
	for tag, entries in pairs(index.refresh().tags()) do
		items[#items + 1] = { text = tag, tag = tag, count = #entries, entries = entries }
	end
	table.sort(items, function(a, b)
		return a.tag:lower() < b.tag:lower()
	end)
	if #items == 0 then
		return util.notify("No tags yet")
	end
	Snacks.picker.pick({
		title = "Tags  (<C-r> renames)",
		items = items,
		layout = { preset = "select" },
		format = function(item)
			local depth = select(2, item.tag:gsub("/", ""))
			return { { ("  "):rep(depth) }, { "#" .. item.tag, "NotesTag" }, { "  " .. item.count, "NotesMuted" } }
		end,
		actions = {
			rename_tag = function(picker, item)
				picker:close()
				if item then
					vim.schedule(function()
						require("notes.refactor").rename_tag(item.tag)
					end)
				end
			end,
		},
		win = { input = { keys = { ["<C-r>"] = { "rename_tag", mode = { "i", "n" } } } } },
		confirm = function(picker, item)
			picker:close()
			if item then
				vim.schedule(function()
					M.notes(by_time(item.entries), "#" .. item.tag)
				end)
			end
		end,
	})
end

--- Tasks. <CR> goes to the task, <C-t> ticks it off, <C-d> changes its due date.
function M.tasks(opts)
	opts = opts or {}
	local rows = opts.rows
	if not rows then
		local all = vim.list_extend({}, index.refresh().tasks())
		vim.list_extend(all, require("notes.todoist").rows())
		rows = vim.tbl_filter(function(row)
			return opts.done or not T.is_done(row.task.status)
		end, all)
		rows = vim.list_extend({}, rows)
		local urgency = require("notes.query.tasksq").urgency
		table.sort(rows, function(a, b)
			local x, y = urgency(a.task), urgency(b.task)
			if x ~= y then
				return x > y
			end
			return a.entry.rel .. a.task.line < b.entry.rel .. b.task.line
		end)
	end
	if #rows == 0 then
		return util.notify("No tasks")
	end
	local function edit(fn)
		return function(picker, item)
			if item then
				picker:close()
				vim.schedule(function()
					fn(item)
					if opts.rows == nil then
						M.tasks(opts)
					end
				end)
			end
		end
	end
	Snacks.picker.pick({
		title = (opts.title or "Tasks") .. "  (<C-t> done, <C-d> date)",
		items = vim.tbl_map(function(row)
			if row.todoist then
				return { text = row.task.body .. " todoist", row = row, name = row.entry.name, preview = { text = row.task.text .. "\n\n" .. (row.todoist.description or ""), ft = "markdown" } }
			end
			return { text = row.task.body .. " " .. row.entry.name, file = row.entry.path, pos = { row.task.line, 0 }, row = row, name = row.entry.name }
		end, rows),
		format = function(item)
			return require("notes.blocks").task_chunks(item.row, { source = true })
		end,
		preview = function(ctx)
			if ctx.item.row.todoist then
				return Snacks.picker.preview.preview(ctx)
			end
			return Snacks.picker.preview.file(ctx)
		end,
		actions = {
			toggle_task = edit(function(item)
				if item.row.todoist then
					return require("notes.todoist").close(item.row.todoist)
				end
				T.edit(item.file, item.row.task.line, item.row.task.raw, T.toggle)
			end),
			task_date = function(picker, item)
				picker:close()
				if item and item.row.todoist then
					vim.schedule(function()
						vim.ui.input({ prompt = "Due (Todoist words)" }, function(text)
							if text and vim.trim(text) ~= "" then
								require("notes.todoist").update(item.row.todoist, { due_string = text })
							end
						end)
					end)
				elseif item then
					vim.schedule(function()
						T.ask_date("Due date", item.row.task.due, function(date)
							T.edit(item.file, item.row.task.line, item.row.task.raw, function(line)
								return { T.set_date(line, "due", date) }
							end)
						end)
					end)
				end
			end,
		},
		win = { input = { keys = { ["<C-t>"] = { "toggle_task", mode = { "i", "n" } }, ["<C-d>"] = { "task_date", mode = { "i", "n" } } } } },
		confirm = function(picker, item)
			if item and item.row.todoist then
				picker:close()
				return vim.ui.open(require("notes.todoist").url(item.row.todoist.id))
			end
			open(picker, item)
		end,
	})
end

--- Templates to insert or to start a note from.
function M.boards()
	local entries = vim.tbl_filter(function(entry)
		return entry.fm["kanban-plugin"] ~= nil
	end, index.refresh().all())
	if #entries == 0 then
		return require("notes.kanban").create()
	end
	Snacks.picker.pick({
		title = "Boards  (<C-n> new)",
		items = note_items(entries),
		format = note_format,
		preview = "file",
		actions = {
			new_board = function(picker)
				picker:close()
				vim.schedule(function()
					require("notes.kanban").create()
				end)
			end,
		},
		win = { input = { keys = { ["<C-n>"] = { "new_board", mode = { "i", "n" } } } } },
		confirm = function(picker, item)
			picker:close()
			if item then
				vim.schedule(function()
					require("notes.kanban").open(item.file)
				end)
			end
		end,
	})
end

--- Other files in the vault; <CR> opens them, <C-l> embeds them here.
function M.attachments()
	index.refresh()
	local items = {}
	for _, rel in pairs(index.files) do
		items[#items + 1] = { text = rel, file = vault.abs(rel), name = vim.fs.basename(rel) }
	end
	if #items == 0 then
		return util.notify("No attachments")
	end
	table.sort(items, function(a, b)
		return a.text < b.text
	end)
	Snacks.picker.pick({
		title = "Attachments  (<C-l> embeds)",
		items = items,
		format = "file",
		preview = "file",
		actions = {
			embed = function(picker, item)
				picker:close()
				if item then
					vim.schedule(function()
						vim.api.nvim_put({ "![[" .. item.name .. "]]" }, "c", true, true)
					end)
				end
			end,
		},
		win = { input = { keys = { ["<C-l>"] = { "embed", mode = { "i", "n" } } } } },
		confirm = function(picker, item)
			picker:close()
			if item then
				vim.ui.open(item.file)
			end
		end,
	})
end

return M
