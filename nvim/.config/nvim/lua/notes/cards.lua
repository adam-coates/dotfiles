-- Flashcards, in the format of Obsidian's Spaced Repetition plugin. A note tagged
-- #flashcards (or #flashcards/deck) can hold:
--
--   Question::Answer            one card
--   Term:::Meaning              two cards, one each way
--   A question                  a longer card, up to the next blank line
--   ?                           (?? for both ways)
--   The answer
--   Insulin is made in the ==pancreas==.     a gap to fill
--
-- The schedule is kept next to the card in a <!--SR:!date,interval,ease--> comment,
-- so it travels with the notes. (The existing plugins need telescope and image.nvim,
-- or keep the schedule in files of their own.)

local settings = require("settings")
local util = require("notes.util")
local vault = require("notes.vault")
local index = require("notes.index")
local D = require("notes.date")

local M = {}

local SR = "<!%-%-SR:(.-)%-%->"

-- Parsing ------------------------------------------------------------------------------

local function schedules(text)
	local out = {}
	for part in (text or ""):gmatch("!([^!]+)") do
		local date, interval, ease = part:match("^(%d%d%d%d%-%d%d%-%d%d),([%d.]+),([%d.]+)")
		if date then
			out[#out + 1] = { date = date, interval = tonumber(interval), ease = tonumber(ease) }
		end
	end
	return out
end

local function deck_of(entry)
	local base = settings.cards.tag:lower()
	for _, tag in ipairs(entry.tags) do
		local lower = tag:lower()
		if lower == base then
			return settings.cards.tag
		elseif vim.startswith(lower, base .. "/") then
			return tag
		end
	end
end

--- Cards in a list of lines. Each has the lines it is on (first..last), where its
--- schedule is (sr), and its sides: { front, back } with one schedule each.
function M.parse(lines, start)
	local cards, i, fence = {}, start or 1, false
	local function strip(line)
		return vim.trim((line:gsub(SR, "")))
	end
	local function next_sr(last)
		local line = lines[last + 1]
		return line and line:match("^%s*" .. SR .. "%s*$") and last + 1 or nil
	end
	while i <= #lines do
		local line = lines[i]
		if line:match("^%s*[`~][`~][`~]") then
			fence = not fence
		elseif not fence and line:match("%S") and not line:match("^#+%s") and not line:match("^%s*" .. SR .. "%s*$") then
			-- The paragraph this line starts
			local last = i
			while lines[last + 1] and lines[last + 1]:match("%S") and not lines[last + 1]:match("^#+%s") and not lines[last + 1]:match("^%s*[`~][`~][`~]") and not lines[last + 1]:match("^%s*" .. SR .. "%s*$") do
				last = last + 1
			end
			local sep
			for j = i + 1, last do
				if lines[j]:match("^%?%??%s*$") then
					sep = j
					break
				end
			end
			if sep then
				local front = table.concat(vim.list_slice(lines, i, sep - 1), "\n")
				local back = vim.trim((table.concat(vim.list_slice(lines, sep + 1, last), "\n"):gsub(SR, "")))
				local card = { first = i, last = last, sides = { { front = front, back = back } } }
				if vim.trim(lines[sep]) == "??" then
					card.sides[2] = { front = back, back = front }
				end
				card.sr = next_sr(last)
				card.inline = lines[last]:match(SR) and last or nil
				card.multi = true
				cards[#cards + 1] = card
			else
				for j = i, last do
					local text = strip(lines[j]):gsub("^[-*+]%s+", ""):gsub("^%d+[.)]%s+", "")
					local clean = text:gsub("`[^`]*`", function(s)
						return (" "):rep(#s)
					end)
					local a, b = clean:find(":::+")
					local both = a ~= nil
					if not a then
						a, b = clean:find("::", 1, true)
					end
					local card
					if a and a > 1 and text:sub(b + 1):match("%S") then
						local front, back = vim.trim(text:sub(1, a - 1)), vim.trim(text:sub(b + 1))
						card = { sides = { { front = front, back = back } } }
						if both then
							card.sides[2] = { front = back, back = front }
						end
					elseif clean:find("==[^=]+==") then
						card = { sides = {}, cloze = true }
						local n = select(2, clean:gsub("==[^=]+==", ""))
						for k = 1, n do
							local seen = 0
							local front = text:gsub("==([^=]+)==", function(word)
								seen = seen + 1
								return seen == k and "**[…]**" or word
							end)
							seen = 0
							local back = text:gsub("==([^=]+)==", function(word)
								seen = seen + 1
								return seen == k and ("==" .. word .. "==") or word
							end)
							card.sides[k] = { front = front, back = back }
						end
					end
					if card then
						card.first, card.last = j, j
						card.inline = lines[j]:match(SR) and j or nil
						card.sr = not card.inline and j == last and next_sr(j) or nil
						cards[#cards + 1] = card
					end
				end
			end
			i = last
		end
		i = i + 1
	end
	for _, card in ipairs(cards) do
		local at = card.inline or card.sr
		local list = at and schedules(lines[at]:match(SR)) or {}
		for k, side in ipairs(card.sides) do
			side.schedule = list[k]
		end
	end
	return cards
end

--- Every card in the vault: { entry, deck, card, side, n }.
function M.all(filter)
	local out = {}
	for _, entry in ipairs(index.refresh().all()) do
		local deck = deck_of(entry)
		if deck and (not filter or filter(deck, entry)) then
			local text = util.read(entry.path)
			for _, card in ipairs(M.parse(util.lines(text or ""), entry.body)) do
				for n, side in ipairs(card.sides) do
					out[#out + 1] = { entry = entry, deck = deck, card = card, side = side, n = n }
				end
			end
		end
	end
	return out
end

-- How many new cards were started today.
local function counter()
	local path = vim.fn.stdpath("state") .. "/notes-cards.json"
	local ok, data = pcall(vim.json.decode, util.read(path) or "{}")
	data = ok and data or {}
	return data[D.today()] or 0, function(n)
		util.write(path, vim.json.encode({ [D.today()] = n }))
	end
end

--- Cards to review now: due ones first, then new ones up to the daily limit.
function M.due(filter)
	local today = D.today()
	local due, new = {}, {}
	for _, item in ipairs(M.all(filter)) do
		if not item.side.schedule then
			new[#new + 1] = item
		elseif item.side.schedule.date <= today then
			due[#due + 1] = item
		end
	end
	table.sort(due, function(a, b)
		return a.side.schedule.date < b.side.schedule.date
	end)
	local started = counter()
	local n_due, n_new = #due, math.min(#new, math.max(0, settings.cards.new_per_day - started))
	return vim.list_extend(due, vim.list_slice(new, 1, n_new)), n_due, n_new
end

-- Scheduling (SM-2, with the same numbers as the Obsidian plugin) ------------------------

--- rating: 1 again, 2 hard, 3 good, 4 easy
function M.next_schedule(old, rating, today)
	today = today or D.today()
	local ease, interval
	if not old then
		ease = ({ 230, 230, 250, 270 })[rating]
		interval = ({ 0, 1, 3, 4 })[rating]
	else
		ease = old.ease
		local late = math.max(0, D.diff(old.date, today))
		if rating == 1 then
			ease, interval = math.max(130, ease - 20), 0
		elseif rating == 2 then
			ease = math.max(130, ease - 20)
			interval = math.max(1, (old.interval + late / 4) * 0.5)
		elseif rating == 3 then
			interval = math.max(1, (old.interval + late / 2) * ease / 100)
		else
			ease = ease + 20
			interval = math.max(2, (old.interval + late) * ease / 100 * 1.3)
		end
	end
	interval = math.min(36525, math.floor(interval * 10 + 0.5) / 10)
	return { date = D.add(today, math.floor(interval + 0.5), "day"), interval = interval, ease = ease }
end

--- Write the schedule of a card back into its note.
function M.store(item)
	local lines = util.lines(util.read(item.entry.path) or "")
	local buf = vim.fn.bufnr("^" .. vim.fn.escape(item.entry.path, "\\[]^$.*~") .. "$")
	local loaded = buf ~= -1 and vim.api.nvim_buf_is_loaded(buf)
	if loaded then
		lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	end
	-- Find the card again by its text; line numbers may have moved.
	local target
	for _, card in ipairs(M.parse(lines, 1)) do
		local side = card.sides[item.n]
		if side and side.front == item.side.front and side.back == item.side.back then
			target = card
			break
		end
	end
	if not target then
		return util.notify("That card changed in the meantime", "warn")
	end
	local parts = {}
	for n, side in ipairs(target.sides) do
		local s = n == item.n and item.side.schedule or side.schedule
		-- Siblings without a schedule yet get a placeholder in the past.
		s = s or { date = "2000-01-01", interval = 1, ease = 250 }
		parts[n] = ("!%s,%s,%d"):format(s.date, (("%.1f"):format(s.interval):gsub("%.0$", "")), s.ease)
	end
	local comment = "<!--SR:" .. table.concat(parts) .. "-->"
	if target.inline then
		local at = target.inline
		lines[at] = lines[at]:gsub(SR, (comment:gsub("%%", "%%%%")))
	elseif target.sr then
		lines[target.sr] = comment
	elseif target.multi then
		table.insert(lines, target.last + 1, comment)
	else
		lines[target.last] = lines[target.last]:gsub("%s+$", "") .. " " .. comment
	end
	if loaded then
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
		vim.api.nvim_buf_call(buf, function()
			vim.cmd("silent noautocmd update")
		end)
	else
		util.write(item.entry.path, table.concat(lines, "\n") .. "\n")
	end
	index.update(item.entry.path)
end

-- Reviewing -----------------------------------------------------------------------------

local function days(n)
	n = math.floor(n + 0.5)
	if n == 0 then
		return "now"
	elseif n < 30 then
		return n .. "d"
	elseif n < 365 then
		return (("%.1fmo"):format(n / 30.4):gsub("%.0mo", "mo"))
	end
	return (("%.1fy"):format(n / 365):gsub("%.0y", "y"))
end

function M.review(filter)
	local queue, due, new = M.due(filter)
	if #queue == 0 then
		return util.notify("No cards are due. Done for today.")
	end
	local total, done, shown = #queue, 0, false
	local buf, win = util.float({ "" }, { width = math.min(84, vim.o.columns - 6), height = 18, title = "󰘸 Review" })
	vim.bo[buf].filetype = "markdown"
	vim.wo[win].wrap, vim.wo[win].linebreak, vim.wo[win].conceallevel = true, true, 2
	vim.wo[win].spell = false

	local function set(lines)
		vim.bo[buf].modifiable = true
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
		vim.bo[buf].modifiable = false
	end
	local function draw()
		local item = queue[1]
		if not item then
			set({ "", "  Done. " .. done .. " cards reviewed." })
			vim.api.nvim_win_set_config(win, { title = " 󰘸 Review ", footer = " q close ", footer_pos = "center" })
			return
		end
		local lines = { "" }
		vim.list_extend(lines, util.lines(item.side.front))
		if shown then
			vim.list_extend(lines, { "", "---", "" })
			vim.list_extend(lines, util.lines(item.side.back))
		end
		set(lines)
		local footer = " <Space> show answer · e edit · s skip · q quit "
		if shown then
			local parts = {}
			for rating, label in ipairs({ "again", "hard", "good", "easy" }) do
				parts[rating] = ("%d %s %s"):format(rating, label, days(M.next_schedule(item.side.schedule, rating).interval))
			end
			footer = " " .. table.concat(parts, " · ") .. " "
		end
		vim.api.nvim_win_set_config(win, {
			title = { { " 󰘸 " .. item.deck:gsub("^[^/]+/", "") .. " ", "NotesTitle" }, { done .. "/" .. total .. " ", "NotesMuted" }, { item.side.schedule and "" or "new ", "NotesGreen" } },
			title_pos = "center",
			footer = footer,
			footer_pos = "center",
		})
		pcall(vim.api.nvim_win_set_cursor, win, { 1, 0 })
	end
	local function rate(rating)
		return function()
			local item = queue[1]
			if not item or not shown then
				return
			end
			local fresh = item.side.schedule == nil
			item.side.schedule = M.next_schedule(item.side.schedule, rating)
			M.store(item)
			if fresh then
				local n, save = counter()
				save(n + 1)
			end
			table.remove(queue, 1)
			if rating == 1 then -- again, a few cards from now
				table.insert(queue, math.min(#queue + 1, 4), item)
			else
				done = done + 1
			end
			shown = false
			draw()
		end
	end
	local function map(lhs, fn)
		vim.keymap.set("n", lhs, fn, { buffer = buf, nowait = true })
	end
	local function reveal()
		if not shown then
			shown = true
			draw()
		end
	end
	map("<Space>", reveal)
	map("<CR>", reveal)
	for rating = 1, 4 do
		map(tostring(rating), rate(rating))
	end
	map("s", function()
		table.insert(queue, table.remove(queue, 1))
		shown = false
		draw()
	end)
	map("e", function()
		local item = queue[1]
		if item then
			vim.api.nvim_win_close(win, true)
			vault.open(item.entry.path, { line = item.card.first })
		end
	end)
	draw()
	return { due = due, new = new }
end

--- Choose a deck first.
function M.decks()
	local decks, order, today = {}, {}, D.today()
	for _, item in ipairs(M.all()) do
		if not decks[item.deck] then
			decks[item.deck] = { name = item.deck, total = 0, due = 0, new = 0 }
			order[#order + 1] = decks[item.deck]
		end
		local deck = decks[item.deck]
		deck.total = deck.total + 1
		if not item.side.schedule then
			deck.new = deck.new + 1
		elseif item.side.schedule.date <= today then
			deck.due = deck.due + 1
		end
	end
	if #order == 0 then
		return util.notify("No cards yet. Tag a note #" .. settings.cards.tag .. " and write “Question::Answer”.")
	end
	table.sort(order, function(a, b)
		return a.name < b.name
	end)
	vim.ui.select(order, {
		prompt = "Deck",
		format_item = function(deck)
			return ("%-30s %3d due  %3d new  %3d cards"):format(deck.name, deck.due, deck.new, deck.total)
		end,
	}, function(deck)
		if deck then
			M.review(function(name)
				return name == deck.name
			end)
		end
	end)
end

function M.review_note()
	local path = vim.api.nvim_buf_get_name(0)
	M.review(function(_, entry)
		return entry.path == path
	end)
end

function M.stats()
	local total, due, new, young, mature = 0, 0, 0, 0, 0
	local ahead, today = {}, D.today()
	for _, item in ipairs(M.all()) do
		total = total + 1
		local s = item.side.schedule
		if not s then
			new = new + 1
		else
			if s.date <= today then
				due = due + 1
			end
			if s.interval >= 21 then
				mature = mature + 1
			else
				young = young + 1
			end
			local n = math.max(0, D.diff(today, s.date))
			if n < 14 then
				ahead[n] = (ahead[n] or 0) + 1
			end
		end
	end
	local rows = {
		{ { ("  %d cards"):format(total), "NotesTitle" } },
		{ { ("  %d due · %d new · %d young · %d mature"):format(due, new, young, mature), "NotesMuted" } },
		{ "" },
	}
	local most = 1
	for _, n in pairs(ahead) do
		most = math.max(most, n)
	end
	for n = 0, 13 do
		local day = D.add(today, n, "day")
		rows[#rows + 1] = {
			{ ("  %-10s "):format(n == 0 and "Today" or os.date("%a %d %b", D.time(day))), "NotesMuted" },
			{ ("█"):rep(math.ceil((ahead[n] or 0) / most * 30)), "NotesAccent" },
			{ " " .. (ahead[n] or 0), "NotesText" },
		}
	end
	local buf = util.float({ "" }, { width = 56, height = #rows, title = "Cards" })
	util.render(buf, vim.api.nvim_create_namespace("notes_cards"), rows)
end

return M
