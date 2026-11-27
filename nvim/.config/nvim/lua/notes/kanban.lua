-- Kanban boards in the format of Obsidian's Kanban plugin: a note with
-- `kanban-plugin: board` in its properties, ## headings as columns and tasks as
-- cards.
--
-- Cards are moved by moving their lines in the note's own buffer. Everything that
-- isn't a card (properties, settings, the archive, text between lists) is left as
-- it is, and u undoes. The existing plugins (kanban.nvim, super-kanban.nvim) parse
-- the note and write it out again, which loses properties and multi-line cards.

local settings = require("settings")
local util = require("notes.util")
local vault = require("notes.vault")
local D = require("notes.date")
local T = require("notes.tasks")

local M = {}

local ns = vim.api.nvim_create_namespace("notes_kanban")
local WIDTH = 34

-- Reading -----------------------------------------------------------------------------

--- Columns of a board: { title, line, last, complete, cards = { first, last, lines } }
--- with 1-based line numbers.
function M.parse(lines)
	local columns, column, card = {}, nil, nil
	local fence = false
	local start = 1
	if lines[1] and lines[1]:match("^%-%-%-%s*$") then
		for i = 2, #lines do
			if lines[i]:match("^%-%-%-%s*$") then
				start = i + 1
				break
			end
		end
	end
	for i = start, #lines do
		local line = lines[i]
		if line:match("^%%%% kanban:settings") or line:match("^%*%*%*%s*$") then
			break -- settings or archive
		end
		if line:match("^%s*```") then
			fence = not fence
		end
		local title = not fence and line:match("^##%s+(.-)%s*$")
		if title then
			column = { title = title, line = i, last = i, cards = {} }
			columns[#columns + 1] = column
			card = nil
		elseif column then
			if not fence and line:match("^[-*+]%s+%[.%]") then
				card = { first = i, last = i, lines = { line } }
				table.insert(column.cards, card)
				column.last = i
			elseif card and line:match("^%s+%S") then
				card.last = i
				table.insert(card.lines, line)
				column.last = i
			elseif line:match("^%*%*Complete%*%*") then
				column.complete = true
				column.last = i
				card = nil
			elseif line:match("%S") then
				card = nil
				column.last = i
			else
				card = nil
			end
		end
	end
	return columns
end

-- The line after which a card goes when it becomes number `pos` of a column.
local function slot(column, pos)
	if #column.cards == 0 then
		return column.last, true
	elseif pos <= 1 then
		return column.cards[1].first - 1
	end
	return column.cards[math.min(pos - 1, #column.cards)].last
end

-- Board -------------------------------------------------------------------------------

local Board = {}
Board.__index = Board

function Board:read()
	self.columns = M.parse(vim.api.nvim_buf_get_lines(self.source, 0, -1, false))
	self.col = math.max(1, math.min(self.col, #self.columns))
	local column = self.columns[self.col]
	self.row = column and math.max(1, math.min(self.row, math.max(1, #column.cards))) or 1
end

function Board:card()
	local column = self.columns[self.col]
	return column and column.cards[self.row], column
end

function Board:save()
	vim.api.nvim_buf_call(self.source, function()
		vim.cmd("silent noautocmd update")
	end)
	require("notes.index").update(vim.api.nvim_buf_get_name(self.source))
	vim.api.nvim_exec_autocmds("User", { pattern = "NotesChanged", data = {} })
end

--- Replace lines first..last (1-based) with `new`, as one undo step with `more`.
function Board:edit(fn)
	vim.api.nvim_buf_call(self.source, fn)
	self:save()
	self:read()
	self:draw()
end

-- Move the current card to position `pos` of column `target`.
function Board:move(target, pos)
	local card = self:card()
	local from, to = self.col, self.columns[target]
	if not card or not to then
		return
	end
	local lines = vim.deepcopy(card.lines)
	-- Entering a **Complete** column ticks the card, leaving one unticks it.
	if target ~= from then
		local done = T.is_done(lines[1]:match("%[(.)%]") or " ")
		if to.complete and not done then
			lines[1] = T.set_status(lines[1], "x")
		elseif self.columns[from].complete and not to.complete and done then
			lines[1] = T.set_status(lines[1], " ")
		end
	end
	self:edit(function()
		local buf = self.source
		-- Position among the other cards, so that moving within a column works.
		local others = vim.tbl_filter(function(c)
			return c ~= card
		end, to.cards)
		local at, empty = slot({ cards = others, last = to.complete and to.last or to.line }, pos)
		if #others == 0 then
			at, empty = to.complete and to.last or to.line, true
			if from == target then
				return
			end
		end
		local insert = lines
		if empty and not to.complete then
			-- Keep the blank line Obsidian puts after a heading.
			local following = vim.api.nvim_buf_get_lines(buf, at, at + 1, false)[1]
			if following and following:match("^%s*$") then
				at = at + 1
			else
				insert = vim.list_extend({ "" }, lines)
			end
		end
		if at >= card.last then -- insert first, so the earlier lines don't shift
			vim.api.nvim_buf_set_lines(buf, at, at, false, insert)
			vim.api.nvim_buf_set_lines(buf, card.first - 1, card.last, false, {})
		else
			vim.api.nvim_buf_set_lines(buf, card.first - 1, card.last, false, {})
			vim.api.nvim_buf_set_lines(buf, at, at, false, insert)
		end
		self.col, self.row = target, pos
	end)
end

local function task_of(card)
	local _, _, status, body = require("notes.index").task_parts(card.lines[1])
	return T.parse(body or "", status or " ")
end

function Board:draw_column(i)
	local column = self.columns[i]
	local pane = self.panes[i - self.first + 1]
	local rows, spots = {}, {}
	local width = WIDTH - 2
	for r, card in ipairs(column.cards) do
		local task = task_of(card)
		local current = i == self.col and r == self.row
		local start = #rows + 1
		local done = T.is_done(task.status)
		local mark = done and { "󰱒 ", "NotesGreen" } or (task.status == "/" and { "󰡖 ", "NotesYellow" } or { "󰄱 ", "NotesMuted" })
		-- Wrap the title by hand: each row is a list of chunks.
		local title = vim.trim((util.plain(task.text):gsub("%s*#[%w_/%-]+", "")))
		local words, line, first_line = vim.split(title, "%s+"), "", true
		local function push(text)
			rows[#rows + 1] = { first_line and mark or "  ", { text, done and "NotesDone" or (current and "NotesTitle" or "NotesText") } }
			first_line = false
		end
		for _, word in ipairs(words) do
			local candidate = line == "" and word or (line .. " " .. word)
			if vim.fn.strdisplaywidth(candidate) > width - 3 and line ~= "" then
				push(line)
				line = word
			else
				line = candidate
			end
		end
		push(line)
		for n = 2, math.min(#card.lines, 4) do
			rows[#rows + 1] = { { "  " .. util.truncate(util.plain(card.lines[n]), width - 3), "NotesMuted" } }
		end
		local meta = { "  " }
		for _, tag in ipairs(task.tags) do
			meta[#meta + 1] = { "#" .. tag, "NotesTag" }
			meta[#meta + 1] = " "
		end
		if task.priority ~= 4 then
			meta[#meta + 1] = { (T.priorities[task.priority] or "") .. " ", T.priority_hl[task.priority] }
		end
		if task.due then
			meta[#meta + 1] = { "󰃭 " .. D.human(task.due), done and "NotesMuted" or T.date_hl(task.due) }
		end
		if card.lines[1]:find("[[", 1, true) then
			meta[#meta + 1] = { " 󰌹", "NotesLink" }
		end
		if #meta > 1 then
			rows[#rows + 1] = meta
		end
		spots[r] = { start, #rows }
		rows[#rows + 1] = { { ("─"):rep(width), "NotesBorder" } }
	end
	if #column.cards == 0 then
		rows[1] = { { "  (empty)", "NotesBorder" } }
	end
	util.render(pane.buf, ns, rows)
	if i == self.col and spots[self.row] then
		for lnum = spots[self.row][1], spots[self.row][2] do
			vim.api.nvim_buf_set_extmark(pane.buf, ns, lnum - 1, 0, { line_hl_group = "NotesActive" })
		end
		-- Scroll so that all of the card is visible.
		vim.api.nvim_win_set_cursor(pane.win, { spots[self.row][2], 0 })
		vim.api.nvim_win_set_cursor(pane.win, { spots[self.row][1], 0 })
	end
	local active = i == self.col
	vim.api.nvim_win_set_config(pane.win, {
		title = { { " " .. column.title .. " ", active and "NotesTitle" or "NotesHeader" }, { #column.cards .. " ", "NotesMuted" }, { column.complete and "󰄲 " or "", "NotesGreen" } },
		title_pos = "center",
	})
	vim.wo[pane.win].winhighlight = "NormalFloat:Normal,FloatBorder:" .. (active and "NotesAccent" or "NotesBorder")
end

function Board:draw()
	if #self.columns == 0 then
		return
	end
	-- As many columns as fit, scrolled so that the current one is visible.
	local room = math.max(1, math.floor((vim.o.columns - 4) / (WIDTH + 2)))
	local shown = math.min(room, #self.columns)
	self.first = math.max(1, math.min(self.first or 1, #self.columns - shown + 1))
	if self.col < self.first then
		self.first = self.col
	elseif self.col > self.first + shown - 1 then
		self.first = self.col - shown + 1
	end
	if #self.panes ~= shown then
		self:close_panes()
		local left = math.max(0, math.floor((vim.o.columns - shown * (WIDTH + 2)) / 2))
		for n = 1, shown do
			local buf = vim.api.nvim_create_buf(false, true)
			vim.bo[buf].bufhidden = "wipe"
			vim.bo[buf].filetype = "noteskanban"
			local win = vim.api.nvim_open_win(buf, false, {
				relative = "editor",
				row = 2,
				col = left + (n - 1) * (WIDTH + 2),
				width = WIDTH,
				height = math.max(5, vim.o.lines - 8),
				style = "minimal",
				title = " ",
			})
			vim.wo[win].wrap, vim.wo[win].cursorline, vim.wo[win].spell = false, false, false
			vim.wo[win].scrolloff = 1
			self.panes[n] = { buf = buf, win = win }
			self:keymaps(buf)
		end
	end
	for n = 1, shown do
		self:draw_column(self.first + n - 1)
	end
	local pane = self.panes[self.col - self.first + 1]
	if vim.api.nvim_get_current_win() ~= pane.win and not self.busy then
		vim.api.nvim_set_current_win(pane.win)
	end
	local more = {}
	if self.first > 1 then
		more[#more + 1] = "← " .. (self.first - 1) .. " more"
	end
	local right = #self.columns - (self.first + shown - 1)
	if right > 0 then
		more[#more + 1] = right .. " more →"
	end
	util.render(self.bar.buf, ns, {
		{ { " " .. self.name .. " ", "NotesTitle" }, { table.concat(more, "  "), "NotesSoon" } },
	})
end

function Board:close_panes()
	for _, pane in ipairs(self.panes) do
		if vim.api.nvim_win_is_valid(pane.win) then
			vim.api.nvim_win_close(pane.win, true)
		end
	end
	self.panes = {}
end

function Board:close()
	self.closing = true
	self:close_panes()
	for _, part in ipairs({ self.bar, self.back, self.help }) do
		if part and vim.api.nvim_win_is_valid(part.win) then
			vim.api.nvim_win_close(part.win, true)
		end
	end
	if self.group then
		pcall(vim.api.nvim_del_augroup_by_id, self.group)
	end
end

function Board:ask(prompt, default, fn)
	self.busy = true
	vim.ui.input({ prompt = prompt, default = default }, function(text)
		self.busy = false
		if text and vim.trim(text) ~= "" then
			fn(vim.trim(text))
		end
		if not self.closing then
			self:draw()
		end
	end)
end

function Board:add(top)
	local column = self.columns[self.col]
	if not column then
		return
	end
	self:ask("New card in " .. column.title, nil, function(text)
		local line = "- [" .. (column.complete and "x" or " ") .. "] " .. T.from_text(text):gsub("^%- %[ %] ", "")
		self:edit(function()
			local pos = top and 1 or #column.cards + 1
			local at, empty = slot(column, pos)
			local new = { line }
			if empty and not column.complete then
				local following = vim.api.nvim_buf_get_lines(self.source, at, at + 1, false)[1]
				if following and following:match("^%s*$") then
					at = at + 1
				else
					new = { "", line }
				end
			end
			vim.api.nvim_buf_set_lines(self.source, at, at, false, new)
			self.row = pos
		end)
	end)
end

function Board:change(fn)
	local card = self:card()
	if not card then
		return
	end
	local new = fn(card)
	if new then
		self:edit(function()
			vim.api.nvim_buf_set_lines(self.source, card.first - 1, card.last, false, new)
		end)
	end
end

--- The note behind a card: the one it links to, or a new one.
function Board:open_note()
	local card = self:card()
	if not card then
		return
	end
	local index = require("notes.index")
	local link = index.parse_links(card.lines[1], 1)[1]
	local path
	if link then
		local entry = index.ensure().resolve(link.target)
		path = entry and entry.path or (vault.folder("inbox") .. "/" .. util.filename(link.target) .. ".md")
	else
		local title = util.filename((util.plain(task_of(card).text):gsub("#[%w_/%-]+", "")))
		path = vault.folder("notes") .. "/" .. title .. ".md"
		self:change(function(c)
			local lines = vim.deepcopy(c.lines)
			local at = lines[1]:find(vim.trim((task_of(c).text:gsub("%s*#[%w_/%-]+", ""))), 1, true)
			if at then
				local text = vim.trim((task_of(c).text:gsub("%s*#[%w_/%-]+", "")))
				lines[1] = lines[1]:sub(1, at - 1) .. "[[" .. title .. (title ~= text and ("|" .. text) or "") .. "]]" .. lines[1]:sub(at + #text)
			end
			return lines
		end)
	end
	self:close()
	vault.create(path, { template = "note" })
end

function Board:keymaps(buf)
	local function map(lhs, fn, desc)
		vim.keymap.set("n", lhs, fn, { buffer = buf, nowait = true, desc = desc })
	end
	local function go(dc, dr)
		return function()
			if dc ~= 0 then
				self.col = math.max(1, math.min(#self.columns, self.col + dc))
			end
			local column = self.columns[self.col]
			self.row = math.max(1, math.min(math.max(1, #column.cards), self.row + dr))
			self:draw()
		end
	end
	for lhs, step in pairs({ h = { -1, 0 }, l = { 1, 0 }, j = { 0, 1 }, k = { 0, -1 }, ["<Left>"] = { -1, 0 }, ["<Right>"] = { 1, 0 }, ["<Down>"] = { 0, 1 }, ["<Up>"] = { 0, -1 } }) do
		map(lhs, go(step[1], step[2]), "Move")
	end
	map("gg", function()
		self.row = 1
		self:draw()
	end, "First card")
	map("G", function()
		self.row = math.max(1, #self.columns[self.col].cards)
		self:draw()
	end, "Last card")
	local function shift(dc, dr)
		return function()
			if dc ~= 0 then
				self:move(self.col + dc, dc ~= 0 and 1 or self.row)
			else
				local n = #self.columns[self.col].cards
				local target = self.row + dr
				if target >= 1 and target <= n then
					self:move(self.col, target)
				end
			end
		end
	end
	for _, keys in ipairs({ { "H", "L", "J", "K" }, { "<M-h>", "<M-l>", "<M-j>", "<M-k>" } }) do
		map(keys[1], shift(-1, 0), "Card left")
		map(keys[2], shift(1, 0), "Card right")
		map(keys[3], shift(0, 1), "Card down")
		map(keys[4], shift(0, -1), "Card up")
	end
	map("a", function()
		self:add(false)
	end, "Add a card")
	map("A", function()
		self:add(true)
	end, "Add a card on top")
	map("e", function()
		local card = self:card()
		if card then
			local head, body = card.lines[1]:match("^([-*+]%s+%[.%]%s+)(.*)$")
			self:ask("Edit card", body, function(text)
				self:change(function(c)
					local lines = vim.deepcopy(c.lines)
					lines[1] = head .. text
					return lines
				end)
			end)
		end
	end, "Edit the card")
	map("x", function()
		self:change(function(card)
			local lines = vim.deepcopy(card.lines)
			local done = T.is_done(lines[1]:match("%[(.)%]"))
			lines[1] = T.set_status(lines[1], done and " " or "x")
			return lines
		end)
	end, "Tick")
	map("@", function()
		local card = self:card()
		if card then
			self.busy = true
			T.ask_date("Date", task_of(card).due, function(date)
				self:change(function(c)
					local lines = vim.deepcopy(c.lines)
					if date and not lines[1]:find("@{", 1, true) and not lines[1]:find("📅", 1, true) then
						lines[1] = lines[1] .. " @{" .. date .. "}"
					else
						lines[1] = T.set_date(lines[1], "due", date)
					end
					return lines
				end)
			end)
			self.busy = false
		end
	end, "Date")
	map("d", function()
		local card = self:card()
		if card and vim.fn.confirm("Delete this card?", "&Yes\n&No", 2) == 1 then
			self:change(function()
				return {}
			end)
		end
	end, "Delete the card")
	map("u", function()
		self:edit(function()
			vim.cmd("silent undo")
		end)
	end, "Undo")
	map("<C-r>", function()
		self:edit(function()
			vim.cmd("silent redo")
		end)
	end, "Redo")
	map("n", function()
		self:ask("New column", nil, function(title)
			self:edit(function()
				local last = self.columns[#self.columns]
				local at = last and last.last or vim.api.nvim_buf_line_count(self.source)
				vim.api.nvim_buf_set_lines(self.source, at, at, false, { "", "", "## " .. title, "" })
				self.col = #self.columns + 1
			end)
		end)
	end, "New column")
	map("<CR>", function()
		self:open_note()
	end, "Open the card's note")
	map("o", function()
		local card, column = self:card()
		local line = card and card.first or (column and column.line)
		local path = vim.api.nvim_buf_get_name(self.source)
		self:close()
		vault.open(path, { line = line })
	end, "Edit as text")
	map("q", function()
		self:close()
	end, "Close")
	map("<Esc>", function()
		self:close()
	end, "Close")
	map("?", function()
		util.float({
			"h j k l    move around         H J K L   move the card",
			"a / A      add below / on top  e         edit",
			"x          tick                @         set a date",
			"d          delete              n         new column",
			"<CR>       open the card's note (creates it)",
			"o          edit the board as text",
			"u / <C-r>  undo / redo         q         close",
		}, { title = "Kanban" })
	end, "Help")
end

--- Open a board (default: the current note).
function M.open(path)
	path = path or vim.api.nvim_buf_get_name(0)
	local source = vim.fn.bufadd(path)
	vim.fn.bufload(source)
	vim.bo[source].buflisted = true
	local columns = M.parse(vim.api.nvim_buf_get_lines(source, 0, -1, false))
	if #columns == 0 then
		return util.notify("No columns here. A board has ## headings with tasks under them.", "warn")
	end
	local board = setmetatable({ source = source, col = 1, row = 1, panes = {}, name = vim.fs.basename(path):gsub("%.md$", "") }, Board)

	local function strip(row, height)
		local buf = vim.api.nvim_create_buf(false, true)
		vim.bo[buf].bufhidden = "wipe"
		local win = vim.api.nvim_open_win(buf, false, { relative = "editor", row = row, col = 0, width = vim.o.columns, height = height, style = "minimal", border = "none", focusable = false, zindex = 30 })
		return { buf = buf, win = win }
	end
	-- Cover what is behind, then a title on top and the keys below.
	board.back = strip(0, vim.o.lines - 1)
	vim.wo[board.back.win].winhighlight = "NormalFloat:Normal"
	board.bar = strip(0, 1)
	board.help = strip(vim.o.lines - 3, 1)
	for _, part in ipairs({ board.bar, board.help }) do
		vim.wo[part.win].winhighlight = "NormalFloat:Normal"
		vim.api.nvim_win_set_config(part.win, { zindex = 40 })
	end
	util.render(board.help.buf, ns, { { { "  hjkl move · HJKL move card · a add · e edit · x tick · @ date · <CR> note · o text · n column · u undo · ? help · q close", "NotesBorder" } } })

	board.group = vim.api.nvim_create_augroup("notes_kanban_board", { clear = true })
	vim.api.nvim_create_autocmd("VimResized", {
		group = board.group,
		callback = function()
			board:close_panes()
			board:draw()
		end,
	})
	board:read()
	board:draw()
	M.board = board
end

function M.create()
	util.input({ prompt = "Board name" }, function(name)
		local path = vault.folder("boards") .. "/" .. util.filename(name) .. ".md"
		if not vim.uv.fs_stat(path) and not require("notes.template").path("board") then
			util.write(path, "---\n\nkanban-plugin: board\n\n---\n\n## Backlog\n\n\n## Doing\n\n\n## Done\n\n**Complete**\n\n")
			require("notes.index").update(path)
		else
			vault.create(path, { template = "board", open = false })
		end
		M.open(path)
	end)
end

return M
