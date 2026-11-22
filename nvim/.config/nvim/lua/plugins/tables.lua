-- Turn pasted plain text into an aligned markdown table.
--
-- <leader>mt  convert the selection (or the paragraph under the cursor)
-- <leader>mT  same, but always ask Claude
-- :[range]Table[!]  command form; ! forces Claude
--
-- Columns are found locally first: the first separator that splits every line
-- into the same number (2+) of columns wins: tabs, pipes, runs of 2+ spaces,
-- then commas (CSV quoting respected). The first row becomes the header.
-- If none fits (single-space separators, ragged rows, PDF text), `claude -p`
-- infers the columns in the background and the result replaces the lines.

local M = {}

local function trim(s)
	return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function split_plain(line, sep)
	local cells, start = {}, 1
	while true do
		local a, b = line:find(sep, start)
		if not a then
			table.insert(cells, trim(line:sub(start)))
			return cells
		end
		table.insert(cells, trim(line:sub(start, a - 1)))
		start = b + 1
	end
end

local function split_csv(line)
	local cells, cell, quoted, n = {}, {}, false, 1
	while n <= #line do
		local c = line:sub(n, n)
		if quoted then
			if c == '"' and line:sub(n + 1, n + 1) == '"' then
				table.insert(cell, '"')
				n = n + 1
			elseif c == '"' then
				quoted = false
			else
				table.insert(cell, c)
			end
		elseif c == '"' then
			quoted = true
		elseif c == "," then
			table.insert(cells, trim(table.concat(cell)))
			cell = {}
		else
			table.insert(cell, c)
		end
		n = n + 1
	end
	table.insert(cells, trim(table.concat(cell)))
	return cells
end

-- Existing markdown/org tables: drop outer pipes and `|---|` rule rows,
-- keep escaped `\|` inside cells.
local function split_pipe(line)
	if line:match("^%s*|?[%s:%-|+]+|?%s*$") and line:find("%-") then
		return nil -- rule row
	end
	line = trim(line):gsub("^|", ""):gsub("|$", ""):gsub("\\|", "\1")
	local cells = split_plain(line, "|")
	for n, c in ipairs(cells) do
		cells[n] = c:gsub("\1", "|")
	end
	return cells
end

local splitters = {
	{ name = "tabs", fn = function(l) return l:find("\t") and split_plain(l, "\t+") or false end },
	{ name = "pipes", fn = function(l) if not l:find("|") then return false end return split_pipe(l) end },
	{ name = "spaces", fn = function(l) return split_plain(l:gsub("\t", "  "), "%s%s+") end },
	{ name = "commas", fn = function(l) return l:find(",") and split_csv(l) or false end },
}

-- Rows of cells, or nil when no separator gives a consistent column count.
function M.parse(lines)
	local content = vim.tbl_filter(function(l) return l:match("%S") end, lines)
	if #content < 2 then
		return nil
	end
	for _, sp in ipairs(splitters) do
		local rows, cols, ok = {}, nil, true
		for _, line in ipairs(content) do
			local cells = sp.fn(trim(line))
			if cells == false or (cells and cols and #cells ~= cols) or (cells and #cells < 2) then
				ok = false
				break
			end
			if cells then -- nil = skipped rule row
				cols = cols or #cells
				table.insert(rows, cells)
			end
		end
		if ok and #rows >= 2 then
			return rows, sp.name
		end
	end
end

function M.render(rows)
	local widths = {}
	for _, row in ipairs(rows) do
		for c, cell in ipairs(row) do
			row[c] = cell:gsub("|", "\\|")
			widths[c] = math.max(widths[c] or 3, vim.fn.strdisplaywidth(row[c]))
		end
	end
	local function line(cells)
		local out = {}
		for c, w in ipairs(widths) do
			local cell = cells[c] or ""
			out[c] = cell .. string.rep(" ", w - vim.fn.strdisplaywidth(cell))
		end
		return "| " .. table.concat(out, " | ") .. " |"
	end
	local rule = {}
	for c, w in ipairs(widths) do
		rule[c] = string.rep("-", w)
	end
	local out = { line(rows[1]), line(rule) }
	for r = 2, #rows do
		table.insert(out, line(rows[r]))
	end
	return out
end

local PROMPT = [[Convert the text on stdin into a GitHub-flavored markdown table.
Work out where each column starts and ends from the meaning when separators are ambiguous.
Use the first row as the header if it reads like one; otherwise write a short header.
Keep every cell's wording exactly as given. Output ONLY the table: no code fences, no commentary.]]

local function ask_claude(buf, first, last, lines)
	if vim.fn.executable("claude") == 0 then
		return vim.notify("Table: no clear columns and `claude` is not on PATH", vim.log.levels.WARN)
	end
	vim.notify("Table: asking Claude to find the columns…")
	vim.system(
		{ "claude", "-p", "--model", "haiku", PROMPT },
		{ stdin = table.concat(lines, "\n") },
		vim.schedule_wrap(function(res)
			if res.code ~= 0 then
				return vim.notify("Table: claude failed: " .. trim(res.stderr or ""), vim.log.levels.ERROR)
			end
			local out = vim.split(trim((res.stdout or ""):gsub("```%w*", "")), "\n")
			local rows = M.parse(out)
			if not rows or not out[1]:match("^%s*|") then
				return vim.notify("Table: Claude's reply wasn't a table:\n" .. res.stdout, vim.log.levels.WARN)
			end
			-- Don't clobber edits made while waiting.
			if not vim.api.nvim_buf_is_valid(buf)
				or not vim.deep_equal(vim.api.nvim_buf_get_lines(buf, first - 1, last, false), lines) then
				return vim.notify("Table: lines changed while waiting; result discarded", vim.log.levels.WARN)
			end
			vim.api.nvim_buf_set_lines(buf, first - 1, last, false, M.render(rows))
		end)
	)
end

function M.convert(first, last, force_claude)
	local buf = vim.api.nvim_get_current_buf()
	local lines = vim.api.nvim_buf_get_lines(buf, first - 1, last, false)
	local rows = not force_claude and M.parse(lines)
	if rows then
		vim.api.nvim_buf_set_lines(buf, first - 1, last, false, M.render(rows))
	else
		ask_claude(buf, first, last, lines)
	end
end

vim.api.nvim_create_user_command("Table", function(o)
	M.convert(o.line1, o.line2, o.bang)
end, { range = "%", bang = true, desc = "Convert lines to a markdown table (! = ask Claude)" })

local function paragraph_or_selection(force)
	return function()
		local first, last
		if vim.fn.mode():match("[vV\22]") then
			first, last = vim.fn.line("v"), vim.fn.line(".")
			vim.cmd("normal! \27")
		else
			first, last = vim.fn.line("'{"), vim.fn.line("'}")
			if not vim.fn.getline(first):match("%S") then first = first + 1 end
			if not vim.fn.getline(last):match("%S") then last = last - 1 end
		end
		if first > last then first, last = last, first end
		M.convert(first, last, force)
	end
end

vim.keymap.set({ "n", "x" }, "<leader>mt", paragraph_or_selection(false), { desc = "Make table" })
vim.keymap.set({ "n", "x" }, "<leader>mT", paragraph_or_selection(true), { desc = "Make table (Claude)" })

return M
