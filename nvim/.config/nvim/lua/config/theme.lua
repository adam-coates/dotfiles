-- Colours. Follows the current Omarchy theme, the same way the previous config
-- did (this is a trimmed copy of its utils/omarchy/theme.lua), and switches
-- live when the theme changes.
--
-- Omarchy's theme-set hook (~/.config/omarchy/hooks/theme-set.d) reloads every
-- Neovim listening on an nvim.* or nvim-old.* socket. Run under another
-- NVIM_APPNAME, this watches the theme name file instead.

local settings = require("settings")

local M = {}

local state = vim.env.HOME .. "/.local/state/omarchy/current"
M.spec_file = state .. "/theme/neovim.lua"
M.name_file = state .. "/theme.name"
M.colors_file = state .. "/theme/colors.toml"

-- Aether watches theme files itself; we already do.
_G.__aether_hotreload_state = { did_setup = true, fs_event_handles = {}, pending_reload_timers = {} }

-- Your previous config's overrides (utils/omarchy/overrides.lua). Omarchy won't stage
-- neovim.lua from a theme installed through git, since Neovim would run it, and
-- generates an aether approximation instead. These themes get their real
-- colorscheme, keyed by Omarchy's theme name. Also used for settings.colorscheme
-- when Omarchy isn't there.
local overrides = {
	["gruvbox-material"] = {
		colorscheme = "gruvbox-material",
		plugin = {
			"sainnhe/gruvbox-material",
			name = "gruvbox-material",
			config = function()
				-- https://github.com/sainnhe/gruvbox-material/blob/master/autoload/gruvbox_material.vim
				vim.g.gruvbox_material_background = "medium"
				vim.g.gruvbox_material_foreground = "material"
				vim.g.gruvbox_material_enable_bold = 1
				vim.g.gruvbox_material_enable_italic = 1
				vim.g.gruvbox_material_transparent_background = 1
				vim.g.gruvbox_material_menu_selection_background = "orange"
				vim.g.gruvbox_material_float_style = "blend"
				vim.g.gruvbox_material_diagnostic_text_highlight = 1
				vim.g.gruvbox_material_diagnostic_virtual_text = "colored"
				vim.g.gruvbox_material_current_word = "underline"
				vim.g.gruvbox_material_better_performance = 1

				vim.api.nvim_create_autocmd("ColorScheme", {
					group = vim.api.nvim_create_augroup("GruvboxMaterialBorder", { clear = true }),
					pattern = "gruvbox-material",
					callback = function()
						vim.api.nvim_set_hl(0, "FloatBorder", { fg = "#a89984" })
					end,
				})
			end,
		},
	},
}
M.overrides = overrides

function M.palette()
	local colors = {}
	if vim.fn.filereadable(M.colors_file) == 1 then
		for _, line in ipairs(vim.fn.readfile(M.colors_file)) do
			local key, value = line:match('^%s*([%w_]+)%s*=%s*"([^"]+)"')
			if key then
				colors[key] = value
			end
		end
	end
	return colors
end

local function omarchy()
	return settings.follow_omarchy and vim.uv.fs_stat(M.name_file) ~= nil
end

