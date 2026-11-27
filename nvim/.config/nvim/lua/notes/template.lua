-- Templates, for the notes obsidian.nvim doesn't create itself (weekly notes,
-- boards, literature notes, ...). Same {{variables}} as everywhere else.

local settings = require("settings")
local util = require("notes.util")
local D = require("notes.date")

local M = {}

local function period(iso)
	local monday = D.week_start(iso, 1)
	return monday, D.add(monday, 6, "day")
end

--- Variables available in every template, as functions of (date, suffix). Also
--- handed to obsidian.nvim, so {{yesterday}} works in its templates too.
M.variables = {
	date = function(iso, fmt)
		return D.format(iso, fmt or settings.daily_format)
	end,
	time = function(_, fmt)
		if fmt then
			local ok, date = pcall(require, "obsidian.date")
			if ok then
				return tostring(date.format(os.time(), fmt))
			end
		end
		return os.date("%H:%M")
	end,
	yesterday = function(iso, fmt)
		return D.format(D.add(iso, -1, "day"), fmt or settings.daily_format)
	end,
	tomorrow = function(iso, fmt)
		return D.format(D.add(iso, 1, "day"), fmt or settings.daily_format)
	end,
	weekday = function(iso)
		return os.date("%A", D.time(iso))
	end,
	week = function(iso)
		return require("notes.periodic").name("weekly", iso) -- the weekly note's name
	end,
	month = function(iso)
		return iso:sub(1, 7)
	end,
	year = function(iso)
		return iso:sub(1, 4)
	end,
	last_week = function(iso)
		return require("notes.periodic").name("weekly", D.add(iso, -7, "day"))
	end,
	next_week = function(iso)
		return require("notes.periodic").name("weekly", D.add(iso, 7, "day"))
	end,
	last_month = function(iso)
		return D.add(iso:sub(1, 7) .. "-01", -1, "month"):sub(1, 7)
	end,
	next_month = function(iso)
		return D.add(iso:sub(1, 7) .. "-01", 1, "month"):sub(1, 7)
	end,
	week_start = function(iso, fmt)
		return D.format((period(iso)), fmt or "YYYY-MM-DD")
	end,
	week_end = function(iso, fmt)
		local _, sunday = period(iso)
		return D.format(sunday, fmt or "YYYY-MM-DD")
	end,
	vault = function()
		return require("notes.vault").name()
	end,
}

--- The seven days of a week as a bullet list of links, for weekly notes.
M.variables.week_days = function(iso)
	local monday, out = period(iso), {}
	for i = 0, 6 do
		local day = D.add(monday, i, "day")
		out[#out + 1] = ("- [[%s|%s]]"):format(D.format(day, settings.daily_format), D.format(day, "ddd D MMM"))
	end
	return table.concat(out, "\n")
end

--- Replace {{variables}} in text. vars: extra strings; date: the day it's about.
function M.substitute(text, vars, date)
	date = date or D.today()
	return (text:gsub("{{%s*([%w_]+):?([^}]*)}}", function(name, suffix)
		suffix = suffix ~= "" and vim.trim(suffix) or nil
		if vars and vars[name] ~= nil then
			return tostring(vars[name])
		elseif M.variables[name] then
			return M.variables[name](date, suffix)
		end
		return nil -- unknown: left as it is
	end))
end

function M.path(key)
	local name = settings.templates[key] or key
	if not name then
		return nil
	end
	local path = vim.fs.joinpath(require("notes.vault").folder("templates"), name .. ".md")
	return vim.uv.fs_stat(path) and path or nil
end

function M.render(key, vars, date)
	local path = key and M.path(key)
	local text = path and util.read(path) or ""
	return M.substitute(text, vars, date or (vars and vars.day))
end

return M
