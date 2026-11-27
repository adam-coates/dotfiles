-- Literature notes from Zotero: pick an item, get a note with its details, abstract
-- and PDF annotations. Reads Zotero's database, never writes to it. (Citation keys
-- and the rest are zotcite's.)

local settings = require("settings")
local util = require("notes.util")
local vault = require("notes.vault")

local M = {}

function M.database()
	local path = vim.fn.expand(settings.zotero.database)
	return vim.uv.fs_stat(path) and path or nil
end

local function query(sql)
	local db = M.database()
	if not db or vim.fn.executable("sqlite3") == 0 then
		return nil, "Zotero's database wasn't found (settings.zotero)"
	end
	-- immutable: readable while Zotero has it locked
	local res = vim.system({ "sqlite3", "-json", "file:" .. db .. "?mode=ro&immutable=1", sql }, { text = true }):wait(15000)
	if res.code ~= 0 then
		return nil, vim.trim(res.stderr or "sqlite3 failed")
	end
	local ok, rows = pcall(vim.json.decode, res.stdout ~= "" and res.stdout or "[]")
	return ok and rows or {}
end

local LIST = [[
select i.itemID as id, i.key as key, t.typeName as type,
  max(case when f.fieldName = 'title' then v.value end) as title,
  max(case when f.fieldName = 'date' then v.value end) as date,
  max(case when f.fieldName in ('publicationTitle','bookTitle','proceedingsTitle','publisher','websiteTitle') then v.value end) as venue,
  max(case when f.fieldName = 'DOI' then v.value end) as doi,
  max(case when f.fieldName = 'url' then v.value end) as url,
  max(case when f.fieldName = 'abstractNote' then v.value end) as abstract,
  max(case when f.fieldName = 'citationKey' then v.value end) as citekey,
  (select group_concat(name, '; ') from (select trim(coalesce(c.firstName,'') || ' ' || c.lastName) as name
     from itemCreators ic join creators c on c.creatorID = ic.creatorID
     where ic.itemID = i.itemID order by ic.orderIndex)) as authors,
  (select group_concat(lastName, '; ') from (select c.lastName as lastName
     from itemCreators ic join creators c on c.creatorID = ic.creatorID
     join creatorTypes ct on ct.creatorTypeID = ic.creatorTypeID
     where ic.itemID = i.itemID and ct.creatorType = 'author' order by ic.orderIndex)) as lastnames,
  (select group_concat(tg.name, '; ') from itemTags it join tags tg on tg.tagID = it.tagID where it.itemID = i.itemID) as tags
from items i
join itemTypes t on t.itemTypeID = i.itemTypeID
left join itemData d on d.itemID = i.itemID
left join fields f on f.fieldID = d.fieldID
left join itemDataValues v on v.valueID = d.valueID
where t.typeName not in ('attachment','note','annotation')
  and i.itemID not in (select itemID from deletedItems)
group by i.itemID
order by i.dateModified desc
]]

function M.items()
	local rows, err = query(LIST)
	if not rows then
		return nil, err
	end
	local function text(value)
		return type(value) == "string" and value or ""
	end
	return vim.tbl_map(function(row)
		return {
			id = row.id,
			key = row.key,
			type = row.type,
			title = text(row.title) ~= "" and row.title or "(untitled)",
			year = text(row.date):match("(%d%d%d%d)") or "",
			venue = text(row.venue),
			doi = text(row.doi),
			url = text(row.url),
			abstract = text(row.abstract),
			citekey = text(row.citekey),
			authors = vim.split(text(row.authors), "; ", { trimempty = true }),
			lastnames = vim.split(text(row.lastnames), "; ", { trimempty = true }),
			tags = vim.split(text(row.tags), "; ", { trimempty = true }),
		}
	end, rows)
end

