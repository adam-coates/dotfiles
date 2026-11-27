-- Inkscape figures in a vault note, the way your previous config makes them
-- (utils/figure.lua, which is used outside a vault): the current line names the
-- figure, a copy of your template opens in Inkscape, and the line becomes the
-- link. The only difference: the file goes in the vault's attachments folder
-- rather than images/ next to the note. On a link to a drawing, it opens that one.

local util = require("notes.util")
local vault = require("notes.vault")
local index = require("notes.index")

local M = {}

local BLANK = [[<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="640" height="400" viewBox="0 0 640 400">
  <rect width="640" height="400" fill="#ffffff"/>
</svg>
]]

local function edit(path)
	if vim.fn.executable("inkscape") == 0 then
		return util.notify("Inkscape isn't installed", "error")
	end
	vim.system({ "inkscape", path }, { detach = true })
end

--- `target` relative to the folder `from` (both absolute), with ../ as needed.
function M.relative(from, target)
	local a = vim.split(vim.fs.normalize(from), "/", { trimempty = true })
	local b = vim.split(vim.fs.normalize(target), "/", { trimempty = true })
	local same = 0
	while same < #a and same < #b and a[same + 1] == b[same + 1] do
		same = same + 1
	end
	local parts = {}
	for _ = same + 1, #a do
		parts[#parts + 1] = ".."
	end
	for i = same + 1, #b do
		parts[#parts + 1] = b[i]
	end
	return table.concat(parts, "/")
end

function M.open()
	local link = require("notes.hover").link_at_cursor()
	if link and link.target:lower():match("%.svg$") then
		local rel = index.resolve_file(link.target, index.buffer())
		if rel then
			return edit(vault.abs(rel))
		end
	end

	local figure = require("utils.figure")
	local title = vim.trim(vim.api.nvim_get_current_line())
	if title == "" then
		return vim.notify("Type the figure name on the current line first", vim.log.levels.WARN)
	end

	-- "My first plot!" -> my-first-plot.svg
	local name = title:lower():gsub("[^%w%s_-]", ""):gsub("%s+", "-") .. ".svg"
	local dir = vault.folder("attachments")
	local file = dir .. "/" .. name
	if not vim.uv.fs_stat(file) then
		vim.fn.mkdir(dir, "p")
		local template = util.read(figure.template)
		if not template then
			util.notify("Figure template not found: " .. figure.template .. " (started from a blank page)", "warn")
		end
		util.write(file, template or BLANK)
		index.update(file)
	end
	edit(file)

	local path = M.relative(vim.fs.dirname(vim.api.nvim_buf_get_name(0)), file)
	local text = ("![%s](%s)"):format(title, path:find(" ") and ("<" .. path .. ">") or path)
	local row = vim.api.nvim_win_get_cursor(0)[1]
	vim.api.nvim_buf_set_lines(0, row - 1, row, false, { text })
	vim.api.nvim_win_set_cursor(0, { row, #text })
end

return M
