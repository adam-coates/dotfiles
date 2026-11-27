-- Small helpers shared by the notes.* modules.

local M = {}

function M.notify(msg, level)
	vim.notify(msg, level and vim.log.levels[level:upper()] or vim.log.levels.INFO, { title = "notes", timeout = level == "error" and 12000 or nil })
end

function M.read(path)
	local fd = io.open(path, "r")
	if not fd then
		return nil
	end
	local text = fd:read("*a")
	fd:close()
	return text
end

function M.write(path, text)
	vim.fn.mkdir(vim.fs.dirname(path), "p")
	local fd = assert(io.open(path, "w"))
	fd:write(text)
	fd:close()
end

--- Split text into lines, without a trailing empty one.
function M.lines(text)
	text = text:gsub("\r\n", "\n")
	if text:sub(-1) == "\n" then
		text = text:sub(1, -2)
	end
	return vim.split(text, "\n", { plain = true })
end

--- Run `fn` at most once per `ms`, after the calls stop.
function M.debounce(ms, fn)
	local timer = assert(vim.uv.new_timer())
	return function(...)
		local args = vim.F.pack_len(...)
		timer:stop()
		timer:start(ms, 0, function()
			timer:stop()
			vim.schedule(function()
				fn(vim.F.unpack_len(args))
			end)
		end)
	end
end

--- Cut text to a display width.
function M.truncate(text, width)
	if vim.fn.strdisplaywidth(text) <= width then
		return text
	end
	if width <= 1 then
		return "…"
	end
	local out, used = {}, 0
	for _, char in ipairs(vim.fn.split(text, "\\zs")) do
		local w = vim.fn.strdisplaywidth(char)
		if used + w > width - 1 then
			break
		end
		out[#out + 1], used = char, used + w
	end
	return table.concat(out) .. "…"
end

--- Pad text to a display width.
function M.pad(text, width, align)
	local space = width - vim.fn.strdisplaywidth(text)
	if space <= 0 then
		return text
	elseif align == "right" then
		return (" "):rep(space) .. text
	elseif align == "center" then
		local left = math.floor(space / 2)
		return (" "):rep(left) .. text .. (" "):rep(space - left)
	end
	return text .. (" "):rep(space)
end

--- Markdown markup removed, for lists and panels.
function M.plain(text)
	text = text:gsub("!?%[%[([^%]|]*)|([^%]]*)%]%]", "%2"):gsub("!?%[%[([^%]]*)%]%]", "%1")
	text = text:gsub("!?%[([^%]]*)%]%([^)]*%)", "%1")
	text = text:gsub("%*%*([^*]+)%*%*", "%1"):gsub("==([^=]+)==", "%1"):gsub("`([^`]+)`", "%1")
	text = text:gsub("%s%^[%w%-]+$", "")
	return vim.trim(text)
end

--- A float with `lines`, closed with q and <Esc>. Returns buf, win.
function M.float(lines, opts)
	opts = opts or {}
	local width = opts.width
	if not width then
		width = 20
		for _, line in ipairs(lines) do
			width = math.max(width, vim.fn.strdisplaywidth(line) + 2)
		end
	end
	width = math.min(width, vim.o.columns - 4)
	local height = math.min(opts.height or #lines, vim.o.lines - 4)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].bufhidden = "wipe"
	if opts.filetype then
		vim.bo[buf].filetype = opts.filetype
	end
	vim.bo[buf].modifiable = opts.modifiable or false
	local config = {
		relative = "editor",
		width = width,
		height = math.max(height, 1),
		row = math.floor((vim.o.lines - height) / 2) - 1,
		col = math.floor((vim.o.columns - width) / 2),
		style = "minimal",
		title = opts.title and (" " .. opts.title .. " ") or nil,
		title_pos = opts.title and "center" or nil,
		footer = opts.footer and (" " .. opts.footer .. " ") or nil,
		footer_pos = opts.footer and "center" or nil,
	}
	local win = vim.api.nvim_open_win(buf, opts.enter ~= false, vim.tbl_extend("force", config, opts.config or {}))
	for _, key in ipairs({ "q", "<Esc>" }) do
		vim.keymap.set("n", key, function()
			if vim.api.nvim_win_is_valid(win) then
				vim.api.nvim_win_close(win, true)
			end
		end, { buffer = buf, nowait = true })
	end
	return buf, win
end

--- Write lines made of { text, hl } chunks into a scratch buffer.
--- `rows` is a list of rows, each a list of chunks or strings.
function M.render(buf, ns, rows)
	local lines, marks = {}, {}
	for i, row in ipairs(rows) do
		local col, parts = 0, {}
		for _, chunk in ipairs(row) do
			local text, hl = chunk, nil
			if type(chunk) == "table" then
				text, hl = chunk[1], chunk[2]
			end
			parts[#parts + 1] = text
			if hl and #text > 0 then
				marks[#marks + 1] = { i - 1, col, col + #text, hl }
			end
			col = col + #text
		end
		lines[i] = table.concat(parts)
	end
	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false
	vim.bo[buf].modified = false
	vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
	for _, m in ipairs(marks) do
		vim.api.nvim_buf_set_extmark(buf, ns, m[1], m[2], { end_col = m[3], hl_group = m[4] })
	end
	return lines
end

--- Ask for one line of text. `vim.ui.input` is Snacks' input.
function M.input(opts, fn)
	if type(opts) == "string" then
		opts = { prompt = opts }
	end
	vim.ui.input(opts, function(value)
		if value and vim.trim(value) ~= "" then
			fn(vim.trim(value))
		end
	end)
end

--- A name that is safe as a file name on every system and in wiki links.
--- A value for YAML properties, quoted when it needs to be ("Attention: the claustrum").
function M.yaml_scalar(value)
	local s = tostring(value or "")
	local special = s == "" or s:find(": ", 1, true) or s:find(" #", 1, true) or s:match("^[%s%-?:,%[%]{}#&*!|>'\"%%@`]") or s:match("%s$")
		or s:match("^[%d_.:+%-]+$") -- 2026_11_23 would be read as a number
	local word = ({ yes = true, no = true, ["true"] = true, ["false"] = true, null = true, ["~"] = true })[s:lower()]
	if special or word then
		return '"' .. (s:gsub("\\", "\\\\"):gsub('"', '\\"')) .. '"'
	end
	return s
end

--- Tags as the lines of a YAML list ("\n  - a\n  - b"), for "tags:{{tags}}".
function M.yaml_tags(tags)
	local out = {}
	for _, tag in ipairs(tags) do
		out[#out + 1] = "\n  - " .. M.yaml_scalar(tag)
	end
	return table.concat(out)
end

function M.filename(title)
	local name = title:gsub('[\\/:*?"<>|#^%[%]]', " "):gsub("%s+", " ")
	name = vim.trim(name):gsub("%.+$", "")
	return name ~= "" and name or os.date("%Y-%m-%d %H%M%S")
end

return M
