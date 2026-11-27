-- blink.cmp source: @tomorrow, @next friday, @+3d and so on become a link to that
-- day's note, or a plain date.

local D = require("notes.date")

local source = {}

function source.new()
	return setmetatable({}, { __index = source })
end

function source:enabled()
	return vim.bo.filetype == "markdown"
end

function source:get_trigger_characters()
	return { "@" }
end

local WORDS = { "today", "tomorrow", "yesterday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday", "next week", "next month", "weekend", "end of month", "in 3 days", "in 2 weeks" }

function source:get_completions(ctx, callback)
	local before = ctx.line:sub(1, ctx.cursor[2])
	local at, query = before:match(".*%f[^%s%(%[]()@([%w%s%+%-./]*)$")
	if not at then
		at, query = before:match("^()@([%w%s%+%-./]*)$")
	end
	if not at or #query > 24 then
		return callback({ items = {}, is_incomplete_forward = false, is_incomplete_backward = false })
	end
	local words = vim.list_extend({}, WORDS)
	query = vim.trim(query:lower())
	if query ~= "" and D.parse(query) then
		table.insert(words, 1, query)
	end
	local items, seen = {}, {}
	local row = ctx.cursor[1] - 1
	local function add(word, text, label, order)
		items[#items + 1] = {
			label = "@" .. word,
			labelDetails = { description = label },
			filterText = "@" .. word,
			sortText = ("%03d"):format(order),
			kind = vim.lsp.protocol.CompletionItemKind.Event,
			textEdit = {
				newText = text,
				range = { start = { line = row, character = at - 1 }, ["end"] = { line = row, character = ctx.cursor[2] } },
			},
		}
	end
	for i, word in ipairs(words) do
		local iso = D.parse(word)
		if iso and not seen[word] then
			seen[word] = true
			local name = D.format(iso, require("settings").daily_format)
			add(word, "[[" .. name .. "]]", "󰌹 " .. D.human(iso) .. " " .. iso, i * 2)
			if i <= 3 then
				add(word, iso, "plain " .. iso, i * 2 + 1)
			end
		end
	end
	callback({ items = items, is_incomplete_forward = true, is_incomplete_backward = true })
end

return source