--- Highlights and comments made in Zotero's PDF reader.
function M.annotations(id)
	local rows = query(([[
select a.type as type, a.text as text, a.comment as comment, a.color as color, a.pageLabel as page, i.key as key, att.key as pdf
from itemAnnotations a
join items i on i.itemID = a.itemID
join itemAttachments ia on ia.itemID = a.parentItemID
join items att on att.itemID = ia.itemID
where ia.parentItemID = %d
order by a.sortIndex]]):format(id)) or {}
	return vim.tbl_filter(function(row)
		return type(row.text) == "string" and row.text ~= "" or type(row.comment) == "string" and row.comment ~= ""
	end, rows)
end

local function surname(name)
	return name:match("(%S+)$") or name
end

function M.short(item)
	local n = #item.authors
	local who = n == 0 and "Unknown" or n == 1 and surname(item.authors[1]) or n == 2 and (surname(item.authors[1]) .. " & " .. surname(item.authors[2])) or (surname(item.authors[1]) .. " et al.")
	return who .. (item.year ~= "" and (" " .. item.year) or "")
end

local function yaml(text)
	return '"' .. text:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", " ") .. '"'
end

--- The note for an item, as text.
function M.render(item)
	local annotations = {}
	local last_page
	for _, a in ipairs(M.annotations(item.id)) do
		if a.page and a.page ~= last_page then
			last_page = a.page
		end
		local link = ("[p. %s](zotero://open-pdf/library/items/%s?annotation=%s)"):format(a.page or "?", a.pdf, a.key)
		if type(a.text) == "string" and a.text ~= "" then
			annotations[#annotations + 1] = "> " .. vim.trim(a.text):gsub("%s*\n%s*", " ") .. " " .. link
		else
			annotations[#annotations + 1] = "- " .. link
		end
		if type(a.comment) == "string" and a.comment ~= "" then
			annotations[#annotations + 1] = ""
			annotations[#annotations + 1] = "- " .. vim.trim(a.comment):gsub("%s*\n%s*", " ")
		end
		annotations[#annotations + 1] = ""
	end
	local vars = {
		title = item.title,
		citekey = item.citekey ~= "" and item.citekey or item.key,
		authors = table.concat(item.authors, ", "),
		authors_yaml = #item.authors > 0 and ("\n" .. table.concat(vim.tbl_map(function(a)
			return "  - " .. yaml(a)
		end, item.authors), "\n")) or " []",
		title_yaml = yaml(item.title),
		venue_yaml = yaml(item.venue),
		year = item.year,
		venue = item.venue,
		doi = item.doi,
		url = item.doi ~= "" and ("https://doi.org/" .. item.doi) or item.url,
		type = item.type,
		abstract = item.abstract ~= "" and item.abstract or "—",
		annotations = #annotations > 0 and vim.trim(table.concat(annotations, "\n")) or "*None yet.*",
		zotero = "zotero://select/library/items/" .. item.key,
	}
	local text = require("notes.template").render("literature", vars)
	if text == "" then
		text = ("---\ncitekey: %s\nyear: %s\ntags: [literature]\n---\n\n# %s\n\n%s\n\n## Annotations\n\n%s\n"):format(vars.citekey, vars.year, vars.title, vars.authors, vars.annotations)
	end
	return text
end

--- "Author et al. (Year) Title", the way the literature notes are named: two
--- authors as "A & B", ": " and "? " as " - ", and past 120 characters without
--- the subtitle (or cut at a word).
function M.note_name(item)
	local a = #(item.lastnames or {}) > 0 and item.lastnames or vim.tbl_map(surname, item.authors)
	local who = #a == 0 and "Unknown" or #a == 1 and a[1] or #a == 2 and (a[1] .. " & " .. a[2]) or (a[1] .. " et al.")
	local year = item.year ~= "" and item.year or "n.d."
	local title = item.title:gsub("[:?]%s+", " - "):gsub('[%*"\\/<>|%?#%^%[%]]', ""):gsub("%s+", " ")
	title = vim.trim(title):gsub("%.+$", "")
	local name = ("%s (%s) %s"):format(who, year, title)
	if vim.fn.strchars(name) > 120 and title:find(" - ", 1, true) then
		name = ("%s (%s) %s"):format(who, year, title:match("^(.-) %- "))
	end
	if vim.fn.strchars(name) > 120 then
		local cut = vim.fn.strcharpart(name, 0, 120)
		name = (cut:match("^(.*) ") or cut):gsub("[,;%- ]+$", "")
	end
	return name
end

--- The paper's literature note: the one with its citekey, or where a new one goes.
function M.path(item)
	if item.citekey ~= "" then
		for _, entry in ipairs(require("notes.index").all()) do
			if entry.fm and entry.fm.citekey == item.citekey then
				return entry.path
			end
		end
	end
	return vault.folder("literature") .. "/" .. util.filename(M.note_name(item)) .. ".md"
end

function M.pick()
	local items, err = M.items()
	if not items then
		return util.notify(err, "warn")
	end
	Snacks.picker.pick({
		title = "Zotero  (<CR> literature note, <C-l> cite, <C-o> open in Zotero)",
		items = vim.tbl_map(function(item)
			return { text = table.concat(item.authors, " ") .. " " .. item.year .. " " .. item.title .. " " .. item.citekey, item = item, preview = { text = M.render_preview(item), ft = "markdown" } }
		end, items),
		format = function(row)
			local item = row.item
			local exists = vim.uv.fs_stat(M.path(item)) ~= nil
			return {
				{ exists and "󰎞 " or "  ", "NotesGreen" },
				{ util.pad(util.truncate(M.short(item), 24), 25), "NotesYellow" },
				{ util.truncate(item.title, 90), "NotesText" },
			}
		end,
		preview = "preview",
		actions = {
			cite = function(picker, row)
				picker:close()
				if row and row.item.citekey ~= "" then
					vim.schedule(function()
						vim.api.nvim_put({ "[@" .. row.item.citekey .. "]" }, "c", true, true)
					end)
				end
			end,
			open_zotero = function(_, row)
				if row then
					vim.ui.open("zotero://select/library/items/" .. row.item.key)
				end
			end,
		},
		win = { input = { keys = { ["<C-l>"] = { "cite", mode = { "i", "n" } }, ["<C-o>"] = { "open_zotero", mode = { "i", "n" } } } } },
		confirm = function(picker, row)
			picker:close()
			if row then
				vim.schedule(function()
					local path = M.path(row.item)
					if not vim.uv.fs_stat(path) then
						util.write(path, M.render(row.item))
						require("notes.index").update(path)
					end
					vault.open(path)
				end)
			end
		end,
	})
end

function M.render_preview(item)
	return table.concat({
		"# " .. item.title,
		"",
		table.concat(item.authors, ", "),
		"",
		("*%s* %s"):format(item.venue, item.year),
		"",
		item.abstract ~= "" and item.abstract or "(no abstract)",
	}, "\n")
end

--- Add the annotations made since the note was written to its end.
function M.update_annotations()
	local entry = require("notes.index").buffer()
	local key = entry and entry.fm.citekey
	if not key then
		return util.notify("This note has no citekey property", "warn")
	end
	for _, item in ipairs(M.items() or {}) do
		if item.citekey == key or item.key == key then
			local text = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
			local new = {}
			for _, a in ipairs(M.annotations(item.id)) do
				if not text:find("annotation=" .. a.key, 1, true) then
					local link = ("[p. %s](zotero://open-pdf/library/items/%s?annotation=%s)"):format(a.page or "?", a.pdf, a.key)
					new[#new + 1] = ""
					new[#new + 1] = type(a.text) == "string" and a.text ~= "" and ("> " .. vim.trim(a.text):gsub("%s*\n%s*", " ") .. " " .. link) or ("- " .. link)
					if type(a.comment) == "string" and a.comment ~= "" then
						vim.list_extend(new, { "", "- " .. vim.trim(a.comment):gsub("%s*\n%s*", " ") })
					end
				end
			end
			if #new == 0 then
				return util.notify("No new annotations")
			end
			vim.api.nvim_buf_set_lines(0, -1, -1, false, new)
			return util.notify("Added new annotations at the end")
		end
	end
	util.notify("“" .. key .. "” isn't in Zotero", "warn")
end

return M