local function read()
	local out = { plugins = {}, colorscheme = settings.colorscheme }
	local name = omarchy() and vim.fn.readfile(M.name_file, "", 1)[1] or nil
	local override = overrides[name or settings.colorscheme]
	if override and (name or not omarchy()) then
		return { plugins = { override.plugin }, colorscheme = override.colorscheme }
	end
	local chunk = omarchy() and loadfile(M.spec_file) or nil
	local ok, theme = false, nil
	if chunk then
		ok, theme = pcall(chunk)
	end
	if not ok or type(theme) ~= "table" then
		out.plugins = { overrides[settings.colorscheme] and overrides[settings.colorscheme].plugin }
		return out
	end
	if type(theme[1]) == "string" then
		theme = { theme }
	end
	out.colorscheme = nil
	for _, spec in ipairs(theme) do
		if type(spec) == "table" and type(spec[1]) == "string" then
			if spec[1] == "LazyVim/LazyVim" then
				out.setup_opts = vim.deepcopy(spec.opts or {})
				out.colorscheme = out.setup_opts.colorscheme
				out.setup_opts.colorscheme = nil
			elseif spec.enabled ~= false then
				out.plugins[#out.plugins + 1] = spec
			end
		end
	end
	return out
end

local function pack_spec(spec)
	local pack = {
		src = spec[1]:find("://", 1, true) and spec[1] or ("https://github.com/" .. spec[1]),
		name = spec.name or spec[1]:match("[^/]+$"):gsub("%.git$", ""),
		version = spec.branch or spec.tag or spec.commit,
	}
	-- Themes disagree on where a plugin lives; keep whichever copy is installed.
	for _, plugin in ipairs(vim.pack.get()) do
		if plugin.spec.name == pack.name then
			pack.src = plugin.spec.src
		end
	end
	return pack
end

local function forget_modules(path)
	for file, kind in vim.fs.dir(path .. "/lua", { depth = 10 }) do
		if kind == "file" and file:match("%.lua$") then
			package.loaded[file:gsub("%.lua$", ""):gsub("/init$", ""):gsub("/", ".")] = nil
		end
	end
end

local function find_setup(name, path)
	local base = name:gsub("%.nvim$", ""):gsub("%-nvim$", ""):gsub("%-neovim$", "")
	for _, mod_name in ipairs({ base, name }) do
		local file = path .. "/lua/" .. mod_name:gsub("%.", "/")
		if vim.uv.fs_stat(file .. ".lua") or vim.uv.fs_stat(file .. "/init.lua") then
			local ok, mod = pcall(require, mod_name)
			if ok and type(mod) == "table" and type(mod.setup) == "function" then
				return mod
			end
		end
	end
end

local function configure(spec, theme)
	local pack = pack_spec(spec)
	vim.pack.add({ pack }, { confirm = false, load = true })
	local path = vim.pack.get({ pack.name })[1].path
	forget_modules(path)
	if spec.init then
		spec.init()
	end
	local opts = vim.tbl_deep_extend("force", theme.setup_opts or {}, spec.opts or {})
	if spec.config then
		spec.config(nil, opts)
	elseif not vim.tbl_isempty(opts) then
		local mod = find_setup(pack.name, path)
		if mod then
			pcall(mod.setup, opts)
		end
	end
end

-- Highlights -------------------------------------------------------------------

local function hex(n)
	return n and ("#%06x"):format(n) or nil
end

local function get(name)
	local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
	return ok and hl or {}
end

--- Mix two "#rrggbb" colours; `amount` of `a` in `b`.
function M.blend(a, b, amount)
	local function rgb(c)
		return tonumber(c:sub(2, 3), 16), tonumber(c:sub(4, 5), 16), tonumber(c:sub(6, 7), 16)
	end
	local r1, g1, b1 = rgb(a)
	local r2, g2, b2 = rgb(b)
	local function mix(x, y)
		return math.floor(x * amount + y * (1 - amount) + 0.5)
	end
	return ("#%02x%02x%02x"):format(mix(r1, r2), mix(g1, g2), mix(b1, b2))
end

--- Colours the rest of the config can rely on, whatever the theme.
function M.colors()
	local p = omarchy() and M.palette() or {}
	local dark = vim.o.background ~= "light"
	local function fg(name, fallback)
		return hex(get(name).fg) or fallback
	end
	return {
		bg = p.background or hex(get("Normal").bg) or (dark and "#282828" or "#fbf1c7"),
		fg = p.foreground or fg("Normal", dark and "#d4be98" or "#654735"),
		muted = fg("Comment", p.muted or "#928374"),
		accent = p.accent or fg("Function", "#e1875c"),
		red = p.red or fg("DiagnosticError", "#ea6962"),
		orange = p.orange or fg("Constant", "#e78a4e"),
		yellow = p.yellow or fg("DiagnosticWarn", "#d8a657"),
		green = p.green or fg("String", "#a9b665"),
		cyan = p.cyan or fg("Special", "#89b482"),
		blue = p.blue or fg("DiagnosticInfo", "#7daea3"),
		magenta = p.magenta or fg("Statement", "#d3869b"),
	}
end

local transparent = {
	"Normal",
	"NormalNC",
	"NormalFloat",
	"FloatBorder",
	"FloatTitle",
	"Pmenu", -- as in your previous config's transparency.lua
	"WhichKeyFloat",
	"Terminal",
	"EndOfBuffer",
	"FoldColumn",
	"Folded",
	"SignColumn",
	"WinBar",
	"WinBarNC",
	"WhichKeyNormal",
	"StatusLine",
	"StatusLineNC",
}

function M.highlights()
	local c = M.colors()
	local set = function(name, hl)
		vim.api.nvim_set_hl(0, name, hl)
	end

	if settings.transparent then
		for _, name in ipairs(transparent) do
			local hl = get(name)
			hl.bg, hl.ctermbg = nil, nil
			set(name, hl)
		end
	end

	-- Headings: the theme's colour on a faint band of itself.
	local heads = { c.red, c.orange, c.yellow, c.green, c.blue, c.magenta }
	for i, color in ipairs(heads) do
		local theme_fg = hex(get("@markup.heading." .. i .. ".markdown").fg) or color
		set("RenderMarkdownH" .. i, { fg = theme_fg, bold = true })
		set("RenderMarkdownH" .. i .. "Bg", { bg = M.blend(theme_fg, c.bg, 0.13) })
	end
	set("RenderMarkdownCode", { bg = M.blend(c.fg, c.bg, 0.06) })
	set("RenderMarkdownCodeInline", { fg = c.cyan, bg = M.blend(c.fg, c.bg, 0.09) })
	set("RenderMarkdownInlineHighlight", { fg = c.fg, bg = M.blend(c.yellow, c.bg, 0.32) })
	set("RenderMarkdownWikiLink", { fg = c.blue, underline = true, sp = M.blend(c.blue, c.bg, 0.5) })
	set("RenderMarkdownLink", { fg = c.cyan, underline = true, sp = M.blend(c.cyan, c.bg, 0.5) })
	set("RenderMarkdownTableHead", { fg = c.muted })
	set("RenderMarkdownTableRow", { fg = c.muted })
	set("RenderMarkdownDash", { fg = c.muted })
	set("@markup.strong", { bold = true, fg = M.blend(c.fg, "#ffffff", vim.o.background == "light" and 1 or 0.75) })
	set("@markup.italic", { italic = true })
	set("@markup.strikethrough", { strikethrough = true, fg = c.muted })

	-- Ours
	set("NotesTitle", { fg = c.accent, bold = true })
	set("NotesHeader", { fg = c.yellow, bold = true })
	set("NotesMuted", { fg = c.muted })
	set("NotesText", { fg = c.fg })
	set("NotesAccent", { fg = c.accent })
	set("NotesLink", { fg = c.blue })
	set("NotesLinkMissing", { fg = M.blend(c.blue, c.bg, 0.55), italic = true })
	set("NotesTag", { fg = c.magenta, bg = M.blend(c.magenta, c.bg, 0.13) })
	set("NotesComment", { fg = c.muted, italic = true })
	set("NotesBlockId", { fg = c.muted, italic = true })
	set("NotesField", { fg = c.cyan })
	set("NotesDate", { fg = c.green })
	set("NotesOverdue", { fg = c.red, bold = true })
	set("NotesToday", { fg = c.orange, bold = true })
	set("NotesSoon", { fg = c.yellow })
	set("NotesDone", { fg = c.muted, strikethrough = true })
	set("NotesPriorityHigh", { fg = c.red, bold = true })
	set("NotesPriorityMedium", { fg = c.orange })
	set("NotesPriorityLow", { fg = c.blue })
	set("NotesActive", { bg = M.blend(c.accent, c.bg, 0.18) })
	set("NotesActiveBold", { fg = c.accent, bg = M.blend(c.accent, c.bg, 0.18), bold = true })
	set("NotesBorder", { fg = M.blend(c.fg, c.bg, 0.3) })
	set("NotesCellHead", { fg = c.yellow, bold = true })
	set("NotesError", { fg = c.red })
	set("NotesOk", { fg = c.green })
	set("NotesStatusline", { fg = M.blend(c.fg, c.bg, 0.75) })
	set("NotesStatusMode", { fg = c.bg, bg = c.accent, bold = true })
	set("NotesMatch", { fg = c.bg, bg = c.yellow })
	for name, color in pairs({ Red = c.red, Orange = c.orange, Yellow = c.yellow, Green = c.green, Cyan = c.cyan, Blue = c.blue, Magenta = c.magenta }) do
		set("Notes" .. name, { fg = color })
	end
end

-- Loading ---------------------------------------------------------------------------

local function apply()
	if omarchy() then
		vim.o.background = M.palette().mode == "light" and "light" or "dark"
	end
	local theme = read()
	for _, spec in ipairs(theme.plugins) do
		local ok, err = pcall(configure, spec, theme)
		if not ok then
			vim.notify("theme: " .. tostring(err), vim.log.levels.WARN)
		end
	end
	if theme.colorscheme and not pcall(vim.cmd.colorscheme, theme.colorscheme) then
		pcall(vim.cmd.colorscheme, "habamax")
	end
end

function M.reload()
	vim.schedule(function()
		vim.cmd("highlight clear")
		apply()
		vim.cmd("redraw!")
	end)
	return "" -- --remote-expr wants a value
end

local function watch()
	local handle = vim.uv.new_fs_event()
	if not handle then
		return
	end
	local timer = assert(vim.uv.new_timer())
	-- The name file is written last, once the whole theme is staged.
	pcall(handle.start, handle, state, {}, function(_, file)
		if file == "theme.name" then
			timer:start(300, 0, vim.schedule_wrap(M.reload))
		end
	end)
end

function M.load()
	vim.api.nvim_create_autocmd("ColorScheme", {
		group = vim.api.nvim_create_augroup("notes_theme", { clear = true }),
		callback = M.highlights,
	})
	apply()
	local socket = vim.fs.basename(vim.v.servername or "")
	local hooked = socket:match("^nvim%.") or socket:match("^nvim%-old%.")
	if omarchy() and not hooked then
		watch()
	end
	vim.api.nvim_create_user_command("ThemeReload", M.reload, { desc = "Re-apply the current theme" })
	vim.api.nvim_create_user_command("OmarchyThemeReload", M.reload, { desc = "Re-apply the current theme (your previous config's name)" })
	package.loaded["omarchy.theme"] = M -- the name Omarchy's hook asks for
end

return M
