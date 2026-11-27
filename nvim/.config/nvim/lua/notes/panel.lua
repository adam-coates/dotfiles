-- The context panel: Obsidian's right sidebar in one window. Calendar, outline,
-- backlinks, unlinked mentions, outgoing links, tags and properties of the note
-- you are in, updated as you move around.
--
--   <CR> open    o peek (stay here)    s / v in a split    <Tab> fold a section
--   l    turn an unlinked mention into a link     [ ] other month     q close

local settings = require("settings")
local util = require("notes.util")
local vault = require("notes.vault")
local index = require("notes.index")
local D = require("notes.date")

local M = {}

local ns = vim.api.nvim_create_namespace("notes_panel")
local hl_ns = vim.api.nvim_create_namespace("notes_panel_current")

local state = {
	buf = nil, ---@type integer?
	win = nil, ---@type integer?
	note = nil, ---@type notes.Entry?
	source = nil, ---@type integer? buffer of the note
	month = nil, ---@type string?
	folded = { properties = true, mentions = true },
	items = {}, -- row -> action
	mentions = nil, -- { rel, version, list }
	headings = {}, -- row -> line
	day_at = nil,
	day_row = 0,
}
M.state = state

function M.is_open()
	return state.win ~= nil and vim.api.nvim_win_is_valid(state.win)
end

-- Content ---------------------------------------------------------------------------

local SECTIONS = { "calendar", "outline", "backlinks", "mentions", "outgoing", "tags", "properties" }
local LABEL = {
	outline = "󰉹 Outline",
	backlinks = "󰌹 Backlinks",
	mentions = "󰍉 Unlinked mentions",
	outgoing = "󰏌 Outgoing links",
	tags = "󰓹 Tags",
	properties = "󰌪 Properties",
}

local function width()
	return (M.is_open() and vim.api.nvim_win_get_width(state.win) or settings.panel_width) - 2
end

-- A line of context around a link, trimmed so that the link itself is visible.
local function context(text, col, room)
	local plain = util.plain(text:gsub("^%s*[-*+>]%s*%[?.?%]?%s*", ""):gsub("^#+%s*", ""))
	if vim.fn.strdisplaywidth(plain) <= room then
		return plain
	end
	local before = util.plain(text:sub(1, math.max(0, (col or 1) - 1)))
	local skip = vim.fn.strchars(before) - math.floor(room / 3)
	if skip > 0 then
		plain = "…" .. vim.fn.strcharpart(plain, skip)
	end
	return util.truncate(plain, room)
end

