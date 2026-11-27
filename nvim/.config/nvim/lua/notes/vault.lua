-- Where the notes are, and opening them in a sensible window.

local settings = require("settings")
local util = require("notes.util")

local M = {}

--- The configured vaults, with absolute paths. $NOTES_VAULT comes first.
function M.list()
	local out = {}
	local env = vim.env.NOTES_VAULT
	if env and env ~= "" then
		local path = vim.fs.normalize(env)
		local known
		for _, v in ipairs(settings.vaults) do
			if vim.fs.normalize(v.path) == path then
				known = v
			end
		end
		out[1] = vim.tbl_extend("force", known or {}, { name = known and known.name or vim.fs.basename(path), path = path })
	end
	for _, v in ipairs(settings.vaults) do
		if not (out[1] and out[1].path == vim.fs.normalize(v.path)) then
			out[#out + 1] = vim.tbl_extend("force", v, { path = vim.fs.normalize(v.path) })
		end
	end
	return out
end

-- Per-vault settings ------------------------------------------------------------------
-- A vault in settings.vaults can bring its own folders, templates and formats. The
-- settings tables are updated in place when the vault changes, so everything that
-- reads settings.folders.* sees the current vault's.

local PER_VAULT = { "folders", "templates", "daily_format", "weekly_format", "ask_location" }
local defaults = {}
for _, key in ipairs(PER_VAULT) do
	defaults[key] = vim.deepcopy(settings[key])
end

--- The settings for one vault (an entry of M.list()), defaults filled in.
function M.settings_for(v)
	local out = {}
	for _, key in ipairs(PER_VAULT) do
		if type(defaults[key]) == "table" then
			out[key] = vim.tbl_extend("force", defaults[key], v and v[key] or {})
		elseif v and v[key] ~= nil then
			out[key] = v[key]
		else
			out[key] = defaults[key]
		end
	end
	return out
end

--- Make settings describe the vault at `path`.
function M.apply(path)
	path = path and vim.fs.normalize(tostring(path))
	local found
	for _, v in ipairs(M.list()) do
		if v.path == path then
			found = v
			break
		end
	end
	local wanted = M.settings_for(found)
	for _, key in ipairs(PER_VAULT) do
		local value = wanted[key] -- nil too: weekly_format can go back to ISO weeks
		if type(value) == "table" then
			for k in pairs(settings[key]) do
				settings[key][k] = nil
			end
			for k, x in pairs(value) do
				settings[key][k] = x
			end
		else
			settings[key] = value
		end
	end
end

--- The vaults whose folder exists.
function M.prepare()
	local vaults = M.list()
	return vim.tbl_filter(function(v)
		return vim.uv.fs_stat(v.path) ~= nil
	end, vaults)
end

function M.root()
	local obsidian = rawget(_G, "Obsidian")
	if obsidian and obsidian.workspace then
		return vim.fs.normalize(tostring(obsidian.workspace.root))
	end
	local first = M.list()[1]
	return first and first.path or vim.fn.getcwd()
end

function M.name()
	local obsidian = rawget(_G, "Obsidian")
	return obsidian and obsidian.workspace and obsidian.workspace.name or vim.fs.basename(M.root())
end

function M.abs(rel)
	return vim.fs.joinpath(M.root(), rel)
end

function M.rel(path)
	local root = M.root() .. "/"
	path = vim.fs.normalize(path)
	if path:sub(1, #root) == root then
		return path:sub(#root + 1)
	end
	return nil
end

--- Is this path a markdown note in the vault?
function M.is_note(path)
	return path ~= nil and path ~= "" and path:match("%.md$") ~= nil and M.rel(path) ~= nil
end

function M.folder(key)
	return M.abs(settings.folders[key] or key)
end

-- Windows ------------------------------------------------------------------------

local SIDE = { notespanel = true, snacks_layout_box = true, snacks_picker_list = true, snacks_picker_input = true }

local function usable(win)
	if vim.api.nvim_win_get_config(win).relative ~= "" then
		return false
	end
	local buf = vim.api.nvim_win_get_buf(win)
	return not SIDE[vim.bo[buf].filetype] and vim.bo[buf].buftype ~= "quickfix" and vim.bo[buf].buftype ~= "terminal" and not vim.wo[win].winfixbuf
end

--- The window notes belong in: the current one unless it's a panel or a float.
function M.main_win()
	local cur = vim.api.nvim_get_current_win()
	if usable(cur) then
		return cur
	end
	local prev = vim.fn.win_getid(vim.fn.winnr("#"))
	if prev ~= 0 and usable(prev) then
		return prev
	end
	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
		if usable(win) then
			return win
		end
	end
	return nil
end

--- Open a note. opts: line, col, cmd ("edit", "vsplit", "split", "tabedit")
function M.open(path, opts)
	opts = opts or {}
	local win = M.main_win()
	if win then
		vim.api.nvim_set_current_win(win)
	else
		vim.cmd("topleft vnew")
	end
	local cmd = opts.cmd or "edit"
	if cmd ~= "edit" or vim.fs.normalize(vim.api.nvim_buf_get_name(0)) ~= vim.fs.normalize(path) then
		vim.cmd[cmd]({ args = { path }, magic = { file = false, bar = false } })
	end
	if opts.line then
		local last = vim.api.nvim_buf_line_count(0)
		pcall(vim.api.nvim_win_set_cursor, 0, { math.max(1, math.min(opts.line, last)), opts.col or 0 })
		vim.cmd("normal! zvzz")
	end
end

--- Create a note from one of the templates (when it doesn't exist) and open it.
--- opts: template (key in settings.templates), vars, open = false
function M.create(path, opts)
	opts = opts or {}
	if not vim.uv.fs_stat(path) then
		local title = vim.fs.basename(path):gsub("%.md$", "")
		-- {{location}} is the folder it goes in, {{tags}} empty unless given.
		local location = M.rel(vim.fs.dirname(vim.fs.normalize(path))) or ""
		local vars = vim.tbl_extend("keep", opts.vars or {}, { title = title, location = location, tags = "" })
		local text = require("notes.template").render(opts.template, vars)
		util.write(path, text)
		require("notes.index").update(path)
	end
	if opts.open ~= false then
		M.open(path, opts)
	end
	return path
end

return M
