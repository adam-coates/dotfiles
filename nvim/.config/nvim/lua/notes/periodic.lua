-- Daily, weekly, monthly and yearly notes.

local settings = require("settings")
local D = require("notes.date")
local vault = require("notes.vault")

local M = {}

-- First day of the period a date is in.
local START = {
	daily = function(iso)
		return iso
	end,
	weekly = function(iso)
		return D.week_start(iso, 1)
	end,
	monthly = function(iso)
		return iso:sub(1, 7) .. "-01"
	end,
	yearly = function(iso)
		return iso:sub(1, 4) .. "-01-01"
	end,
}
local UNIT = { daily = "day", weekly = "week", monthly = "month", yearly = "year" }

function M.name(kind, iso)
	if kind == "daily" then
		return D.format(iso, settings.daily_format)
	elseif kind == "weekly" then
		if settings.weekly_format then
			return D.format(D.week_start(iso, 1), settings.weekly_format)
		end
		return D.week_id(iso)
	elseif kind == "monthly" then
		return iso:sub(1, 7)
	end
	return iso:sub(1, 4)
end

function M.path(kind, iso)
	return vault.folder(kind) .. "/" .. M.name(kind, iso) .. ".md"
end

function M.exists(kind, iso)
	return vim.uv.fs_stat(M.path(kind, iso)) ~= nil
end

--- The path, after creating the note from its template if needed.
function M.ensure(kind, iso)
	local start = START[kind](iso)
	local path = M.path(kind, kind == "daily" and iso or start)
	return vault.create(path, { template = kind, open = false, vars = { day = start } })
end

function M.open(kind, iso, opts)
	vault.open(M.ensure(kind, iso or D.today()), opts)
end

--- Kind and first day of a periodic note, from its path.
function M.identify(path)
	local rel = vault.rel(path)
	if not rel then
		return nil
	end
	local name = vim.fs.basename(rel):gsub("%.md$", "")
	for _, kind in ipairs({ "daily", "weekly", "monthly", "yearly" }) do
		if vim.startswith(rel, settings.folders[kind] .. "/") then
			if kind == "daily" then
				local iso = name:match("%d%d%d%d%-%d%d%-%d%d")
				if iso and D.valid(iso) then
					return kind, iso
				end
			elseif kind == "weekly" then
				local y, w = name:match("^(%d%d%d%d)%-W(%d%d)$")
				if y then
					return kind, D.add(D.week_start(y .. "-01-04", 1), (tonumber(w) - 1) * 7, "day")
				end
				-- Named after a day of the week (weekly_format), e.g. 2026_01_12
				local yy, mm, dd = name:match("^(%d%d%d%d)[-_.](%d%d)[-_.](%d%d)$")
				local iso = yy and (yy .. "-" .. mm .. "-" .. dd)
				if iso and D.valid(iso) then
					return kind, D.week_start(iso, 1)
				end
			elseif kind == "monthly" and name:match("^%d%d%d%d%-%d%d$") then
				return kind, name .. "-01"
			elseif kind == "yearly" and name:match("^%d%d%d%d$") then
				return kind, name .. "-01-01"
			end
		end
	end
end

--- The previous or next note of the same kind. From any other note, yesterday
--- or tomorrow. Skips to the nearest one that exists, unless `create`.
function M.step(direction, create)
	local kind, iso = M.identify(vim.api.nvim_buf_get_name(0))
	if not kind then
		return M.open("daily", D.add(D.today(), direction, "day"))
	end
	local target = D.add(iso, direction, UNIT[kind])
	if not create then
		local candidate = target
		for _ = 1, kind == "daily" and 400 or 60 do
			if M.exists(kind, candidate) then
				return M.open(kind, candidate)
			end
			candidate = D.add(candidate, direction, UNIT[kind])
		end
	end
	M.open(kind, target)
end

--- Pick among existing daily notes, newest first.
function M.pick(kind)
	local items = {}
	local prefix = settings.folders[kind] .. "/"
	for _, entry in ipairs(require("notes.index").all()) do
		if vim.startswith(entry.rel, prefix) then
			local _, iso = M.identify(entry.path)
			items[#items + 1] = { text = entry.name .. " " .. (iso and os.date("%A %d %B %Y", D.time(iso)) or ""), file = entry.path, name = entry.name, iso = iso or "" }
		end
	end
	table.sort(items, function(a, b)
		return a.iso > b.iso
	end)
	Snacks.picker.pick({
		title = kind:gsub("^%l", string.upper) .. " notes",
		items = items,
		format = function(item)
			return { { item.name, "NotesLink" }, { "  " .. (item.iso ~= "" and os.date("%A, %d %B", D.time(item.iso)) or ""), "NotesMuted" } }
		end,
		preview = "file",
		confirm = function(picker, item)
			picker:close()
			if item then
				vault.open(item.file)
			end
		end,
	})
end

return M