-- Group { entry, ... } hits by note.
local function by_note(hits)
	local groups, order = {}, {}
	for _, hit in ipairs(hits) do
		local rel = hit.entry.rel
		if not groups[rel] then
			groups[rel] = { entry = hit.entry, hits = {} }
			order[#order + 1] = groups[rel]
		end
		table.insert(groups[rel].hits, hit)
	end
	table.sort(order, function(a, b)
		return a.entry.mtime > b.entry.mtime
	end)
	return order
end

local build = {}

function build.calendar(add, _)
	state.month = state.month or D.today():sub(1, 7)
	local _, day = require("notes.periodic").identify(state.note and state.note.path or "")
	local rows, at = require("notes.calendar").rows(state.month, day)
	local pad = (" "):rep(math.max(0, math.floor((width() - 32) / 2)))
	state.day_at, state.day_pad = at, #pad
	for i, row in ipairs(rows) do
		local lnum = add(vim.list_extend({ pad }, row))
		if i == 1 then
			state.day_row = lnum - 1
		end
	end
	add({ "" })
end

function build.outline(add, note)
	state.headings = {}
	for _, h in ipairs(note.headings) do
		local text = (" "):rep((h.level - 1) * 2) .. util.truncate(util.plain(h.text), width() - (h.level - 1) * 2 - 2)
		local row = add({ "  ", { text, "RenderMarkdownH" .. h.level } }, { kind = "line", line = h.line })
		state.headings[row] = h.line
	end
end

function build.backlinks(add, note)
	for _, group in ipairs(by_note(index.backlinks(note))) do
		add({ "  ", { util.truncate(group.entry.name, width() - 6), "NotesLink" }, { " " .. #group.hits, "NotesMuted" } }, { kind = "open", path = group.entry.path, line = group.hits[1].link.line })
		for _, hit in ipairs(group.hits) do
			local text = hit.link.property and "in properties" or context(hit.link.text, hit.link.col, width() - 5)
			add({ { "    " .. text, "NotesMuted" } }, { kind = "open", path = group.entry.path, line = hit.link.line, col = hit.link.col - 1 })
		end
	end
end

function build.mentions(add, _)
	for _, group in ipairs(by_note(state.mentions and state.mentions.list or {})) do
		add({ "  ", { util.truncate(group.entry.name, width() - 6), "NotesLink" }, { " " .. #group.hits, "NotesMuted" } }, { kind = "open", path = group.entry.path, line = group.hits[1].line })
		for _, hit in ipairs(group.hits) do
			add({ { "    " .. context(hit.text, hit.col, width() - 5), "NotesMuted" } }, { kind = "mention", path = group.entry.path, line = hit.line, col = hit.col - 1, hit = hit })
		end
	end
end

function build.outgoing(add, note)
	local seen = {}
	for _, link in ipairs(note.links) do
		local key = link.target:lower()
		if link.target ~= "" and not seen[key] then
			seen[key] = true
			local to = index.resolve(link.target, note)
			local file = not to and index.resolve_file(link.target, note)
			if to then
				add({ "  ", { util.truncate(to.name, width() - 3), "NotesLink" } }, { kind = "open", path = to.path })
			elseif file then
				add({ "  ", { "󰁦 " .. util.truncate(vim.fs.basename(file), width() - 5), "NotesText" } }, { kind = "file", path = vault.abs(file) })
			else
				add({ "  ", { util.truncate(link.target, width() - 12), "NotesLinkMissing" }, { " (new)", "NotesMuted" } }, { kind = "create", target = link.target })
			end
		end
	end
end

function build.tags(add, note)
	local tags = index.tags()
	for _, tag in ipairs(note.tags) do
		local entries = tags[tag] or {}
		add({ "  ", { "#" .. tag, "NotesTag" }, { " " .. #entries, "NotesMuted" } }, { kind = "tag", tag = tag })
	end
end

function build.properties(add, note)
	local X = require("notes.query.expr")
	local keys = {}
	for key in pairs(note.fm) do
		keys[#keys + 1] = tostring(key)
	end
	table.sort(keys)
	for _, key in ipairs(keys) do
		local value = X.tostring(X.from(note.fm[key]))
		add({ "  ", { key, "NotesField" }, " ", { util.truncate(value, math.max(4, width() - #key - 4)), "NotesText" } }, { kind = "line", line = 1 })
	end
	for key, value in vim.spairs(note.fields) do
		add({ "  ", { key, "NotesField" }, " ", { util.truncate(util.plain(value), math.max(4, width() - #key - 4)), "NotesText" } }, nil)
	end
end

local function count(section, note)
	if section == "outline" then
		return #note.headings
	elseif section == "backlinks" then
		return #index.backlinks(note)
	elseif section == "mentions" then
		return state.mentions and #state.mentions.list or 0
	elseif section == "outgoing" then
		local seen, n = {}, 0
		for _, link in ipairs(note.links) do
			if link.target ~= "" and not seen[link.target:lower()] then
				seen[link.target:lower()] = true
				n = n + 1
			end
		end
		return n
	elseif section == "tags" then
		return #note.tags
	end
	return vim.tbl_count(note.fm) + vim.tbl_count(note.fields)
end

function M.render()
	if not M.is_open() then
		return
	end
	local rows = {}
	state.items, state.headings = {}, {}
	local function add(row, item)
		rows[#rows + 1] = row
		state.items[#rows] = item
		return #rows
	end

	add({ "" })
	build.calendar(add)
	local note = state.note
	if note then
		add({ " ", { util.truncate(note.name, width()), "NotesTitle" } }, { kind = "line", line = 1 })
		add({ { (" %d words"):format(note.words) .. (note.folder ~= "" and (" · " .. note.folder) or ""), "NotesMuted" } })
		add({ "" })
		for _, section in ipairs(SECTIONS) do
			if section ~= "calendar" then
				local n = count(section, note)
				if n > 0 or section == "backlinks" then
					local folded = state.folded[section]
					add({ { (folded and " ▸ " or " ▾ ") .. LABEL[section], "NotesHeader" }, { " " .. n, "NotesMuted" } }, { kind = "section", section = section })
					if not folded then
						if n == 0 then
							add({ { "  No notes link here yet", "NotesMuted" } })
						end
						build[section](add, note)
						add({ "" })
					end
				end
			end
		end
	else
		add({ { "  Open a note to see its context", "NotesMuted" } })
	end
	-- Keep the panel's own cursor where it was.
	local view = vim.api.nvim_win_get_cursor(state.win)
	util.render(state.buf, ns, rows)
	pcall(vim.api.nvim_win_set_cursor, state.win, { math.min(view[1], #rows), view[2] })
	M.mark_heading()
end

--- Highlight the heading the cursor is under.
function M.mark_heading()
	if not M.is_open() or not state.source or not vim.api.nvim_buf_is_valid(state.source) then
		return
	end
	local win = vim.fn.bufwinid(state.source)
	if win == -1 then
		return
	end
	local line = vim.api.nvim_win_get_cursor(win)[1]
	local best_row, best = nil, 0
	for row, at in pairs(state.headings) do
		if at <= line and at > best then
			best_row, best = row, at
		end
	end
	vim.api.nvim_buf_clear_namespace(state.buf, hl_ns, 0, -1)
	if best_row then
		vim.api.nvim_buf_set_extmark(state.buf, hl_ns, best_row - 1, 0, { line_hl_group = "NotesActive" })
	end
end

-- Keeping up ------------------------------------------------------------------------

local function find_mentions()
	local note = state.note
	if not note or (state.mentions and state.mentions.rel == note.rel and state.mentions.version == index.version) then
		return
	end
	local version = index.version
	index.mentions(note, function(list)
		if state.note and state.note.rel == note.rel then
			state.mentions = { rel = note.rel, version = version, list = list }
			M.render()
		end
	end)
end

--- Show the note in a buffer (default: the current one, if it is a note).
function M.update(buf)
	buf = buf or vim.api.nvim_get_current_buf()
	if not M.is_open() or not vim.api.nvim_buf_is_valid(buf) then
		return
	end
	local note = index.buffer(buf)
	if note then
		if not state.note or state.note.rel ~= note.rel then
			state.mentions = nil
			local _, day = require("notes.periodic").identify(note.path)
			if day then
				state.month = day:sub(1, 7)
			end
		end
		state.note, state.source = note, buf
	elseif state.source and vim.api.nvim_buf_is_valid(state.source) then
		state.note = index.buffer(state.source) or state.note
	end
	M.render()
	find_mentions()
end

-- Actions ------------------------------------------------------------------------------

local function follow(opts)
	opts = opts or {}
	local pos = vim.api.nvim_win_get_cursor(state.win)
	local item = state.items[pos[1]]
	if not item and state.day_at then
		local iso, week = state.day_at(pos[1] - state.day_row, pos[2] - state.day_pad)
		if iso then
			return require("notes.periodic").open("daily", iso, opts)
		elseif week then
			return require("notes.periodic").open("weekly", week, opts)
		end
	end
	if not item then
		return
	end
	if item.kind == "section" then
		state.folded[item.section] = not state.folded[item.section]
		M.render()
	elseif item.kind == "open" or item.kind == "mention" then
		vault.open(item.path, { line = item.line, col = item.col, cmd = opts.cmd })
	elseif item.kind == "line" and state.note then
		vault.open(state.note.path, { line = item.line, cmd = opts.cmd })
	elseif item.kind == "tag" then
		require("notes.pickers").tag(item.tag)
	elseif item.kind == "file" then
		vim.ui.open(item.path)
	elseif item.kind == "create" then
		local path = vault.folder("inbox") .. "/" .. util.filename(item.target) .. ".md"
		vault.create(path, { template = "note", cmd = opts.cmd })
	end
	if opts.stay and M.is_open() then
		vim.api.nvim_set_current_win(state.win)
	end
end

local function link_mention()
	local item = state.items[vim.api.nvim_win_get_cursor(state.win)[1]]
	if not item or item.kind ~= "mention" or not state.note then
		return util.notify("Not on an unlinked mention", "warn")
	end
	local hit, name = item.hit, state.note.name
	local ok = require("notes.tasks").edit(item.path, hit.line, hit.text, function(line)
		local word = line:sub(hit.col, hit.col + #hit.word - 1)
		local link = word == name and ("[[" .. name .. "]]") or ("[[" .. name .. "|" .. word .. "]]")
		return { line:sub(1, hit.col - 1) .. link .. line:sub(hit.col + #hit.word) }
	end)
	if ok then
		state.mentions = nil
		M.update(state.source)
	end
end

local function month(delta)
	return function()
		state.month = D.add(state.month .. "-01", delta, "month"):sub(1, 7)
		M.render()
	end
end

local function keymaps(buf)
	local function map(lhs, fn, desc)
		vim.keymap.set("n", lhs, fn, { buffer = buf, nowait = true, desc = desc })
	end
	map("<CR>", follow, "Open")
	map("<2-LeftMouse>", follow, "Open")
	map("o", function()
		follow({ stay = true })
	end, "Open, stay in the panel")
	map("s", function()
		follow({ cmd = "split" })
	end, "Open below")
	map("v", function()
		follow({ cmd = "vsplit" })
	end, "Open beside")
	map("<Tab>", function()
		local row = vim.api.nvim_win_get_cursor(0)[1]
		while row > 0 do
			local item = state.items[row]
			if item and item.kind == "section" then
				state.folded[item.section] = not state.folded[item.section]
				M.render()
				return pcall(vim.api.nvim_win_set_cursor, state.win, { row, 0 })
			end
			row = row - 1
		end
	end, "Fold section")
	map("l", link_mention, "Link this mention")
	map("[", month(-1), "Previous month")
	map("]", month(1), "Next month")
	map("t", function()
		state.month = D.today():sub(1, 7)
		M.render()
	end, "This month")
	map("r", function()
		index.refresh()
		state.mentions = nil
		M.update(state.source)
	end, "Refresh")
	map("q", M.close, "Close")
	map("?", function()
		util.float({
			"<CR>   open              o  open, stay here",
			"s / v  open in a split   <Tab>  fold section",
			"l      link the mention under the cursor",
			"[ / ]  other month       t  this month",
			"r      refresh           q  close",
		}, { title = "Context panel" })
	end, "Help")
end

function M.open(opts)
	opts = opts or {}
	if M.is_open() then
		return
	end
	local source = vim.api.nvim_get_current_buf()
	if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
		state.buf = vim.api.nvim_create_buf(false, true)
		vim.bo[state.buf].bufhidden = "hide"
		vim.bo[state.buf].filetype = "notespanel"
		vim.api.nvim_buf_set_name(state.buf, "notes://context")
		keymaps(state.buf)
	end
	state.win = vim.api.nvim_open_win(state.buf, opts.enter == true, { split = "right", win = -1, width = settings.panel_width })
	local wo = vim.wo[state.win]
	wo.winfixwidth, wo.winfixbuf, wo.wrap, wo.number, wo.relativenumber = true, true, false, false, false
	wo.signcolumn, wo.foldcolumn, wo.spell, wo.list, wo.cursorline = "no", "0", false, false, opts.enter == true
	wo.statuscolumn, wo.conceallevel = "", 0
	wo.winhighlight = "Normal:Normal,CursorLine:NotesActive"
	M.update(source)
end

function M.close()
	if M.is_open() then
		if #vim.api.nvim_tabpage_list_wins(0) > 1 then
			vim.api.nvim_win_close(state.win, true)
		end
		state.win = nil
	end
end

function M.toggle()
	if M.is_open() then
		M.close()
	else
		M.open()
	end
end

--- Jump into the panel, opening it if needed.
function M.focus(section)
	if not M.is_open() then
		M.open({ enter = true })
	end
	if section then
		state.folded[section] = false
		M.render()
	end
	vim.api.nvim_set_current_win(state.win)
	for row, item in pairs(state.items) do
		if section and item.kind == "section" and item.section == section then
			vim.api.nvim_win_set_cursor(state.win, { row, 0 })
		end
	end
end

function M.setup()
	local group = vim.api.nvim_create_augroup("notes_panel", { clear = true })
	local update = util.debounce(60, function(buf)
		M.update(buf)
	end)
	vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost" }, {
		group = group,
		pattern = "*.md",
		callback = function(ev)
			if M.is_open() then
				update(ev.buf)
			end
		end,
	})
	local typing = util.debounce(500, function(buf)
		M.update(buf)
	end)
	vim.api.nvim_create_autocmd({ "TextChanged", "InsertLeave" }, {
		group = group,
		pattern = "*.md",
		callback = function(ev)
			if M.is_open() then
				typing(ev.buf)
			end
		end,
	})
	vim.api.nvim_create_autocmd("User", {
		group = group,
		pattern = { "NotesChanged", "TodoistChanged" },
		callback = function()
			if M.is_open() then
				update(state.source or vim.api.nvim_get_current_buf())
			end
		end,
	})
	vim.api.nvim_create_autocmd({ "WinEnter", "WinLeave" }, {
		group = group,
		callback = function(ev)
			if M.is_open() and vim.api.nvim_get_current_win() == state.win then
				vim.wo[state.win].cursorline = ev.event == "WinEnter"
			end
		end,
	})
	local mark = util.debounce(80, M.mark_heading)
	vim.api.nvim_create_autocmd("CursorMoved", {
		group = group,
		pattern = "*.md",
		callback = function()
			if M.is_open() then
				mark()
			end
		end,
	})
	vim.api.nvim_create_autocmd("VimResized", {
		group = group,
		callback = function()
			if M.is_open() then
				vim.api.nvim_win_set_width(state.win, settings.panel_width)
				M.render()
			end
		end,
	})
	-- Don't keep Neovim open just for the panel.
	vim.api.nvim_create_autocmd("QuitPre", {
		group = group,
		callback = function()
			if not M.is_open() then
				return
			end
			local others = vim.tbl_filter(function(win)
				return win ~= state.win and win ~= vim.api.nvim_get_current_win() and vim.api.nvim_win_get_config(win).relative == ""
			end, vim.api.nvim_tabpage_list_wins(0))
			if #others == 0 and vim.api.nvim_get_current_win() ~= state.win then
				M.close()
			end
		end,
	})
end

return M
