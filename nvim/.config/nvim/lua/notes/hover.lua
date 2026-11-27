-- K on a link: the note it points to, in a float (Obsidian's page preview). K again
-- goes into it. Anywhere else K shows diagnostics, and in a code block the
-- language server's hover.

local util = require("notes.util")
local index = require("notes.index")
local vault = require("notes.vault")

local M = {}

local open ---@type integer?

--- The link under the cursor.
function M.link_at_cursor()
	local pos = vim.api.nvim_win_get_cursor(0)
	for _, link in ipairs(index.parse_links(vim.api.nvim_get_current_line(), pos[1])) do
		if pos[2] + 1 >= link.col and pos[2] + 1 <= link.stop then
			return link
		end
	end
end

--- Lines of the part of a note that an anchor points to.
function M.section(entry, anchor)
	local lines = util.lines(util.read(entry.path) or "")
	if not anchor or anchor == "" then
		return vim.list_slice(lines, entry.body), entry.body
	end
	local block = anchor:match("^%^(.+)$")
	if block then
		local at = entry.blocks[block]
		if not at then
			return { "Block not found: ^" .. block }, 1
		end
		local first, last = at, at
		if not lines[at]:match("^%s*[-*+]%s") then
			while first > entry.body and lines[first - 1]:match("%S") and not lines[first - 1]:match("^%s*[-*+]%s") and not lines[first - 1]:match("^#+%s") do
				first = first - 1
			end
		end
		while lines[last + 1] and lines[last + 1]:match("^%s+%S") do
			last = last + 1
		end
		return vim.list_slice(lines, first, last), first
	end
	local function normal(text)
		return (util.plain(text):lower():gsub("[^%w\128-\255]+", " "):gsub("^%s+", ""):gsub("%s+$", ""))
	end
	local wanted = normal(anchor:match("([^#]+)$") or anchor)
	for i, h in ipairs(entry.headings) do
		if normal(h.text) == wanted then
			local last = #lines
			for j = i + 1, #entry.headings do
				if entry.headings[j].level <= h.level then
					last = entry.headings[j].line - 1
					break
				end
			end
			return vim.list_slice(lines, h.line, last), h.line
		end
	end
	return { "Heading not found: " .. anchor }, 1
end

local function show(lines, title, path, line)
	while lines[#lines] and lines[#lines]:match("^%s*$") do
		lines[#lines] = nil
	end
	while lines[1] and lines[1]:match("^%s*$") do
		table.remove(lines, 1)
	end
	if #lines == 0 then
		lines = { "*(empty note)*" }
	end
	local width = 72
	local height = 0
	for _, text in ipairs(lines) do
		height = height + math.max(1, math.ceil(vim.fn.strdisplaywidth(text) / width))
	end
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].modifiable = false
	local win = vim.api.nvim_open_win(buf, false, {
		relative = "cursor",
		row = 1,
		col = 0,
		width = math.min(width, vim.o.columns - 4),
		height = math.min(height + 1, 22, vim.o.lines - 6),
		title = { { " " .. title .. " ", "NotesTitle" } },
		footer = { { " K again to go inside ", "NotesMuted" } },
		footer_pos = "right",
		style = "minimal",
	})
	vim.bo[buf].filetype = "markdown"
	vim.wo[win].wrap, vim.wo[win].linebreak, vim.wo[win].conceallevel, vim.wo[win].spell = true, true, 2, false
	vim.wo[win].foldenable = false
	open = win
	local source = vim.api.nvim_get_current_buf()
	local group = vim.api.nvim_create_augroup("notes_hover", { clear = true })
	vim.api.nvim_create_autocmd({ "CursorMoved", "InsertEnter", "BufLeave" }, {
		group = group,
		buffer = source,
		callback = function()
			if vim.api.nvim_get_current_win() ~= win then
				M.close()
			end
		end,
	})
	local function go()
		M.close()
		if path then
			vault.open(path, { line = line })
		end
	end
	for lhs, fn in pairs({ q = M.close, ["<Esc>"] = M.close, ["<CR>"] = go }) do
		vim.keymap.set("n", lhs, fn, { buffer = buf, nowait = true })
	end
end

function M.close()
	if open and vim.api.nvim_win_is_valid(open) then
		vim.api.nvim_win_close(open, true)
	end
	open = nil
	pcall(vim.api.nvim_del_augroup_by_name, "notes_hover")
end

--- Is the cursor inside a fenced code block?
function M.in_code_block()
	local ok, node = pcall(vim.treesitter.get_node)
	while ok and node do
		if node:type() == "fenced_code_block" then
			return true
		end
		node = node:parent()
	end
	return false
end

function M.hover()
	if open and vim.api.nvim_win_is_valid(open) then
		vim.api.nvim_clear_autocmds({ group = "notes_hover" })
		vim.api.nvim_set_current_win(open)
		return
	end
	local link = M.link_at_cursor()
	if link then
		local from = index.get(vim.api.nvim_buf_get_name(0))
		local entry = index.resolve(link.target, from)
		if entry then
			local lines, first = M.section(entry, link.anchor)
			return show(vim.deepcopy(lines), entry.name .. (link.anchor and (" › " .. link.anchor) or ""), entry.path, first)
		end
		local file = index.resolve_file(link.target, from)
		if file and Snacks.image and file:lower():match("%.%a+$") and Snacks.image.supports_file(vault.abs(file)) then
			return Snacks.image.hover()
		end
		return show({ file and ("Attachment: " .. file) or "This note doesn't exist yet. `<CR>` creates it." }, link.target)
	end
	-- Footnotes
	local line, col = vim.api.nvim_get_current_line(), vim.api.nvim_win_get_cursor(0)[2] + 1
	for s, name, e in line:gmatch("()%[%^([^%]]+)%]()") do
		if col >= s and col < e then
			for lnum, text in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
				local body = text:match("^%[%^" .. vim.pesc(name) .. "%]:%s*(.*)$")
				if body then
					return show({ body }, "Footnote " .. name, vim.api.nvim_buf_get_name(0), lnum)
				end
			end
		end
	end
	if #vim.diagnostic.get(0, { lnum = vim.api.nvim_win_get_cursor(0)[1] - 1 }) > 0 then
		return vim.diagnostic.open_float({ scope = "cursor" })
	end
	if vim.bo.filetype ~= "markdown" or M.in_code_block() then
		return vim.lsp.buf.hover() -- code blocks have their language's server (otter)
	end
	util.notify("Nothing to preview here")
end

return M
