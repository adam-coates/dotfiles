-- Word documents with tracked changes and comments, reviewed in Neovim.
--
-- Opening a .docx shows it as markdown, read-only, with the changes marked
-- the way pandiff marks them: {++inserted++} {--deleted--} {==commented==}
-- {>>author: comment<<}.
--
-- :DocxReview lists every tracked change and comment in a picker, located in
-- the markdown/quarto source the document was rendered from, so the edits go
-- straight into the source instead of round-tripping through Word:
--   <CR>    jump to it in the source
--   <a-a>   accept: make the change in the source (a comment: mark it done)
--   <a-x>   dismiss: reject the change, or mark the comment done
--   <a-y>   yank the new text (for changes that couldn't be located)
--   <c-a>   select all, so <a-a> accepts everything at once
-- Pending items also show as diagnostics in the source. Accepting is plain
-- buffer editing: undo with u, and nothing is saved until you :w.
--
-- From a .docx buffer it asks which source file to use (guessing by name);
-- from a .md/.qmd buffer it asks which .docx (or takes :DocxReview file.docx).
--
-- Locating: the docx text is the rendered document, so each change is found
-- by the text around it, after stripping markdown syntax from the source.
-- Citations, cross-references and code output differ between the two, so
-- changes right next to them may only match on one side, or not at all;
-- those are listed as "not found" and can be yanked and placed by hand.

local M = {}

local ns = vim.api.nvim_create_namespace("docx_review")

local function notify(msg, level)
	vim.notify(msg, level or vim.log.levels.INFO, { title = "Word review" })
end

local SUBS = {
	["“"] = '"',
	["”"] = '"',
	["„"] = '"',
	["‘"] = "'",
	["’"] = "'",
	["—"] = "-",
	["–"] = "-",
	["…"] = "...",
	["\194\160"] = " ", -- no-break space
}

-- Text in the form both sides are compared in: straight quotes, plain
-- hyphens, single spaces.
local function norm(s)
	-- (UTF-8: one gsub per character, as a [set] would match single bytes)
	for from, to in pairs(SUBS) do
		s = s:gsub(from, to)
	end
	return (s:gsub("%s+", " "))
end

---------------------------------------------------------------------------
-- Reading the docx
---------------------------------------------------------------------------

local function pandoc(args, input)
	if vim.fn.executable("pandoc") == 0 then
		return nil, "pandoc isn't installed"
	end
	local res = vim.system(vim.list_extend({ "pandoc" }, args), { stdin = input, text = true }):wait()
	if res.code ~= 0 then
		return nil, vim.trim(res.stderr or "pandoc failed")
	end
	return res.stdout
end

local function attrs(attr)
	local kv = {}
	for _, pair in ipairs(attr[3]) do
		kv[pair[1]] = pair[2]
	end
	return attr[2], kv
end

-- Plain text of inlines (for comment bodies).
local function plain(list)
	local out = {}
	local function walk(l)
		for _, el in ipairs(l) do
			local t, c = el.t, el.c
			if t == "Str" or t == "Code" or t == "Math" then
				out[#out + 1] = type(c) == "table" and c[2] or c
			elseif t == "Space" or t == "SoftBreak" or t == "LineBreak" then
				out[#out + 1] = " "
			elseif t == "Quoted" then
				walk(c[2])
			elseif t == "Span" or t == "Link" or t == "Cite" then
				walk(c[2])
			elseif type(c) == "table" and t ~= "Note" and t ~= "Image" and t ~= "RawInline" then
				walk(c)
			end
		end
	end
	walk(list)
	return vim.trim(norm(table.concat(out)))
end

-- A paragraph as pieces of text, each marked inserted, deleted or neither,
-- with comment start/end markers between them.
local function pieces(list)
	local out = {}
	local function emit(text, st)
		out[#out + 1] = { text = norm(text), kind = st.kind, author = st.author, date = st.date }
	end
	local function walk(l, st)
		for _, el in ipairs(l) do
			local t, c = el.t, el.c
			if t == "Str" then
				emit(c, st)
			elseif t == "Space" or t == "SoftBreak" or t == "LineBreak" then
				emit(" ", st)
			elseif t == "Code" or t == "Math" then
				emit(c[2], st)
			elseif t == "Quoted" then
				local q = c[1].t == "DoubleQuote" and '"' or "'"
				emit(q, st)
				walk(c[2], st)
				emit(q, st)
			elseif t == "Span" then
				local classes, kv = attrs(c[1])
				local class = classes[1]
				if class == "insertion" or class == "deletion" then
					walk(c[2], { kind = class == "insertion" and "ins" or "del", author = kv.author, date = kv.date })
				elseif class == "comment-start" then
					out[#out + 1] = {
						comment = "start",
						id = kv.id,
						author = kv.author,
						date = kv.date,
						body = plain(c[2]),
					}
				elseif class == "comment-end" then
					out[#out + 1] = { comment = "end", id = kv.id }
				elseif class ~= "paragraph-insertion" and class ~= "paragraph-deletion" then
					walk(c[2], st)
				end
			elseif t == "Cite" or t == "Link" then
				walk(c[2], st)
			elseif t == "Emph" or t == "Strong" or t == "Underline" or t == "Strikeout" then
				walk(c, st)
			elseif t == "Superscript" or t == "Subscript" or t == "SmallCaps" then
				walk(c, st)
			end
		end
	end
	walk(list, {})
	return out
end

-- Changes and comments in one paragraph, positioned in its original
-- (pre-change) text.
local function paragraph(list, para, changes, comments, open)
	local old, new = {}, {}
	local old_len, new_len = 0, 0
	local function add(buf, text)
		local tail = buf[#buf]
		if text:sub(1, 1) == " " and (not tail or tail:sub(-1) == " ") then
			text = text:sub(2)
		end
		if text ~= "" then
			buf[#buf + 1] = text
		end
		return #text
	end
	local group
	local function close_group()
		if group then
			group.e, group.ne = old_len, new_len
			changes[#changes + 1] = group
			group = nil
		end
	end
	for _, p in ipairs(pieces(list)) do
		if p.comment == "start" then
			open[p.id] = { kind = "comment", author = p.author, date = p.date, body = p.body, para = para, s = old_len }
		elseif p.comment == "end" then
			local c = open[p.id]
			if c then
				c.e = c.para == para and old_len or nil
				comments[#comments + 1] = c
				open[p.id] = nil
			end
		elseif p.kind then
			if not group then
				group = { kind = "change", author = p.author, date = p.date, para = para, s = old_len, ns = new_len, ins = {}, del = {} }
			end
			if p.kind == "del" then
				group.del[#group.del + 1] = p.text
				old_len = old_len + add(old, p.text)
			else
				group.ins[#group.ins + 1] = p.text
				new_len = new_len + add(new, p.text)
			end
		elseif p.text ~= "" then
			close_group()
			old_len = old_len + add(old, p.text)
			new_len = new_len + add(new, p.text)
		end
	end
	close_group()
	return table.concat(old), table.concat(new)
end

-- All changes and comments in a docx, with the paragraph text around each.
function M.read(path)
	local json, err = pandoc({ "--track-changes=all", "-f", "docx", "-t", "json", path })
	if not json then
		return nil, err
	end
	local doc = vim.json.decode(json)
	local paras, changes, comments, open = {}, {}, {}, {}
	local function walk(node)
		if type(node) ~= "table" then
			return
		end
		local inl = (node.t == "Para" or node.t == "Plain") and node.c or (node.t == "Header" and node.c[3])
		if inl then
			local old, new = paragraph(inl, #paras + 1, changes, comments, open)
			paras[#paras + 1] = { old = old, new = new }
			return
		end
		for _, v in pairs(node) do
			walk(v)
		end
	end
	walk(doc.blocks)
	for _, c in pairs(open) do -- comments whose end never came
		comments[#comments + 1] = c
	end

	local items = {}
	for _, ch in ipairs(changes) do
		local p = paras[ch.para]
		if p.old == "" then
			-- A paragraph that's all new goes after the last one that was there
			-- before; a run of them becomes one item, so they keep their order.
			local prev = ch.para - 1
			while prev > 0 and paras[prev].old == "" do
				prev = prev - 1
			end
			local last = items[#items]
			local text = table.concat(ch.ins)
			if last and last.newpara and last.anchor == prev then
				last.new = last.new .. "\n\n" .. text
				goto continue
			end
			ch.old, ch.new, ch.op, ch.newpara, ch.anchor = "", "\n\n" .. text, "insert", true, prev
			ch.before, ch.after = prev > 0 and paras[prev].old or "", ""
			ch.s = prev > 0 and #paras[prev].old or 0
			items[#items + 1] = ch
			goto continue
		end
		ch.old = p.old:sub(ch.s + 1, ch.e)
		ch.new = vim.trim(table.concat(ch.ins))
		ch.before, ch.after = p.old:sub(1, ch.s), p.old:sub(ch.e + 1)
		-- Whether the finished text has a space on each side of the change, so
		-- accepting it can fix the spacing whatever the source's line breaks.
		local added = p.new:sub(ch.ns + 1, ch.ne)
		ch.wantL = p.new:sub(ch.ns, ch.ns) == " " or added:sub(1, 1) == " "
		ch.wantR = p.new:sub(ch.ne + 1, ch.ne + 1) == " " or (added ~= "" and added:sub(-1) == " ")
		-- At the end of a paragraph the source has no space to match after.
		if ch.after == "" then
			ch.before = ch.before:gsub(" $", "")
		end
		ch.op = ch.old == "" and "insert" or (ch.new == "" and "delete" or "replace")
		items[#items + 1] = ch
		::continue::
	end
	for _, c in ipairs(comments) do
		local p = paras[c.para]
		c.e = c.e or #p.old
		c.old = p.old:sub(c.s + 1, c.e)
		c.before, c.after = p.old:sub(1, c.s), p.old:sub(c.e + 1)
		items[#items + 1] = c
	end
	for i, item in ipairs(items) do
		item.order = i -- document order, for edits at the same spot
	end
	table.sort(items, function(a, b)
		if a.para ~= b.para then
			return a.para < b.para
		end
		if a.s ~= b.s then
			return a.s < b.s
		end
		return a.order < b.order
	end)
	return items
end

---------------------------------------------------------------------------
-- The source, as text that can be compared with the docx
---------------------------------------------------------------------------

-- The source's prose with markdown syntax stripped, and for each byte of it
-- the source range it came from: pos[i] = { row, start_col, end_col }.
local function index(lines)
	local text, pos = {}, {}
	local function put(s, row, sc, ec)
		for i = 1, #s do
			text[#text + 1] = s:sub(i, i)
			pos[#pos + 1] = { row, sc, ec }
		end
	end
	local function space(row, col)
		local tail = text[#text]
		if tail and tail ~= " " and tail ~= "\n" then
			put(" ", row, col, col)
		end
	end
	local function newpara(row, col)
		if text[#text] == " " then
			text[#text] = "\n"
		elseif text[#text] and text[#text] ~= "\n" then
			put("\n", row, col, col)
		end
	end

	local i, fence = 1, nil
	if lines[1] == "---" then
		for j = 2, #lines do
			if lines[j] == "---" or lines[j] == "..." then
				i = j + 1
				break
			end
		end
	end
	for li = i, #lines do
		local row, line = li - 1, lines[li]
		local f = line:match("^%s*([`~][`~][`~]+)")
		if fence then
			if f and f:sub(1, 1) == fence:sub(1, 1) and #f >= #fence then
				fence = nil
			end
		elseif f then
			fence = f
			newpara(row, 0)
		elseif line:match("^%s*$") or line:match("^%s*:::") or line:match("^%s*<!%-%-.*%-%->%s*$") then
			newpara(row, 0)
		else
			local col = 1
			-- Block markers: headings, quotes, list items start a paragraph.
			local marker = line:match("^%s*#+%s+()")
				or line:match("^%s*[-*+]%s+()")
				or line:match("^%s*%d+[.)]%s+()")
				or line:match("^%s*>[%s>]*()")
			if marker then
				newpara(row, 0)
				col = marker
			end
			local heading = line:match("^%s*#")
			local n = #line
			if heading then -- ## Title {#id .class}
				n = (line:match("^(.-)%s+{[^{}]*}%s*$") or line):len()
			end
			while col <= n do
				local ch = line:sub(col, col)
				local two, three = line:sub(col, col + 1), line:sub(col, col + 2)
				local skip = nil
				if ch == "\\" and col < n then
					put(line:sub(col + 1, col + 1), row, col - 1, col + 1)
					skip = col + 2
				elseif two == "![" then -- image: dropped, as in the docx text
					local e = line:find("%b()", col) and select(2, line:find("^!%b[]%b()", col))
					skip = e and e + 1 or col + 2
				elseif two == "[@" or two == "[^" or (two == "[-" and line:sub(col + 2, col + 2) == "@") then
					local e = select(2, line:find("^%b[]", col))
					skip = e and e + 1 or col + 1
				elseif ch == "@" and (col == 1 or line:sub(col - 1, col - 1):match("[%s%(%[]")) then
					local e = select(2, line:find("^@[%w_:.#$%%&+?<>~/-]+", col))
					skip = e and (line:sub(e, e):match("[.:]") and e or e + 1) or col + 1
				elseif ch == "]" and line:sub(col + 1, col + 1) == "(" then
					local e = select(2, line:find("^%b()", col + 1))
					skip = e and e + 1 or col + 1
				elseif ch == "]" and line:sub(col + 1, col + 1) == "{" then
					local e = select(2, line:find("^%b{}", col + 1))
					skip = e and e + 1 or col + 1
				elseif three == "---" then
					put("-", row, col - 1, col + 2)
					skip = col + 3
				elseif two == "--" then
					put("-", row, col - 1, col + 1)
					skip = col + 2
				elseif two == "<!" and line:sub(col, col + 3) == "<!--" then
					local e = select(2, line:find("-->", col, true))
					skip = e and e + 1 or n + 1
				elseif ch:match("[%[%]*`$|]") or two == "~~" then
					skip = col + (two == "~~" and 2 or 1)
				elseif ch == "_" and not (line:sub(col - 1, col - 1):match("%w") and line:sub(col + 1, col + 1):match("%w")) then
					skip = col + 1
				elseif ch:match("%s") then
					space(row, col - 1)
					skip = col + 1
				end
				if skip then
					col = skip
				else
					-- A whole UTF-8 character.
					local len = ch:byte() >= 0xF0 and 4 or ch:byte() >= 0xE0 and 3 or ch:byte() >= 0xC0 and 2 or 1
					local c = norm(line:sub(col, col + len - 1))
					put(c, row, col - 1, col - 1 + len)
					col = col + len
				end
			end
			space(row, #line)
			if heading then
				newpara(row, #line)
			end
		end
	end
	return { text = table.concat(text), pos = pos }
end

-- The one place `needle` occurs in the source text, or nil.
local function unique(text, needle)
	if #needle < 12 then
		return nil
	end
	local s = text:find(needle, 1, true)
	if s and not text:find(needle, s + 1, true) then
		return s
	end
end

-- Where an item's original text sits in the source: { row, col, end_row,
-- end_col } (0-based, end exclusive), or nil.
local function locate(idx, item)
	local text, before, old, after = idx.text, item.before, item.old, item.after
	local s
	for _, n in ipairs({ 60, 30, 15 }) do
		local b, a = before:sub(-n), after:sub(1, n)
		-- The docx may have a space where the source has none (before a full
		-- stop, say, with the deleted text gone), so try without them too.
		local bt, at = b:gsub(" $", ""), a:gsub("^ ", "")
		for _, ctx in ipairs({ { b, a }, { bt, at }, { b, "" }, { bt, "" }, { "", a }, { "", at } }) do
			if #(ctx[1] .. ctx[2]) >= 8 then
				local hit = unique(text, ctx[1] .. old .. ctx[2])
				if hit then
					s = hit + #ctx[1]
					break
				end
			end
		end
		if s then
			break
		end
	end
	if not s and #old >= 12 then
		s = unique(text, old)
	end
	if not s then
		return nil
	end
	local pos = idx.pos
	if old == "" then
		-- An insertion point: just after the text before it (or just before
		-- the text after it, at the start of a paragraph).
		-- After a space (which may be a line break in the source), insert at
		-- the start of the next word rather than the end of the previous line.
		local p, col
		if pos[s] and (s == 1 or text:sub(s - 1, s - 1):match("[ \n]")) and text:sub(s, s) ~= "\n" then
			p = pos[s]
			col = p[2]
		else
			p = pos[s - 1] or pos[s]
			col = pos[s - 1] and p[3] or p[2]
		end
		return { p[1], col, p[1], col }
	end
	local e = s + #old - 1
	-- Spaces at either end are left to apply() to sort out.
	while e > s and text:sub(e, e) == " " do
		e = e - 1
	end
	while s < e and text:sub(s, s) == " " do
		s = s + 1
	end
	return { pos[s][1], pos[s][2], pos[e][1], pos[e][3] }
end

---------------------------------------------------------------------------
-- Review
---------------------------------------------------------------------------

local function summary(item)
	local function cut(s, n)
		s = vim.trim(s)
		return #s > n and s:sub(1, n) .. "…" or s
	end
	if item.kind == "comment" then
		return item.body
	elseif item.op == "insert" then
		return "+ " .. cut(item.new, 60)
	elseif item.op == "delete" then
		return "- " .. cut(item.old, 60)
	end
	return cut(item.old, 30) .. " → " .. cut(item.new, 30)
end

local function diagnostics(review)
	if not vim.api.nvim_buf_is_valid(review.buf) then
		return
	end
	local list = {}
	for _, item in ipairs(review.items) do
		if not item.done and item.loc then
			list[#list + 1] = {
				lnum = item.loc[1],
				col = item.loc[2],
				end_lnum = item.loc[3],
				end_col = item.loc[4],
				severity = item.kind == "comment" and vim.diagnostic.severity.INFO or vim.diagnostic.severity.HINT,
				source = item.author or "Word",
				message = summary(item),
			}
		end
	end
	vim.diagnostic.set(ns, review.buf, list)
end

-- Locate every pending item in the source as it is now.
local function relocate(review)
	local idx = index(vim.api.nvim_buf_get_lines(review.buf, 0, -1, false))
	for _, item in ipairs(review.items) do
		item.loc = not item.done and locate(idx, item) or nil
	end
	diagnostics(review)
end

local function isspace(ch)
	return ch == " " or ch == "\t"
end

-- Replace an item's text in the source, with spaces either side as in the
-- finished docx text.
local function apply(buf, item)
	local r1, c1, r2, c2 = unpack(item.loc)
	if item.newpara then
		return vim.api.nvim_buf_set_text(buf, r1, c1, r1, c1, vim.split(item.new, "\n"))
	end
	local line1 = vim.api.nvim_buf_get_lines(buf, r1, r1 + 1, true)[1]
	local line2 = vim.api.nvim_buf_get_lines(buf, r2, r2 + 1, true)[1]
	local L = c1 > 0 and line1:sub(c1, c1) or "\n"
	local R = c2 < #line2 and line2:sub(c2 + 1, c2 + 1) or "\n"
	local function ws(ch)
		return isspace(ch) or ch == "\n"
	end
	local text = item.new
	if text == "" then
		if item.wantL or item.wantR then
			if L:match("[%(%[]") and isspace(R) then -- "( x" -> "(x"
				while c2 < #line2 and isspace(line2:sub(c2 + 1, c2 + 1)) do
					c2 = c2 + 1
				end
			elseif R:match("[,.;:!?%)%]]") and isspace(L) then -- "x ." -> "x."
				while c1 > 0 and isspace(line1:sub(c1, c1)) do
					c1 = c1 - 1
				end
			elseif isspace(L) and isspace(R) then
				c2 = c2 + 1 -- two spaces would be left: keep one
			elseif not ws(L) and not ws(R) then
				text = " "
			end
		elseif isspace(L) then -- no space wanted: drop the one before
			while c1 > 0 and isspace(line1:sub(c1, c1)) do
				c1 = c1 - 1
			end
		elseif isspace(R) and r1 == r2 then
			while c2 < #line2 and isspace(line2:sub(c2 + 1, c2 + 1)) do
				c2 = c2 + 1
			end
		end
	else
		local closing = text:match("^[,.;:!?)%]]")
		if item.wantL and not ws(L) and not closing and not L:match("[%(%[]") then
			text = " " .. text
		elseif isspace(L) and closing then
			while c1 > 0 and isspace(line1:sub(c1, c1)) do
				c1 = c1 - 1
			end
		end
		if item.wantR and not ws(R) and not R:match("[,.;:!?%)%]]") and not text:match("[%(%[]$") then
			text = text .. " "
		end
	end
	vim.api.nvim_buf_set_text(buf, r1, c1, r2, c2, vim.split(text, "\n"))
end

-- Make the changes in the source, last first so earlier positions hold.
-- Returns how many couldn't be located.
local function accept(review, list)
	relocate(review)
	local edits, missed = {}, 0
	for _, item in ipairs(list) do
		if item.kind == "comment" then
			item.done = true
		elseif item.loc then
			edits[#edits + 1] = item
		else
			missed = missed + 1
		end
	end
	-- Last first; at the same spot, a deletion before an insertion (so it
	-- doesn't remove the inserted text) and later insertions before earlier
	-- ones (so they end up in document order).
	table.sort(edits, function(a, b)
		local x, y = a.loc, b.loc
		if x[1] ~= y[1] or x[2] ~= y[2] then
			return x[1] > y[1] or (x[1] == y[1] and x[2] > y[2])
		end
		if x[3] ~= y[3] or x[4] ~= y[4] then
			return x[3] > y[3] or (x[3] == y[3] and x[4] > y[4])
		end
		return a.order > b.order
	end)
	for _, item in ipairs(edits) do
		local ok, err = pcall(apply, review.buf, item)
		if ok then
			item.done = true
		else
			missed = missed + 1
			notify(err, vim.log.levels.ERROR)
		end
	end
	relocate(review)
	return missed
end

local function jump(review, item)
	local win = vim.fn.bufwinid(review.buf)
	if win == -1 then
		vim.cmd("buffer " .. review.buf)
		win = vim.api.nvim_get_current_win()
	end
	vim.api.nvim_set_current_win(win)
	if item.loc then
		vim.api.nvim_win_set_cursor(win, { item.loc[1] + 1, item.loc[2] })
		vim.cmd("normal! zz")
	end
end

local function critic(item)
	local before = item.before:sub(-200):gsub("^%S*%s", "")
	local after = item.after:sub(1, 200):gsub("%s%S*$", "")
	if item.kind == "comment" then
		return before .. "{==" .. item.old .. "==}" .. after
	end
	local mid = (item.old ~= "" and "{--" .. item.old .. "--}" or "") .. (item.new ~= "" and "{++" .. item.new .. "++}" or "")
	return before .. mid .. after
end

local function mark_critic(buf, lines)
	for row, line in ipairs(lines) do
		for _, spec in ipairs({
			{ "{%+%+.-%+%+}", "DiffAdd" },
			{ "{%-%-.-%-%-}", "DiffDelete" },
			{ "{==.-==}", "DiffText" },
			{ "{>>.-<<}", "DiagnosticInfo" },
		}) do
			local init = 1
			while true do
				local s, e = line:find(spec[1], init)
				if not s then
					break
				end
				vim.api.nvim_buf_set_extmark(buf, ns, row - 1, s - 1, { end_col = e, hl_group = spec[2], priority = 300 })
				for _, m in ipairs({ { s, s + 2 }, { e - 2, e } }) do
					vim.api.nvim_buf_set_extmark(buf, ns, row - 1, m[1] - 1, { end_col = m[2], conceal = "" })
				end
				init = e + 1
			end
		end
	end
end

local function preview(review, ctx, item)
	local who = (item.author or "Unknown") .. (item.date and ("  " .. item.date:sub(1, 10)) or "")
	local lines = { who, "" }
	if item.kind == "comment" then
		vim.list_extend(lines, vim.split(item.body, "\n"))
		lines[#lines + 1] = ""
	end
	lines[#lines + 1] = critic(item)
	lines[#lines + 1] = ""
	local srcname = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(review.buf), ":t")
	if item.loc then
		lines[#lines + 1] = ("── %s:%d ──"):format(srcname, item.loc[1] + 1)
		local from = math.max(0, item.loc[1] - 2)
		vim.list_extend(lines, vim.api.nvim_buf_get_lines(review.buf, from, item.loc[3] + 3, false))
	else
		lines[#lines + 1] = ("── not found in %s: <a-y> yanks the new text ──"):format(srcname)
	end
	ctx.preview:reset()
	ctx.preview:set_lines(lines)
	ctx.preview:highlight({ ft = "markdown" })
	ctx.preview:wo({ wrap = true, linebreak = true, conceallevel = 2 })
	local buf = ctx.buf
	vim.api.nvim_buf_set_extmark(buf, ns, 0, 0, { end_col = #lines[1], hl_group = "Title" })
	mark_critic(buf, lines)
	if item.loc then
		local header = #lines - (math.min(item.loc[3] + 3, vim.api.nvim_buf_line_count(review.buf)) - math.max(0, item.loc[1] - 2))
		local off = header - math.max(0, item.loc[1] - 2)
		vim.api.nvim_buf_set_extmark(buf, ns, header - 1, 0, { end_row = header, hl_group = "Comment", hl_eol = true })
		pcall(vim.api.nvim_buf_set_extmark, buf, ns, item.loc[1] + off, item.loc[2], {
			end_row = item.loc[3] + off,
			end_col = math.max(item.loc[4], item.loc[2] + 1),
			hl_group = item.kind == "comment" and "DiffText" or "DiffDelete",
			strict = false,
		})
	end
end

function M.review(docx, src_buf)
	local items, err = M.read(docx)
	if not items then
		return notify(err, vim.log.levels.ERROR)
	end
	if #items == 0 then
		return notify(vim.fn.fnamemodify(docx, ":t") .. " has no tracked changes or comments.")
	end
	local review = { buf = src_buf, items = items, docx = docx }
	relocate(review)

	local function of(entry)
		return review.items[entry.ref]
	end

	-- Redraw the list after accepting or dismissing; close when nothing's left.
	local function update(picker)
		diagnostics(review)
		if vim.iter(review.items):all(function(i)
			return i.done
		end) then
			picker:close()
		else
			picker:refresh()
		end
	end

	Snacks.picker.pick({
		title = "Word review: " .. vim.fn.fnamemodify(docx, ":t"),
		finder = function()
			local list = {}
			for i, item in ipairs(review.items) do
				if not item.done then
					list[#list + 1] = {
						ref = i, -- not the item itself: Snacks copies selected entries
						text = table.concat({ item.author or "", item.body or "", item.old, item.new or "" }, " "),
					}
				end
			end
			return list
		end,
		format = function(entry)
			local item = of(entry)
			local icon, hl = "󰏫 ", "DiagnosticHint"
			if item.kind == "comment" then
				icon, hl = "󰆉 ", "DiagnosticInfo"
			elseif item.op == "insert" then
				icon, hl = " ", "DiffAdd"
			elseif item.op == "delete" then
				icon, hl = " ", "DiffDelete"
			end
			return {
				{ icon, hl },
				{ ("%-4s "):format(item.loc and tostring(item.loc[1] + 1) or "?"), item.loc and "LineNr" or "WarningMsg" },
				{ summary(item) .. "  " },
				{ item.author or "", "Comment" },
			}
		end,
		preview = function(ctx)
			preview(review, ctx, of(ctx.item))
		end,
		confirm = function(picker, entry)
			picker:close()
			if entry then
				vim.schedule(function()
					jump(review, of(entry))
				end)
			end
		end,
		actions = {
			docx_accept = function(picker)
				local list = vim.tbl_map(function(entry)
					return of(entry)
				end, picker:selected({ fallback = true }))
				local missed = accept(review, list)
				update(picker)
				if missed > 0 then
					notify(("%d change%s couldn't be located in the source."):format(missed, missed == 1 and "" or "s"), vim.log.levels.WARN)
				end
			end,
			docx_dismiss = function(picker)
				for _, entry in ipairs(picker:selected({ fallback = true })) do
					of(entry).done = true
				end
				update(picker)
			end,
			docx_yank = function(_, entry)
				if entry then
					local text = of(entry).new or of(entry).body or ""
					vim.fn.setreg('"', text)
					vim.fn.setreg("+", text)
					notify("Yanked: " .. text)
				end
			end,
		},
		win = {
			input = {
				keys = {
					["<a-a>"] = { "docx_accept", mode = { "n", "i" } },
					["<a-x>"] = { "docx_dismiss", mode = { "n", "i" } },
					["<a-y>"] = { "docx_yank", mode = { "n", "i" } },
				},
			},
			list = { keys = { ["<a-a>"] = "docx_accept", ["<a-x>"] = "docx_dismiss", ["<a-y>"] = "docx_yank" } },
		},
		on_close = function()
			if vim.iter(review.items):all(function(i)
				return i.done
			end) then
				vim.diagnostic.reset(ns, review.buf)
				notify("All changes and comments reviewed. :w to save the source.")
			end
		end,
	})
end

-- Markdown/quarto files the docx might have been rendered from, best guess first.
local function sources_for(docx)
	local dir = vim.fs.dirname(docx)
	local stem = vim.fn.fnamemodify(docx, ":t:r"):lower()
	local found = {}
	for _, d in ipairs(vim.fn.uniq({ dir, vim.fn.getcwd() })) do
		for _, f in ipairs(vim.fn.globpath(d, "*.{qmd,md,Rmd,rmd}", false, true)) do
			local name = vim.fn.fnamemodify(f, ":t:r"):lower()
			-- Longest shared prefix with the docx name: "manuscript_JD" -> "manuscript".
			local n = 0
			while n < #name and name:sub(n + 1, n + 1) == stem:sub(n + 1, n + 1) do
				n = n + 1
			end
			found[#found + 1] = { file = f, score = n }
		end
	end
	table.sort(found, function(a, b)
		return a.score > b.score
	end)
	return vim.tbl_map(function(x)
		return x.file
	end, found)
end

function M.start(arg)
	local name = vim.api.nvim_buf_get_name(0)
	local this_docx = vim.b.docx_path
	if arg and arg ~= "" then
		local docx = vim.fn.fnamemodify(vim.fn.expand(arg), ":p")
		return M.review(docx, vim.api.nvim_get_current_buf())
	end
	if this_docx then
		local candidates = sources_for(this_docx)
		local function go(src)
			if src then
				vim.cmd.edit(vim.fn.fnameescape(src))
				M.review(this_docx, vim.api.nvim_get_current_buf())
			end
		end
		if #candidates == 0 then
			return notify("No .md or .qmd file next to the document to apply the changes to.", vim.log.levels.WARN)
		end
		return vim.ui.select(candidates, {
			prompt = "Source the document was rendered from",
			format_item = function(f)
				return vim.fn.fnamemodify(f, ":~:.")
			end,
		}, go)
	end
	local dir = name ~= "" and vim.fs.dirname(name) or vim.fn.getcwd()
	local docs = vim.fn.globpath(dir, "*.docx", false, true)
	docs = vim.tbl_filter(function(f)
		return not vim.fn.fnamemodify(f, ":t"):match("^~%$")
	end, docs)
	table.sort(docs, function(a, b)
		return vim.fn.getftime(a) > vim.fn.getftime(b)
	end)
	if #docs == 0 then
		return notify("No .docx files in " .. vim.fn.fnamemodify(dir, ":~") .. ". Use :DocxReview path/to/file.docx", vim.log.levels.WARN)
	end
	local buf = vim.api.nvim_get_current_buf()
	if #docs == 1 then
		return M.review(docs[1], buf)
	end
	vim.ui.select(docs, {
		prompt = "Word document to review (newest first)",
		format_item = function(f)
			return vim.fn.fnamemodify(f, ":t")
		end,
	}, function(docx)
		if docx then
			M.review(docx, buf)
		end
	end)
end

---------------------------------------------------------------------------
-- Opening a .docx
---------------------------------------------------------------------------

local FILTER = [[
local function raw(s) return pandoc.RawInline("markdown", s) end
function Span(el)
  local c, by = el.classes, el.attributes.author or "Unknown"
  if c:includes("insertion") then
    return pandoc.Inlines({ raw("{++") }) .. el.content .. { raw("++}") }
  elseif c:includes("deletion") then
    return pandoc.Inlines({ raw("{--") }) .. el.content .. { raw("--}") }
  elseif c:includes("comment-start") then
    return raw("{>>" .. by .. ": " .. pandoc.utils.stringify(el.content) .. "<<}{==")
  elseif c:includes("comment-end") then
    return raw("==}")
  elseif c:includes("paragraph-insertion") or c:includes("paragraph-deletion") then
    return {}
  end
end
]]

local function filter_path()
	local path = vim.fn.stdpath("cache") .. "/docx-criticmarkup.lua"
	local f = io.open(path, "r")
	local current = f and f:read("*a")
	if f then
		f:close()
	end
	if current ~= FILTER then
		vim.fn.writefile(vim.split(FILTER, "\n"), path)
	end
	return path
end

function M.open(buf, path)
	local md, err = pandoc({
		"--track-changes=all",
		"--wrap=none",
		"--lua-filter",
		filter_path(),
		"-f",
		"docx",
		"-t",
		"markdown-raw_html-native_divs-native_spans-bracketed_spans",
		path,
	})
	local lines = vim.split(md or ("Couldn't read " .. path .. ":\n\n" .. (err or "")), "\n", { trimempty = true })
	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false
	vim.bo[buf].modified = false
	vim.bo[buf].buftype = "nowrite"
	vim.bo[buf].swapfile = false
	vim.b[buf].docx_path = path
	vim.bo[buf].filetype = "markdown"
	vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
	mark_critic(buf, lines)
	vim.api.nvim_create_autocmd("BufWinEnter", {
		buffer = buf,
		callback = function()
			vim.wo.wrap, vim.wo.linebreak, vim.wo.conceallevel = true, true, 2
		end,
	})
	vim.wo.wrap, vim.wo.linebreak, vim.wo.conceallevel = true, true, 2
end

function M.setup()
	vim.api.nvim_create_autocmd("BufReadCmd", {
		pattern = "*.docx",
		group = vim.api.nvim_create_augroup("docx_review", { clear = true }),
		callback = function(ev)
			M.open(ev.buf, vim.fn.fnamemodify(ev.match, ":p"))
		end,
	})
	vim.api.nvim_create_user_command("DocxReview", function(o)
		M.start(o.args)
	end, { nargs = "?", complete = "file", desc = "Review a Word document's tracked changes and comments" })
	vim.keymap.set("n", "<leader>ow", M.start, { desc = "Review Word document changes" })
end

return M
