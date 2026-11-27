-- Dates as "YYYY-MM-DD" strings: they sort, compare and print as they are.

local M = {}

local MONTHS = {
	january = 1, february = 2, march = 3, april = 4, may = 5, june = 6, july = 7,
	august = 8, september = 9, october = 10, november = 11, december = 12,
	jan = 1, feb = 2, mar = 3, apr = 4, jun = 6, jul = 7, aug = 8, sep = 9, sept = 9,
	oct = 10, nov = 11, dec = 12,
}
local DAYS = {
	sunday = 1, monday = 2, tuesday = 3, wednesday = 4, thursday = 5, friday = 6, saturday = 7,
	sun = 1, mon = 2, tue = 3, tues = 3, wed = 4, thu = 5, thur = 5, thurs = 5, fri = 6, sat = 7,
}
local NUMBERS = {
	a = 1, an = 1, one = 1, two = 2, three = 3, four = 4, five = 5, six = 6, seven = 7,
	eight = 8, nine = 9, ten = 10, eleven = 11, twelve = 12,
}
local UNITS = {
	d = "day", day = "day", days = "day",
	w = "week", wk = "week", week = "week", weeks = "week",
	m = "month", mo = "month", month = "month", months = "month",
	q = "quarter", quarter = "quarter", quarters = "quarter",
	y = "year", yr = "year", year = "year", years = "year",
}

-- Noon, so that daylight saving never moves us to another day.
function M.time(iso)
	local y, m, d = iso:match("^(%d%d%d%d)-(%d%d)-(%d%d)")
	if not y then
		return nil
	end
	return os.time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12 })
end

function M.iso(time)
	return os.date("%Y-%m-%d", time) --[[@as string]]
end

function M.today()
	return M.iso(os.time())
end

function M.is(text)
	return type(text) == "string" and text:match("^%d%d%d%d%-%d%d%-%d%d$") ~= nil and M.valid(text)
end

function M.valid(iso)
	local t = M.time(iso)
	return t ~= nil and M.iso(t) == iso:sub(1, 10)
end

function M.days_in_month(y, m)
	return tonumber(os.date("%d", os.time({ year = y, month = m + 1, day = 0, hour = 12 })))
end

--- Add `n` days, weeks, months, quarters or years. Months keep to the month's
--- end (31 January + 1 month = 28 February).
function M.add(iso, n, unit)
	local y, m, d = iso:match("^(%d+)-(%d+)-(%d+)")
	y, m, d = tonumber(y), tonumber(m), tonumber(d)
	unit = UNITS[unit] or unit
	if unit == "week" then
		n, unit = n * 7, "day"
	elseif unit == "quarter" then
		n, unit = n * 3, "month"
	elseif unit == "year" then
		n, unit = n * 12, "month"
	end
	if unit == "day" then
		return M.iso(os.time({ year = y, month = m, day = d + n, hour = 12 }))
	end
	local months = y * 12 + (m - 1) + n
	y, m = math.floor(months / 12), months % 12 + 1
	return ("%04d-%02d-%02d"):format(y, m, math.min(d, M.days_in_month(y, m)))
end

--- Whole days from `a` to `b`.
function M.diff(a, b)
	return math.floor((M.time(b) - M.time(a)) / 86400 + 0.5)
end

--- 1 Sunday ... 7 Saturday
function M.wday(iso)
	return tonumber(os.date("%w", M.time(iso))) + 1
end

--- Monday (or Sunday) of the week `iso` is in.
function M.week_start(iso, first)
	first = first or require("settings").week_start
	local offset = (M.wday(iso) - 1 - first) % 7
	return M.add(iso, -offset, "day")
end

--- ISO week, as "2026-W48".
function M.week_id(iso)
	return os.date("%G-W%V", M.time(iso)) --[[@as string]]
end

--- Moment-style formatting ("dddd, D MMMM YYYY"), as used in Obsidian.
function M.format(iso, fmt)
	local ok, date = pcall(require, "obsidian.date")
	if ok then
		return tostring(date.format(M.time(iso), fmt))
	end
	return iso
end

--- "Tomorrow", "Fri 28 Nov", "3 days ago"
function M.human(iso, today)
	today = today or M.today()
	local n = M.diff(today, iso)
	if n == 0 then
		return "Today"
	elseif n == 1 then
		return "Tomorrow"
	elseif n == -1 then
		return "Yesterday"
	elseif n > 1 and n < 7 then
		return os.date("%A", M.time(iso))
	elseif n < 0 and n > -14 then
		return (-n) .. " days ago"
	end
	local fmt = iso:sub(1, 4) == today:sub(1, 4) and "%a %d %b" or "%d %b %Y"
	return (os.date(fmt, M.time(iso)):gsub(" 0", " "))
end

local function count(text)
	return tonumber(text) or NUMBERS[text]
end

local function ymd(y, m, d)
	y, m, d = tonumber(y), tonumber(m), tonumber(d)
	if not (y and m and d) or m < 1 or m > 12 or d < 1 or d > M.days_in_month(y, m) then
		return nil
	end
	return ("%04d-%02d-%02d"):format(y, m, d)
end

-- The next `wday` after `iso` (never `iso` itself).
local function next_day(iso, wday)
	local n = (wday - M.wday(iso)) % 7
	return M.add(iso, n == 0 and 7 or n, "day")
end

-- A day and month without a year: this year, or next year once it has passed.
local function upcoming(today, m, d)
	local y = tonumber(today:sub(1, 4))
	local date = ymd(y, m, d)
	if date and date < today then
		date = ymd(y + 1, m, d)
	end
	return date
end

