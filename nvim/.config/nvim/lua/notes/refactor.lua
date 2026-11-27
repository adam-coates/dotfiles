-- Bigger changes: rename a tag everywhere, split a section off into its own note,
-- tidy a note's properties.

local util = require("notes.util")
local vault = require("notes.vault")
local index = require("notes.index")

local M = {}

--- Rename #old (and #old/...) to #new in every note, inline and in properties.
function M.rename_tag(old)
	local function run(tag)
		util.input({ prompt = "Rename #" .. tag .. " to", default = tag }, function(new)
			new = new:gsub("^#", "")
			if new == tag or not new:match("^[%w_/%-\128-\255]+$") then
				return
			end
			local entries = {}
			for name, list in pairs(index.refresh().tags()) do
				if name:lower() == tag:lower() then
					entries = list
				end
			end
			if #entries == 0 then
				return util.notify("No notes with #" .. tag, "warn")
			end
			if vim.fn.confirm(("Rename #%s to #%s in %d note%s?"):format(tag, new, #entries, #entries == 1 and "" or "s"), "&Yes\n&No") ~= 1 then
				return
			end
			vim.cmd("silent! wall")
			local count = 0
			for _, entry in ipairs(entries) do
				local lines = util.lines(util.read(entry.path) or "")
				local out = M.rename_tag_in(lines, tag, new, entry.body)
				if table.concat(out, "\n") ~= table.concat(lines, "\n") then
					util.write(entry.path, table.concat(out, "\n") .. "\n")
					count = count + 1
				end
			end
			vim.cmd("silent! checktime")
			index.refresh()
			vim.api.nvim_exec_autocmds("User", { pattern = "NotesChanged", data = {} })
			util.notify(("Renamed #%s to #%s in %d note%s"):format(tag, new, count, count == 1 and "" or "s"))
		end)
	end
	if old then
		run(old)
	else
		local names = vim.tbl_keys(index.refresh().tags())
		table.sort(names)
		vim.ui.select(names, { prompt = "Rename which tag?" }, function(tag)
			if tag then
				run(tag)
			end
		end)
	end
end

--- The same on a list of lines; `body` is the first line after the properties.
function M.rename_tag_in(lines, old, new, body)
	local out, fence, in_tags = {}, false, false
	-- A tag, not followed by more of a tag name (but #old/child is fine)
	local function swap(text, prefix)
		local low = text:lower()
		local result, pos = {}, 1
		while true do
			local s, e = low:find(prefix .. old:lower(), pos, true)
			if not s then
				break
			end
			local before = s == 1 and " " or text:sub(s - 1, s - 1)
			local after = text:sub(e + 1, e + 1)
			local ok = not after:match("[%w_%-\128-\255]") and before:match("[%s%(,;\"'%[]")
			result[#result + 1] = text:sub(pos, s - 1) .. (ok and (prefix .. new) or text:sub(s, e))
			pos = e + 1
		end
		return table.concat(result) .. text:sub(pos)
	end
	for i, line in ipairs(lines) do
		if i < (body or 1) then
			local key = line:match("^(%a[%w_-]*):")
			if key then
				in_tags = key:lower() == "tags" or key:lower() == "tag"
			end
			if in_tags then
				local head, rest = line:match("^(%a[%w_-]*:)(.*)$")
				if head then
					line = head .. swap(rest, "")
				else
					line = swap(line, "")
				end
				-- "#tag" in quotes
				line = swap(line, "#")
			end
		else
			if line:match("^%s*[`~][`~][`~]") then
				fence = not fence
			elseif not fence then
				line = swap(line, "#")
			end
		end
		out[i] = line
	end
	return out
end

--- Move the section under the cursor to a note of its own, leaving a link (or with
--- `embed`, an embed) behind.
function M.extract_section(embed)
	local buf = vim.api.nvim_get_current_buf()
	local entry = index.buffer(buf)
	if not entry then
		return
	end
	local row = vim.api.nvim_win_get_cursor(0)[1]
	local at
	for i, h in ipairs(entry.headings) do
		if h.line <= row then
			at = i
		end
	end
	if not at then
		return util.notify("The cursor isn't under a heading", "warn")
	end
	local heading = entry.headings[at]
	local last = vim.api.nvim_buf_line_count(buf)
	for j = at + 1, #entry.headings do
		if entry.headings[j].level <= heading.level then
			last = entry.headings[j].line - 1
			break
		end
	end
	local title = util.filename(util.plain(heading.text))
	local path = vim.fs.joinpath(vault.root(), entry.folder, title .. ".md")
	if vim.uv.fs_stat(path) then
		return util.notify("“" .. title .. "” already exists", "warn")
	end
	-- Footnotes stay behind, and go along too when the section uses them.
	local body, footnotes = {}, {}
	for _, line in ipairs(vim.api.nvim_buf_get_lines(buf, heading.line, last, false)) do
		table.insert(line:match("^%[%^[^%]]+%]:") and footnotes or body, line)
	end
	while body[1] and body[1]:match("^%s*$") do
		table.remove(body, 1)
	end
	local used = vim.tbl_filter(function(line)
		return table.concat(body, "\n"):find(line:match("^(%[%^[^%]]+%])"), 1, true) ~= nil
	end, footnotes)
	if #used > 0 then
		vim.list_extend(body, vim.list_extend({ "" }, used))
	end
	local text = require("notes.template").render("note", { title = title })
	util.write(path, text:gsub("%s+$", "") .. "\n\n" .. table.concat(body, "\n"):gsub("%s+$", "") .. "\n")
	local hashes = ("#"):rep(heading.level)
	local left = { hashes .. " " .. heading.text, "", (embed and "!" or "") .. "[[" .. title .. "]]", "" }
	vim.list_extend(left, footnotes)
	vim.api.nvim_buf_set_lines(buf, heading.line - 1, last, false, left)
	vim.cmd("silent update")
	index.update(path)
	vim.api.nvim_exec_autocmds("User", { pattern = "NotesChanged", data = {} })
	util.notify("Moved to " .. title)
end

--- Set a property in the frontmatter, adding the block when there is none.
function M.set_property(key, value, buf)
	buf = buf or vim.api.nvim_get_current_buf()
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	local line = key .. ": " .. value
	if not (lines[1] or ""):match("^%-%-%-%s*$") then
		return vim.api.nvim_buf_set_lines(buf, 0, 0, false, { "---", line, "---", "" })
	end
	for i = 2, #lines do
		if lines[i]:match("^%-%-%-%s*$") then
			return vim.api.nvim_buf_set_lines(buf, i - 1, i - 1, false, { line })
		elseif lines[i]:match("^" .. vim.pesc(key) .. ":") then
			local stop = i
			while lines[stop + 1] and lines[stop + 1]:match("^%s+") or (lines[stop + 1] or ""):match("^%- ") do
				stop = stop + 1
			end
			return vim.api.nvim_buf_set_lines(buf, i - 1, stop, false, { line })
		end
	end
end

--- Ask for a property and its value, completing from what the vault already uses.
function M.ask_property()
	local known = {}
	for _, entry in ipairs(index.all()) do
		for key, value in pairs(entry.fm) do
			key = tostring(key)
			known[key] = known[key] or { n = 0, values = {} }
			known[key].n = known[key].n + 1
			if type(value) == "string" or type(value) == "number" or type(value) == "boolean" then
				known[key].values[tostring(value)] = true
			end
		end
	end
	local keys = vim.tbl_keys(known)
	table.sort(keys, function(a, b)
		return known[a].n > known[b].n
	end)
	keys[#keys + 1] = "New property…"
	vim.ui.select(keys, { prompt = "Property" }, function(key)
		local function value_for(name)
			local values = known[name] and vim.tbl_keys(known[name].values) or {}
			table.sort(values)
			values = vim.list_slice(values, 1, 40)
			values[#values + 1] = "Other value…"
			local function ask()
				util.input({ prompt = name }, function(value)
					local date = require("notes.date").parse(value)
					M.set_property(name, date or value)
				end)
			end
			if #values == 1 then
				return ask()
			end
			vim.ui.select(values, { prompt = name }, function(value)
				if value == "Other value…" then
					ask()
				elseif value then
					M.set_property(name, value)
				end
			end)
		end
		if key == "New property…" then
			util.input({ prompt = "Property name" }, value_for)
		elseif key then
			value_for(key)
		end
	end)
end

return M
