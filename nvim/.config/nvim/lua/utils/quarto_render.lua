-- Quarto divs and spans in the buffer, styled like the markdown preview.
--
-- A render-markdown custom handler: text inside ::: {.class} divs and
-- [text]{.class} spans is coloured from the document's own stylesheets (the
-- css: files in its front matter), the ::: markers are dimmed, and span and
-- heading attributes ({.class}, {.unnumbered}) are hidden. Like the rest of
-- render-markdown, the raw text shows on the cursor's line.
--
-- var(--name, fallback) in those stylesheets resolves through the theme file
-- Omarchy renders for the preview, so the buffer and the preview match.

local M = {}

M.theme_css = vim.env.HOME .. "/.local/state/omarchy/current/theme/markdown-preview.css"

local cache = {} -- path -> { mtime, text }
local function read(path)
	local stat = vim.uv.fs_stat(path)
	if not stat then
		return nil
	end
	local hit = cache[path]
	if hit and hit.mtime == stat.mtime.sec then
		return hit.text
	end
	local text = table.concat(vim.fn.readfile(path), "\n")
	cache[path] = { mtime = stat.mtime.sec, text = text }
	return text
end

-- --name: value pairs from the preview's theme file
local function theme_vars()
	local vars = {}
	for name, value in (read(M.theme_css) or ""):gmatch("%-%-([%w-]+):%s*([^;]+);") do
		vars[name] = vim.trim(value)
	end
	return vars
end

local function resolve(value, vars)
	return (value:gsub("var%(%s*%-%-([%w-]+)%s*,?%s*([^)]*)%)", function(name, fallback)
		return vars[name] or vim.trim(fallback)
	end))
end

-- css: entries in the front matter, as absolute paths
local function stylesheets(buf, lines)
	if lines[1] ~= "---" then
		return {}
	end
	local dir = vim.fs.dirname(vim.api.nvim_buf_get_name(buf))
	local files, in_css = {}, false
	for i = 2, #lines do
		local line = lines[i]
		if line == "---" or line == "..." then
			break
		end
		local value = line:match("^%s*css:%s*(.*)$")
		if value then
			in_css = value == ""
			for file in value:gsub("^%[", ""):gsub("%]$", ""):gmatch("[^,]+") do
				files[#files + 1] = file
			end
		elseif in_css and line:match("^%s+%-%s+") then
			files[#files + 1] = line:match("^%s+%-%s+(.*)$")
		elseif not line:match("^%s*$") then
			in_css = false
		end
	end
	return vim.tbl_map(function(f)
		return vim.fs.normalize(dir .. "/" .. vim.trim(f):gsub("^['\"]", ""):gsub("['\"]$", ""))
	end, files)
end

-- Highlight group per class, from rules like .a, .b { color: ...; font-style: italic }
local function class_groups(buf, lines)
	local vars = theme_vars()
	local groups = {}
	for _, file in ipairs(stylesheets(buf, lines)) do
		local css = (read(file) or ""):gsub("/%*.-%*/", "")
		for selectors, body in css:gmatch("([^{}]+){([^}]*)}") do
			local hl = {}
			local color = body:match("[^-]color%s*:%s*([^;]+)") or body:match("^%s*color%s*:%s*([^;]+)")
			if color then
				color = resolve(vim.trim(color), vars)
				hl.fg = color:match("^#%x+$") and color or nil
			end
			hl.italic = body:match("font%-style%s*:%s*italic") and true or nil
			hl.bold = body:match("font%-weight%s*:%s*bold") and true or nil
			if next(hl) then
				for class in selectors:gmatch("%.([%w-]+)") do
					local name = "QuartoClass_" .. class:gsub("-", "_")
					vim.api.nvim_set_hl(0, name, hl)
					groups[class] = name
				end
			end
		end
	end
	return groups
end

local function classes(attrs)
	local list = {}
	for class in attrs:gmatch("%.([%w-]+)") do
		list[#list + 1] = class
	end
	return list
end

local function group_for(attrs, groups)
	for _, class in ipairs(classes(attrs)) do
		if groups[class] then
			return groups[class]
		end
	end
end

function M.parse(ctx)
	local buf = ctx.buf
	local start_row, _, end_row = ctx.root:range()
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	local groups = class_groups(buf, lines)
	local marks = {}
	local function mark(row, col, opts, conceal)
		marks[#marks + 1] = { conceal = conceal or false, start_row = row, start_col = col, opts = opts }
	end

	local divs, fence = {}, nil
	local body = 1
	if lines[1] == "---" then
		for i = 2, #lines do
			if lines[i] == "---" or lines[i] == "..." then
				body = i + 1
				break
			end
		end
	end

	for i = body, #lines do
		local row = i - 1
		local line = lines[i]
		local in_root = row >= start_row and row < end_row
		local f = line:match("^%s*([`~][`~][`~]+)")
		if fence then
			if f and f:sub(1, 1) == fence:sub(1, 1) and #f >= #fence then
				fence = nil
			end
		elseif f then
			fence = f
		else
			local colons, attrs = line:match("^%s*(:::+)%s*(.-)%s*$")
			if colons then
				if attrs ~= "" then
					table.insert(divs, { group = group_for(attrs, groups) })
				else
					table.remove(divs)
				end
				if in_root then
					mark(row, 0, { end_col = #line, hl_group = "NonText", priority = 200 }, true)
				end
			elseif in_root then
				-- Text inside styled divs takes the innermost styled class.
				for d = #divs, 1, -1 do
					if divs[d].group and #line > 0 then
						mark(row, 0, { end_col = #line, hl_group = divs[d].group, priority = 150 })
						break
					end
				end
				-- [text]{.class}: colour the text, hide the brackets and attributes.
				local pos = 1
				while true do
					local s, e, text, attrs = line:find("%[([^%[%]]*)%]{([^{}]*)}", pos)
					if not s then
						break
					end
					if attrs:find("[.#=]") then
						local group = group_for(attrs, groups)
						mark(row, s - 1, { end_col = s, conceal = "" }, true)
						if group then
							mark(row, s, { end_col = s + #text, hl_group = group, priority = 160 }, true)
						end
						mark(row, s + #text, { end_col = e, conceal = "" }, true)
					end
					pos = e + 1
				end
				-- ## Heading {.unnumbered}: hide the attributes.
				local hs = line:match("^%s*#+%s+.-()%s+{[^{}]*}%s*$")
				if hs then
					mark(row, hs - 1, { end_col = #line, conceal = "" }, true)
				end
			end
		end
	end
	return marks
end

return M
