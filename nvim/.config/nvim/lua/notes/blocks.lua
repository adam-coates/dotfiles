-- Draws the results of ```dataview and ```tasks blocks, and of `= inline`
-- queries, as virtual text. The note itself is never changed. With the cursor in a
-- block you see (and edit) the query; <CR> lists the results to jump to or tick off.

local util = require("notes.util")
local index = require("notes.index")
local vault = require("notes.vault")
local X = require("notes.query.expr")
local T = require("notes.tasks")

local M = {}

local ns = vim.api.nvim_create_namespace("notes_blocks")
local LANGS = { dataview = true, tasks = true, todoist = true }
local ICON = { table = "󰓫", list = "󰉹", task = "󰄲" }

local cache = {} ---@type table<integer, { blocks: table[], inlines: table[], tick: integer, width: integer, open: integer? }>

-- Finding blocks ---------------------------------------------------------------------

--- { lang, first, last, text } with 1-based lines of the fences.
function M.find(lines)
	local out, i = {}, 1
	while i <= #lines do
		local ticks, lang = lines[i]:match("^%s*(```+)%s*(%w*)")
		if ticks then
			local close
			for j = i + 1, #lines do
				local other = lines[j]:match("^%s*(```+)%s*$")
				if other and #other >= #ticks then
					close = j
					break
				end
			end
			if not close then
				break
			end
			if LANGS[lang:lower()] then
				out[#out + 1] = { lang = lang:lower(), first = i, last = close, text = table.concat(lines, "\n", i + 1, close - 1) }
			end
			i = close + 1
		else
			i = i + 1
		end
	end
	return out
end

function M.run(block, entry)
	if block.lang == "tasks" then
		return require("notes.query.tasksq").query(block.text)
	elseif block.lang == "todoist" then
		return require("notes.todoist").query(block.text, entry)
	end
	return require("notes.query.dql").query(block.text, entry)
end

-- Drawing ------------------------------------------------------------------------------

--- A task as chunks of text.
function M.task_chunks(row, opts)
	opts = opts or {}
	local task, hide = row.task, opts.hide or {}
	local done = T.is_done(task.status)
	local box = { [" "] = { "󰄱 ", "NotesText" }, ["/"] = { "󰡖 ", "NotesYellow" }, x = { "󰱒 ", "NotesGreen" }, X = { "󰱒 ", "NotesGreen" }, ["-"] = { "󰜺 ", "NotesMuted" } }
	local chunks = { box[task.status] or { "󰄱 ", "NotesBlue" } }
	local text = util.plain(task.text)
	if hide["tags"] then
		text = vim.trim((text:gsub("#[%w_/%-]+", "")))
	end
	-- Colour the #tags within the text
	local pos = 1
	for s, tag, e in text:gmatch("()(#[%w_/%-]+)()") do
		if s == 1 or text:sub(s - 1, s - 1):match("%s") then
			chunks[#chunks + 1] = { text:sub(pos, s - 1), done and "NotesDone" or "NotesText" }
			chunks[#chunks + 1] = { tag, "NotesTag" }
			pos = e
		end
	end
	chunks[#chunks + 1] = { text:sub(pos), done and "NotesDone" or "NotesText" }
	if T.priorities[task.priority] and not hide["priority"] then
		chunks[#chunks + 1] = { " " .. T.priorities[task.priority], T.priority_hl[task.priority] }
	end
	if task.recur and not hide["recurrence rule"] then
		chunks[#chunks + 1] = { " 󰑖 " .. task.recur, "NotesMuted" }
	end
	local D = require("notes.date")
	if done then
		if task.done and not hide["done date"] then
			chunks[#chunks + 1] = { " ✓ " .. D.human(task.done), "NotesMuted" }
		end
	else
		if task.scheduled and not hide["scheduled date"] then
			chunks[#chunks + 1] = { " 󰥔 " .. D.human(task.scheduled), T.date_hl(task.scheduled) }
		end
		if task.due and not hide["due date"] then
			chunks[#chunks + 1] = { " 󰃭 " .. D.human(task.due), T.date_hl(task.due) }
		end
	end
	if opts.source and not hide["backlink"] then
		chunks[#chunks + 1] = { "  " .. row.entry.name, "NotesBorder" }
	end
	return chunks
end

-- Cut a list of chunks to a width.
local function fit(chunks, width)
	local out, used = {}, 0
	for _, chunk in ipairs(chunks) do
		local w = vim.fn.strdisplaywidth(chunk[1])
		if used + w > width then
			if width - used > 1 then
				out[#out + 1] = { util.truncate(chunk[1], width - used), chunk[2] }
			end
			return out
		end
		out[#out + 1], used = chunk, used + w
	end
	return out
end

local function cell_hl(value)
	local kind = X.kind(value)
	if kind == "link" then
		return value.entry and "NotesLink" or "NotesLinkMissing"
	elseif kind == "number" then
		return "NotesYellow"
	elseif kind == "date" then
		return "NotesDate"
	elseif kind == "null" then
		return "NotesBorder"
	elseif kind == "string" and value:match("^#[%w_/%-]+$") then
		return "NotesTag"
	elseif kind == "list" and value.items[1] and X.kind(value.items[1]) == "link" then
		return "NotesLink"
	elseif kind == "list" and type(value.items[1]) == "string" and value.items[1]:match("^#") then
		return "NotesTag"
	end
	return "NotesText"
end

local function text_of(value)
	if X.kind(value) == "list" then
		return table.concat(vim.tbl_map(text_of, value.items), ", ")
	end
	return (util.plain(X.tostring(value)):gsub("%s+", " "))
end

local function draw_table(result, width)
	local n = #result.headers
	if n == 0 then
		return { { { "  (no columns)", "NotesMuted" } } }
	end
	local texts, widths, numeric = {}, {}, {}
	for c = 1, n do
		widths[c] = vim.fn.strdisplaywidth(result.headers[c].name)
		numeric[c] = #result.rows > 0
	end
	for r, row in ipairs(result.rows) do
		texts[r] = {}
		for c = 1, n do
			texts[r][c] = text_of(row.cells[c])
			widths[c] = math.max(widths[c], vim.fn.strdisplaywidth(texts[r][c]))
			local kind = X.kind(row.cells[c])
			numeric[c] = numeric[c] and (kind == "number" or kind == "null")
		end
	end
	-- Shrink the widest column until everything fits.
	local function total()
		local sum = 1
		for c = 1, n do
			sum = sum + widths[c] + 3
		end
		return sum
	end
	while total() > width do
		local widest = 1
		for c = 2, n do
			if widths[c] > widths[widest] then
				widest = c
			end
		end
		if widths[widest] <= 6 then
			break
		end
		widths[widest] = widths[widest] - 1
	end
	local function rule(left, mid, right)
		local parts = {}
		for c = 1, n do
			parts[c] = ("─"):rep(widths[c] + 2)
		end
		return { { left .. table.concat(parts, mid) .. right, "NotesBorder" } }
	end
	local function line(get, hl)
		local chunks = { { "│", "NotesBorder" } }
		for c = 1, n do
			local text = util.truncate(get(c), widths[c])
			chunks[#chunks + 1] = { " " .. util.pad(text, widths[c], numeric[c] and "right" or nil) .. " ", hl(c) }
			chunks[#chunks + 1] = { "│", "NotesBorder" }
		end
		return chunks
	end
	local out = {
		rule("╭", "┬", "╮"),
		line(function(c)
			return result.headers[c].name
		end, function()
			return "NotesCellHead"
		end),
		rule("├", "┼", "┤"),
	}
	for r, row in ipairs(result.rows) do
		out[#out + 1] = line(function(c)
			return texts[r][c]
		end, function(c)
			return cell_hl(row.cells[c])
		end)
	end
	out[#out + 1] = rule("╰", "┴", "╯")
	return out
end

--- Lines of chunks for a result.
function M.draw(result, width)
	if result.error then
		return { { { "  󰅚 " .. util.truncate(result.error, width - 6), "NotesError" } } }
	end
	local out = {}
	if result.loading then
		return { { { "  󰄵 Asking Todoist…", "NotesMuted" } } }
	elseif result.count == 0 then
		return { { { "  Nothing found", "NotesMuted" } } }
	elseif result.type == "table" then
		return draw_table(result, width)
	elseif result.type == "list" then
		for _, row in ipairs(result.rows) do
			local chunks = { { "  • ", "NotesAccent" } }
			for i, cell in ipairs(row.cells) do
				if i > 1 then
					chunks[#chunks + 1] = { ": ", "NotesMuted" }
				end
				chunks[#chunks + 1] = { text_of(cell), cell_hl(cell) }
			end
			out[#out + 1] = fit(chunks, width)
			for _, member in ipairs(row.members or {}) do
				out[#out + 1] = fit({ { "    ◦ ", "NotesMuted" }, { member.entry.name, "NotesLink" } }, width)
			end
		end
		return out
	end
	for _, group in ipairs(result.groups) do
		if group.name then
			out[#out + 1] = { { " " .. util.truncate(group.name, width - 8), group.entry and "NotesLink" or "NotesHeader" }, { " " .. #group.tasks, "NotesMuted" } }
		end
		for _, row in ipairs(group.tasks) do
			local chunks = { { (" "):rep(2 + (result.flat and 0 or math.min(row.task.indent or 0, 8))), "NotesMuted" } }
			vim.list_extend(chunks, M.task_chunks(row, { source = not group.entry and not result.short, hide = result.hide }))
			out[#out + 1] = fit(chunks, width)
		end
	end
	if result.total and result.total > result.count then
		out[#out + 1] = { { ("  %d of %d"):format(result.count, result.total), "NotesMuted" } }
	end
	return out
end

-- Placing ----------------------------------------------------------------------------

local function text_width(buf)
	local win = vim.fn.bufwinid(buf)
	if win == -1 then
		return 80
	end
	local info = vim.fn.getwininfo(win)[1]
	return math.max(30, math.min(info.width - info.textoff - 1, 130))
end

local function cursor_row(buf)
	if vim.api.nvim_get_current_buf() ~= buf then
		return -1
	end
	return vim.api.nvim_win_get_cursor(0)[1]
end

local function place(buf)
	local state = cache[buf]
	if not state then
		return
	end
	vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
	local row = cursor_row(buf)
	state.open = nil
	local last_line = vim.api.nvim_buf_line_count(buf)
	for i, block in ipairs(state.blocks) do
		if block.last <= last_line then
			local open = row >= block.first and row <= block.last
			local virt = vim.deepcopy(block.lines)
			if open then
				state.open = i
				vim.api.nvim_buf_set_extmark(buf, ns, block.last - 1, 0, { virt_lines = virt, virt_lines_leftcol = false })
			else
				local result = block.result
				local title = result.error and "query" or (result.type == "task" and (block.lang == "todoist" and "todoist" or "tasks") or result.type)
				local header = { { " " .. (ICON[result.type] or "󰆼") .. " " .. title, "NotesMuted" }, { " · " .. (result.count or 0), "NotesMuted" } }
				local length = #(vim.api.nvim_buf_get_lines(buf, block.first - 1, block.first, false)[1] or "")
				vim.api.nvim_buf_set_extmark(buf, ns, block.first - 1, 0, {
					end_col = length,
					conceal = "",
					virt_text = header,
					virt_text_pos = "overlay",
					virt_lines = virt,
					priority = 250,
				})
				-- Hide the rest of the block.
				for lnum = block.first, block.last - 1 do
					vim.api.nvim_buf_set_extmark(buf, ns, lnum, 0, { end_row = lnum, conceal_lines = "", priority = 250 })
				end
			end
		end
	end
	for _, inline in ipairs(state.inlines) do
		if inline.row ~= row then
			pcall(vim.api.nvim_buf_set_extmark, buf, ns, inline.row - 1, inline.from, {
				end_col = inline.to,
				conceal = "",
				virt_text = { { inline.value, inline.hl } },
				virt_text_pos = "inline",
				priority = 250,
			})
		end
	end
end

--- Run every query in a buffer and draw the results.
function M.refresh(buf)
	buf = (buf == nil or buf == 0) and vim.api.nvim_get_current_buf() or buf
	if not vim.api.nvim_buf_is_loaded(buf) or not vault.is_note(vim.api.nvim_buf_get_name(buf)) then
		return
	end
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	local blocks = M.find(lines)
	local inlines, fence = {}, nil
	local entry
	local has_inline = false
	for _, line in ipairs(lines) do
		if line:find("`= ", 1, true) then
			has_inline = true
			break
		end
	end
	if #blocks == 0 and not has_inline then
		if cache[buf] then
			cache[buf] = nil
			vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
		end
		return
	end
	if vim.b[buf].notes_no_queries then
		vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
		return
	end
	entry = index.get(vim.api.nvim_buf_get_name(buf)) or index.buffer(buf)
	local width = text_width(buf)
	for _, block in ipairs(blocks) do
		block.result = M.run(block, entry)
		block.lines = M.draw(block.result, width)
		if (lines[block.last + 1] or ""):match("%S") then
			block.lines[#block.lines + 1] = { { "", "NotesMuted" } }
		end
	end
	if has_inline then
		for i, line in ipairs(lines) do
			local ticks = line:match("^%s*([`~][`~][`~]+)")
			if ticks then
				fence = not fence and ticks or nil
			elseif not fence then
				for s, expr, e in line:gmatch("()`= ([^`]+)`()") do
					local value, err = require("notes.query.dql").inline(expr, entry)
					inlines[#inlines + 1] = { row = i, from = s - 1, to = e - 1, value = value or ("󰅚 " .. err), hl = value and "NotesYellow" or "NotesError" }
				end
			end
		end
	end
	cache[buf] = { blocks = blocks, inlines = inlines, width = width }
	place(buf)
end

--- The block the cursor is in.
function M.current()
	local state = cache[vim.api.nvim_get_current_buf()]
	local row = vim.api.nvim_win_get_cursor(0)[1]
	for _, block in ipairs(state and state.blocks or {}) do
		if row >= block.first and row <= block.last then
			return block
		end
	end
end

--- List the results of the block under the cursor.
function M.pick()
	local block = M.current()
	if not block then
		return false
	end
	local result = block.result
	if result.error then
		util.notify(result.error, "error")
		return true
	end
	if result.type == "task" then
		local rows = {}
		for _, group in ipairs(result.groups) do
			vim.list_extend(rows, group.tasks)
		end
		require("notes.pickers").tasks({ rows = rows, title = "Query results" })
		return true
	end
	local entries, seen = {}, {}
	local function add(entry)
		if entry and not seen[entry.rel] then
			seen[entry.rel] = true
			entries[#entries + 1] = entry
		end
	end
	for _, row in ipairs(result.rows) do
		add(row.entry)
		for _, member in ipairs(row.members or {}) do
			add(member.entry)
		end
		for _, cell in ipairs(row.cells) do
			if X.kind(cell) == "link" then
				add(cell.entry)
			end
		end
	end
	require("notes.pickers").notes(entries, "Query results")
	return true
end

function M.toggle()
	vim.b.notes_no_queries = not vim.b.notes_no_queries
	cache[vim.api.nvim_get_current_buf()] = nil
	M.refresh()
	util.notify("Query results " .. (vim.b.notes_no_queries and "hidden" or "shown"))
end

function M.setup()
	local group = vim.api.nvim_create_augroup("notes_blocks", { clear = true })
	local refresh = util.debounce(80, function(buf)
		M.refresh(buf)
	end)
	vim.api.nvim_create_autocmd({ "BufWinEnter", "BufWritePost", "InsertLeave", "TextChanged" }, {
		group = group,
		pattern = "*.md",
		callback = function(ev)
			refresh(ev.buf)
		end,
	})
	vim.api.nvim_create_autocmd("User", {
		group = group,
		pattern = "NotesChanged",
		callback = function()
			for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
				M.refresh(vim.api.nvim_win_get_buf(win))
			end
		end,
	})
	vim.api.nvim_create_autocmd({ "VimResized", "WinResized" }, {
		group = group,
		callback = function()
			for buf, state in pairs(cache) do
				if vim.api.nvim_buf_is_valid(buf) and vim.fn.bufwinid(buf) ~= -1 and text_width(buf) ~= state.width then
					refresh(buf)
				end
			end
		end,
	})
	-- Show the source of a block while the cursor is in it.
	vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "BufEnter", "BufLeave" }, {
		group = group,
		pattern = "*.md",
		callback = function(ev)
			local state = cache[ev.buf]
			if not state then
				return
			end
			local row = ev.event == "BufLeave" and -1 or cursor_row(ev.buf)
			local now
			for i, block in ipairs(state.blocks) do
				if row >= block.first and row <= block.last then
					now = i
				end
			end
			local inline
			for _, item in ipairs(state.inlines) do
				if item.row == row then
					inline = row
				end
			end
			if now ~= state.open or inline ~= state.inline then
				state.inline = inline
				place(ev.buf)
			end
		end,
	})
	vim.api.nvim_create_autocmd("BufWipeout", {
		group = group,
		callback = function(ev)
			cache[ev.buf] = nil
		end,
	})
end

return M
