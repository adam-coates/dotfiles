-- What render-markdown leaves alone: #tags, %%comments%%, ^block-ids, inline fields
-- (key:: value), task dates and priorities, and links to notes that don't exist.
-- Drawn per visible line while the screen is redrawn, so nothing is stored.

local vault = require("notes.vault")
local index = require("notes.index")
local D = require("notes.date")

local M = {}

local ns = vim.api.nvim_create_namespace("notes_decor")

local EMOJI = {
	["📅"] = "due",
	["⏳"] = "scheduled",
	["🛫"] = "start",
	["➕"] = "muted",
	["✅"] = "muted",
	["❌"] = "muted",
}

local function mark(buf, row, from, to, hl, priority)
	vim.api.nvim_buf_set_extmark(buf, ns, row, from, { end_col = to, hl_group = hl, ephemeral = true, priority = priority or 180 })
end

-- Is there a fence above that hasn't closed? Cached per change.
local fences = {}
local function fenced(buf, row)
	local tick = vim.api.nvim_buf_get_changedtick(buf)
	local state = fences[buf]
	if not state or state.tick ~= tick then
		state = { tick = tick, inside = {} }
		local open, front = nil, false
		for i, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
			if i == 1 and line:match("^%-%-%-%s*$") then
				front = true
				state.inside[0] = "front"
			elseif front then
				state.inside[i - 1] = "front"
				front = not line:match("^%-%-%-%s*$")
			else
				local ticks = line:match("^%s*>?%s*([`~][`~][`~]+)")
				if open then
					state.inside[i - 1] = "code"
					if ticks and #ticks >= #open and line:match("^%s*>?%s*[`~]+%s*$") then
						open = nil
					end
				elseif ticks then
					open = ticks
					state.inside[i - 1] = "code"
				end
			end
		end
		fences[buf] = state
	end
	return state.inside[row]
end

local function on_line(_, _, buf, row)
	local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1]
	if not line or line == "" or #line > 4000 then
		return
	end
	local where = fenced(buf, row)
	if where == "code" then
		return
	elseif where == "front" then
		local key = line:match("^([%w_ -]+):")
		if key then
			mark(buf, row, 0, #key, "NotesField")
		end
		local at, value = line:match("()(%d%d%d%d%-%d%d%-%d%d)")
		if value then
			mark(buf, row, at - 1, at - 1 + #value, "NotesDate")
		end
		return
	end

	-- #tags, outside links, code and headings' own #
	if line:find("#", 1, true) then
		for at, tag, stop in line:gmatch("()#([%w_/%-\128-\255]+)()") do
			local before = at == 1 and " " or line:sub(at - 1, at - 1)
			if before:match("[%s%(,;]") and tag:match("[%a\128-\255]") then
				mark(buf, row, at - 1, stop - 1, "NotesTag")
			end
		end
	end
	-- %%comments%%
	if line:find("%%", 1, true) then
		for s, e in line:gmatch("()%%%%.-%%%%()") do
			mark(buf, row, s - 1, e - 1, "NotesComment", 200)
		end
	end
	-- ^block-id
	local block = line:match("()%s%^[%w%-]+%s*$") or line:match("^()%^[%w%-]+%s*$")
	if block then
		mark(buf, row, block - 1, #line, "NotesBlockId")
	end
	-- key:: value and [key:: value]
	if line:find("::", 1, true) then
		local s, key = line:match("^%s*[-*+]?%s*()([%w_ %-]+)::%s")
		if s and #key < 40 then
			mark(buf, row, s - 1, s + #key + 1, "NotesField")
		end
		for a, b in line:gmatch("()[%[%(][%w_ %-]+::[^%]%)]*[%]%)]()") do
			mark(buf, row, a - 1, b - 1, "NotesField")
		end
	end
	-- Task metadata
	if line:match("^%s*[-*+]%s+%[.%]") then
		local done = line:match("^%s*[-*+]%s+%[[xX%-]%]") ~= nil
		for emoji, kind in pairs(EMOJI) do
			for s, date, e in line:gmatch("()" .. emoji .. "[\239\184\143]*%s*(%d%d%d%d%-%d%d%-%d%d)()") do
				local hl = "NotesMuted"
				if not done and kind == "due" or not done and kind == "scheduled" then
					hl = date < D.today() and "NotesOverdue" or date == D.today() and "NotesToday" or "NotesDate"
				end
				mark(buf, row, s - 1, e - 1, hl, 210)
			end
		end
		local s, e = line:match("()🔁[\239\184\143]*[%w%s]*%w()")
		if s then
			mark(buf, row, s - 1, e - 1, "NotesCyan", 210)
		end
	end
	-- Links to nowhere
	if line:find("[[", 1, true) then
		for _, link in ipairs(index.parse_links(line, row + 1)) do
			if link.target ~= "" and not index.resolve(link.target, nil) and not index.files[vim.fs.basename(link.target):lower()] then
				mark(buf, row, link.col - 1, link.stop, "NotesLinkMissing", 220)
			end
		end
	end
end

function M.setup()
	vim.api.nvim_set_decoration_provider(ns, {
		on_win = function(_, win, buf)
			return vim.bo[buf].filetype == "markdown" and vim.bo[buf].buftype == "" and vault.is_note(vim.api.nvim_buf_get_name(buf))
		end,
		on_line = function(...)
			pcall(on_line, ...)
		end,
	})
	vim.api.nvim_create_autocmd("BufWipeout", {
		group = vim.api.nvim_create_augroup("notes_decor", { clear = true }),
		callback = function(ev)
			fences[ev.buf] = nil
		end,
	})
end

return M
