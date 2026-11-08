local M = {}

local api, fn, bo = vim.api, vim.fn, vim.bo
local get_opt = api.nvim_get_option_value

local tools = require("utils.tools")
local icons = tools.ui.icons

local HL = {
	branch = { "DiagnosticOk", icons.branch },
	file = { "NonText", icons.node },
	fileinfo = { "Function", icons.document },
	nomodifiable = { "DiagnosticWarn", icons.bullet },
	modified = { "DiagnosticError", icons.bullet },
	readonly = { "DiagnosticWarn", icons.lock },
	error = { "DiagnosticError", icons.error },
	warn = { "DiagnosticWarn", icons.warning },
	visual = { "DiagnosticInfo", "‹› " },
}

local ICON = {}
for k, v in pairs(HL) do
	ICON[k] = tools.hl_str(v[1], v[2])
end

-- first character of nvim_get_mode().mode -> label and color
local MODES = {
	n = { "N", "Normal" },
	i = { "I", "Insert" },
	v = { "V", "Visual" },
	V = { "L", "Visual" },
	["\22"] = { "B", "Visual" },
	s = { "S", "Visual" },
	S = { "S", "Visual" },
	["\19"] = { "S", "Visual" },
	R = { "R", "Replace" },
	c = { "C", "Command" },
	t = { "T", "Terminal" },
	r = { "?", "Command" },
	["!"] = { "!", "Command" },
}

-- Each mode takes its color from a theme group, so it follows the colorscheme.
local MODE_COLORS = {
	Normal = "Function",
	Insert = "String",
	Visual = "Keyword",
	Replace = "DiagnosticError",
	Command = "DiagnosticWarn",
	Terminal = "Type",
}

local ORDER = {
	"mode",
	"path",
	"venv",
	"mod",
	"ro",
	"sep",
	"diag",
	"fileinfo",
	"pad",
	"scrollbar",
	"pad",
}

local PAD = " "
local SEP = "%="

-- utilities -----------------------------------------
local function concat(parts)
	local out, i = {}, 1
	for _, k in ipairs(ORDER) do
		local v = parts[k]
		if v and v ~= "" then
			out[i] = v
			i = i + 1
		end
	end
	return table.concat(out, " ")
end

local function esc_str(str)
	return str:gsub("([%(%)%%%+%-%*%?%[%]%^%$])", "%%%1")
end

-- mode indicator ---------------------------------------------
local function mode_widget()
	local mode = MODES[api.nvim_get_mode().mode:sub(1, 1)] or MODES.n
	return tools.hl_str("StatusLineMode" .. mode[2], " " .. mode[1] .. " ")
end

-- path and git info -----------------------------------------
local function path_widget(root, fname)
	local file_name = fn.fnamemodify(fname, ":t")

	local icon, hl
	if file_name == "" then
		icon, hl = MiniIcons.get("default", "file")
	else
		icon, hl = MiniIcons.get("file", file_name)
	end
	icon = icon .. " "

	if fname == "" then
		file_name = "[No Name]"
	end
	-- A literal % would start a statusline item.
	file_name = file_name:gsub("%%", "%%%%")
	local path = tools.hl_str(hl, icon) .. file_name

	if bo.buftype == "help" then
		return ICON.file .. path
	end

	local dir_path = fn.fnamemodify(fname, ":h") .. "/"
	if dir_path == "./" then
		dir_path = ""
	end

	local remote = tools.get_git_remote_name(root)
	local branch = tools.get_git_branch(root)
	local repo_info = ""
	if remote and branch then
		dir_path = dir_path:gsub("^" .. esc_str(root) .. "/", ""):gsub("%%", "%%%%")
		repo_info = string.format("%s %s @ %s ", ICON.branch, remote, branch)
	end

	local win_w = api.nvim_win_get_width(0)
	local need = #repo_info + #dir_path + #path
	if win_w < need + 5 then
		dir_path = ""
	end
	if win_w < need - #dir_path then
		repo_info = ""
	end

	return repo_info .. ICON.file .. " " .. dir_path .. path .. " "
end

-- diagnostics ---------------------------------------------
local function diagnostics_widget()
	if not tools.diagnostics_available() then
		return ""
	end
	local diag_count = vim.diagnostic.count(0)
	local err, warn = string.format("%-3d", diag_count[1] or 0), string.format("%-3d", diag_count[2] or 0)

	return string.format(
		"%s %s  %s %s  ",
		ICON.error,
		tools.hl_str("DiagnosticError", err),
		ICON.warn,
		tools.hl_str("DiagnosticWarn", warn)
	)
end
-- markdown check ---------------------------------------------
local function is_markdown()
	return bo.filetype == "markdown" or bo.filetype == "asciidoc" or bo.filetype == "quarto"
end