--- Parse a whole phrase ("next friday", "in 3 weeks", "1 dec", "+2d") into a
--- date. Returns nil when the phrase isn't a date.
function M.parse(text, today)
	today = today or M.today()
	text = vim.trim(text):lower():gsub(",", " "):gsub("%s+", " ")
	text = text:gsub("(%d)st%f[%A]", "%1"):gsub("(%d)nd%f[%A]", "%1"):gsub("(%d)rd%f[%A]", "%1"):gsub("(%d)th%f[%A]", "%1")

	local simple = {
		today = 0, tod = 0, now = 0, tonight = 0,
		tomorrow = 1, tom = 1, tmr = 1, tmrw = 1,
		yesterday = -1,
		["day after tomorrow"] = 2, ["the day after tomorrow"] = 2, ["day before yesterday"] = -2,
	}
	if simple[text] then
		return M.add(today, simple[text], "day")
	end

	-- 2026-12-01, 2026/12/1, 1.12.2026, 1/12/2026 (day first)
	local y, m, d = text:match("^(%d%d%d%d)[-/.](%d%d?)[-/.](%d%d?)$")
	if y then
		return ymd(y, m, d)
	end
	d, m, y = text:match("^(%d%d?)[./](%d%d?)[./](%d%d%d%d)$")
	if d then
		return ymd(y, m, d)
	end
	d, m = text:match("^(%d%d?)%.(%d%d?)%.?$")
	if d then
		return upcoming(today, tonumber(m), tonumber(d))
	end

	-- +3d, -2w, 10d
	local sign, n, unit = text:match("^([+-]?)(%d+) ?(%a+)$")
	if n and UNITS[unit] then
		return M.add(today, (sign == "-" and -1 or 1) * tonumber(n), unit)
	end
	-- in 3 days, in a week, 3 days ago, 2 weeks from now
	n, unit = text:match("^in (%w+) (%a+)$")
	if n and count(n) and UNITS[unit] then
		return M.add(today, count(n), unit)
	end
	n, unit = text:match("^(%w+) (%a+) ago$")
	if n and count(n) and UNITS[unit] then
		return M.add(today, -count(n), unit)
	end
	n, unit = text:match("^(%w+) (%a+) from now$")
	if n and count(n) and UNITS[unit] then
		return M.add(today, count(n), unit)
	end

	-- friday, this friday, next friday, last friday
	local which, day = text:match("^(%a+) (%a+)$")
	if not which then
		which, day = nil, text
	end
	if DAYS[day] then
		if which == nil or which == "this" or which == "coming" or which == "on" then
			return next_day(today, DAYS[day])
		elseif which == "next" then
			-- The one in next week, not the one in the coming days.
			return M.add(M.week_start(M.add(M.week_start(today, 1), 7, "day"), 1), (DAYS[day] - 2) % 7, "day")
		elseif which == "last" then
			local back = (M.wday(today) - DAYS[day]) % 7
			return M.add(today, -(back == 0 and 7 or back), "day")
		end
	end
	if which and (which == "next" or which == "last") and UNITS[day] then
		return M.add(today, which == "next" and 1 or -1, day)
	end

	if text == "weekend" or text == "this weekend" then
		return M.wday(today) == 7 and today or next_day(today, 7)
	elseif text == "eow" or text == "end of week" or text == "end of the week" then
		return M.add(M.week_start(today, 1), 6, "day")
	elseif text == "eom" or text == "end of month" or text == "end of the month" then
		local ty, tm = tonumber(today:sub(1, 4)), tonumber(today:sub(6, 7))
		return ymd(ty, tm, M.days_in_month(ty, tm))
	elseif text == "eoy" or text == "end of year" or text == "end of the year" then
		return today:sub(1, 4) .. "-12-31"
	end

	-- 1 dec, 1 december 2026, dec 1, december 1 2026
	local dd, mon, yy = text:match("^(%d%d?) (%a+) ?(%d*)$")
	if not dd then
		mon, dd, yy = text:match("^(%a+) (%d%d?) ?(%d*)$")
	end
	if dd and MONTHS[mon] then
		if yy ~= "" and #yy == 4 then
			return ymd(yy, MONTHS[mon], dd)
		elseif yy == "" then
			return upcoming(today, MONTHS[mon], tonumber(dd))
		end
	end
	return nil
end

-- Single words that are a date on their own inside a sentence. Short ones like
-- "sat", "mon" or "may" only count after due/by/on.
local STANDALONE = {
	today = true, tonight = true, tomorrow = true, yesterday = true, tmr = true, tmrw = true,
	monday = true, tuesday = true, wednesday = true, thursday = true, friday = true,
	saturday = true, sunday = true, eow = true, eom = true, eoy = true,
}
local LEAD = { due = true, by = true, on = true, at = true, ["until"] = true, before = true }

--- Find a date phrase in a sentence. Returns the date and the sentence without
--- it, or nil.
function M.extract(text, today)
	local words = vim.split(text, "%s+", { trimempty = true })
	for size = math.min(4, #words), 1, -1 do
		for i = #words - size + 1, 1, -1 do
			local phrase = table.concat(words, " ", i, i + size - 1)
			local lead = i > 1 and LEAD[words[i - 1]:lower()] or false
			local date = M.parse(phrase, today)
			if date and size == 1 then
				local word = phrase:lower()
				if not (lead or STANDALONE[word] or word:match("^%d%d%d%d%-%d%d?%-%d%d?$") or word:match("^%+%d+%a$")) then
					date = nil
				end
			end
			if date then
				local rest = {}
				for j, word in ipairs(words) do
					if j < (lead and i - 1 or i) or j > i + size - 1 then
						rest[#rest + 1] = word
					end
				end
				return date, table.concat(rest, " ")
			end
		end
	end
	return nil
end

return M