-- file/selection info -------------------------------------
local function fileinfo_widget()
	local ft = get_opt("filetype", {})
	local lines = tools.group_number(api.nvim_buf_line_count(0), ",")
	local str = ICON.fileinfo .. " "

	-- For markdown files, show reading time
	if is_markdown() then
		local wc = fn.wordcount()
		local words = wc.visual_words or wc.words
		local reading_time = math.ceil(words / 200.0)

		if not wc.visual_words then
			return str
				.. string.format("%3s lines  %3s words  %s min", lines, tools.group_number(words, ","), reading_time)
		else
			local vlines = math.abs(fn.line(".") - fn.line("v")) + 1
			return str
				.. string.format(
					"%3s lines  %3s words  %3s chars  %s min",
					tools.group_number(vlines, ","),
					tools.group_number(wc.visual_words, ","),
					tools.group_number(wc.visual_chars, ","),
					reading_time
				)
		end
	end

	-- For non-programming modes (but not markdown)
	if not tools.nonprog_modes[ft] then
		return str .. string.format("%3s lines", lines)
	end

	local wc = fn.wordcount()
	if not wc.visual_words then
		return str .. string.format("%3s lines  %3s words", lines, tools.group_number(wc.words, ","))
	end

	local vlines = math.abs(fn.line(".") - fn.line("v")) + 1
	return str
		.. string.format(
			"%3s lines %3s words  %3s chars",
			tools.group_number(vlines, ","),
			tools.group_number(wc.visual_words, ","),
			tools.group_number(wc.visual_chars, ",")
		)
end
-- python venv ---------------------------------------------
local function venv_widget()
	if bo.filetype ~= "python" then
		return ""
	end
	local env = vim.env.VIRTUAL_ENV

	local str
	if env and env ~= "" then
		str = string.format("[.venv: %s]  ", fn.fnamemodify(env, ":t"))
		return tools.hl_str("Comment", str)
	end
	env = vim.env.CONDA_DEFAULT_ENV
	if env and env ~= "" then
		str = string.format("[conda: %s]  ", env)
		return tools.hl_str("Comment", str)
	end
	return tools.hl_str("Comment", "[no venv]")
end

-- scrollbar ---------------------------------------------
local function scrollbar_widget()
	local sbar_chars = {
		"▔", -- top
		"🮂",
		"🬂",
		"🮃",
		"▀",
		"▄",
		"▃",
		"🬭",
		"▂",
		"▁", -- bottom
	}

	local cur_line = api.nvim_win_get_cursor(0)[1]
	local lines = api.nvim_buf_line_count(0)

	local i = math.floor((math.max(cur_line, 1) - 1) / lines * #sbar_chars) + 1
	return string.rep(sbar_chars[i], 2)
end

-- render ---------------------------------------------
function M.render()
	local fname = api.nvim_buf_get_name(0)
	local root = (bo.buftype == "" and tools.get_path_root(fname)) or nil
	if bo.buftype ~= "" and bo.buftype ~= "help" then
		fname = bo.ft
	end

	local buf = api.nvim_win_get_buf(vim.g.statusline_winid)

	local parts = {
		pad = PAD,
		path = path_widget(root, fname),
		venv = venv_widget(),
		mode = mode_widget(),
		mod = get_opt("modifiable", { buf = buf }) and (get_opt("modified", { buf = buf }) and ICON.modified or " ")
			or ICON.nomodifiable,
		ro = get_opt("readonly", { buf = buf }) and ICON.readonly or "",
		sep = SEP,
		diag = diagnostics_widget(),
		fileinfo = fileinfo_widget(),
		scrollbar = scrollbar_widget(),
	}

	return concat(parts)
end

-- setup ---------------------------------------------
-- Black or white, whichever reads better on the given color.
local function contrast(color)
	local r, g, b = bit.rshift(color, 16), bit.band(bit.rshift(color, 8), 255), bit.band(color, 255)
	return (0.299 * r + 0.587 * g + 0.114 * b) > 140 and "#000000" or "#ffffff"
end

local function set_highlights()
	local normal = api.nvim_get_hl(0, { name = "Normal", link = false })
	-- No background, so the bar blends into the theme (or the transparent terminal).
	api.nvim_set_hl(0, "StatusLine", { fg = normal.fg })
	api.nvim_set_hl(0, "StatusLineNC", { fg = normal.fg })

	for mode, group in pairs(MODE_COLORS) do
		local color = api.nvim_get_hl(0, { name = group, link = false }).fg or normal.fg or 0xffffff
		api.nvim_set_hl(0, "StatusLineMode" .. mode, { fg = contrast(color), bg = color, bold = true })
	end
end

function M.setup()
	set_highlights()
	vim.o.showmode = false -- the mode block replaces it
	vim.o.statusline = "%!v:lua.require('utils.statusline').render()"

	local group = api.nvim_create_augroup("UserStatusline", { clear = true })
	api.nvim_create_autocmd("ColorScheme", { group = group, callback = set_highlights })
	api.nvim_create_autocmd({ "DiagnosticChanged", "ModeChanged" }, {
		group = group,
		callback = function()
			vim.cmd("redrawstatus")
		end,
	})
	api.nvim_create_autocmd({ "FocusGained", "DirChanged" }, {
		group = group,
		callback = tools.clear_git_cache,
	})
end

return M
