-- nvim --headless -l ~/.config/nvim/tests/run.lua
--
-- Tests for the local modules, on a throwaway vault. Nothing else is touched.

local config = vim.fs.dirname(vim.fs.dirname(debug.getinfo(1, "S").source:sub(2)))
vim.opt.rtp:prepend(config)
vim.opt.rtp:append(vim.fn.stdpath("data") .. "/site/pack/core/opt/obsidian.nvim")

local root = vim.fn.tempname() .. "-vault"
vim.fn.mkdir(root, "p")
_G.Obsidian = { workspace = { root = root, name = "test" }, opts = {} }

local passed, failed = 0, {}
local function eq(got, want, what)
	if vim.deep_equal(got, want) then
		passed = passed + 1
	else
		failed[#failed + 1] = ("%s\n    want %s\n    got  %s"):format(what or "?", vim.inspect(want, { newline = " ", indent = "" }), vim.inspect(got, { newline = " ", indent = "" }))
	end
end
local function ok(value, what)
	eq(not not value, true, what)
end
local function write(rel, text)
	local path = root .. "/" .. rel
	vim.fn.mkdir(vim.fs.dirname(path), "p")
	local fd = assert(io.open(path, "w"))
	fd:write(text)
	fd:close()
	return path
end
local function read(rel)
	local fd = assert(io.open(root .. "/" .. rel))
	local text = fd:read("*a")
	fd:close()
	return text
end

-- Dates ---------------------------------------------------------------------------
local D = require("notes.date")
local wed = "2026-11-25" -- a Wednesday
for phrase, want in pairs({
	today = "2026-11-25", tomorrow = "2026-11-26", yesterday = "2026-11-24",
	friday = "2026-11-27", wednesday = "2026-12-02", mon = "2026-11-30",
	["next friday"] = "2026-12-04", ["last monday"] = "2026-11-23", ["last wednesday"] = "2026-11-18",
	["in 3 days"] = "2026-11-28", ["in a week"] = "2026-12-02", ["two weeks ago"] = "2026-11-11",
	["+3d"] = "2026-11-28", ["-1w"] = "2026-11-18", ["2w"] = "2026-12-09", ["next week"] = "2026-12-02",
	["next month"] = "2026-12-25", ["1 dec"] = "2026-12-01", ["Dec 1"] = "2026-12-01", ["1st December 2027"] = "2027-12-01",
	["3 nov"] = "2027-11-03", ["2026-12-31"] = "2026-12-31", ["31.12.2026"] = "2026-12-31", ["5/1/2027"] = "2027-01-05",
	["end of month"] = "2026-11-30", eow = "2026-11-29", weekend = "2026-11-28", ["day after tomorrow"] = "2026-11-27",
}) do
	eq(D.parse(phrase, wed), want, "date: " .. phrase)
end
for _, phrase in ipairs({ "banana", "31 feb", "2026-13-01", "in some days", "maybe", "" }) do
	eq(D.parse(phrase, wed), nil, "not a date: " .. phrase)
end
eq(D.add("2026-01-31", 1, "month"), "2026-02-28", "month end")
eq(D.add("2024-02-29", 1, "year"), "2025-02-28", "leap year")
eq(D.add("2026-03-28", 2, "day"), "2026-03-30", "across summer time")
eq(D.diff("2026-03-28", "2026-03-30"), 2, "diff across summer time")
eq(D.add("2026-11-25", -25, "day"), "2026-10-31", "back a month")
eq(D.week_id("2027-01-01"), "2026-W53", "ISO week year")
eq(D.week_start(wed, 1), "2026-11-23", "week start")
eq(D.week_start("2026-11-29", 1), "2026-11-23", "Sunday belongs to the week before")
eq(D.week_start("2026-11-29", 0), "2026-11-29", "weeks from Sunday")
eq({ D.extract("Call Anna tomorrow #phone", wed) }, { "2026-11-26", "Call Anna #phone" }, "extract")
eq({ D.extract("Report due next friday", wed) }, { "2026-12-04", "Report" }, "extract with lead word")
eq({ D.extract("Submit by 1 dec", wed) }, { "2026-12-01", "Submit" }, "extract a date")
eq({ D.extract("Meet May about the sun", wed) }, {}, "names aren't dates")
eq({ D.extract("Talk to him on mon", wed) }, { "2026-11-30", "Talk to him" }, "short weekday after on")

-- Tasks ------------------------------------------------------------------------------
local T = require("notes.tasks")
local task = T.parse("Write intro #thesis ⏫ 🔁 every week ⏳ 2026-11-27 📅 2026-11-30", " ")
eq({ task.text, task.due, task.scheduled, task.priority, task.recur, task.tags }, { "Write intro #thesis", "2026-11-30", "2026-11-27", 2, "every week", { "thesis" } }, "parse a task")
eq(T.parse("Pay [due:: 2026-12-01] [priority:: high]", " ").due, "2026-12-01", "dataview format")
eq(T.parse("Pay [due:: 2026-12-01] [priority:: high]", " ").priority, 2, "dataview priority")
eq(T.parse("Card @{2026-12-01}", " ").due, "2026-12-01", "kanban date")
eq(T.parse("With variation selector 🗓️ 2026-12-01", " ").due, "2026-12-01", "variation selector")
eq(T.parse("No metadata", " ").priority, 4, "normal priority")
eq(T.toggle("- [ ] Plain", wed), { "- [x] Plain ✅ 2026-11-25" }, "complete")
eq(T.toggle("- [x] Plain ✅ 2026-11-25", wed), { "- [ ] Plain" }, "undo complete")
eq(T.toggle("- [ ] Block ^abc", wed), { "- [x] Block ✅ 2026-11-25 ^abc" }, "block id stays last")
eq(T.toggle("  * [/] Started", wed), { "  * [x] Started ✅ 2026-11-25" }, "in progress to done")
eq(T.toggle("1. [ ] Numbered", wed), { "1. [x] Numbered ✅ 2026-11-25" }, "numbered")
eq(T.toggle("not a task", wed), { "not a task" }, "not a task")
eq(T.toggle("- [ ] Review 🔁 every week 📅 2026-11-27", wed), { "- [ ] Review 🔁 every week 📅 2026-12-04", "- [x] Review 🔁 every week 📅 2026-11-27 ✅ 2026-11-25" }, "recurring")
eq(T.toggle("- [ ] A 🔁 every month 🛫 2026-11-20 ⏳ 2026-11-25 📅 2026-11-30", wed)[1], "- [ ] A 🔁 every month 🛫 2026-12-20 ⏳ 2026-12-25 📅 2026-12-30", "all dates move")
eq(T.toggle("- [ ] Water 🔁 every 3 days when done 📅 2026-11-01", wed)[1], "- [ ] Water 🔁 every 3 days when done 📅 2026-11-28", "when done counts from today")
eq(T.toggle("- [ ] R 🔁 every day 📅 2026-11-25 ^id", wed), { "- [ ] R 🔁 every day 📅 2026-11-26", "- [x] R 🔁 every day 📅 2026-11-25 ✅ 2026-11-25 ^id" }, "block id stays with the original")
for rule, want in pairs({
	["every day"] = "2026-11-26", ["every 2 days"] = "2026-11-27", ["every week"] = "2026-12-02", ["every 2 weeks"] = "2026-12-09",
	["every weekday"] = "2026-11-26", ["every monday"] = "2026-11-30", ["every tuesday, friday"] = "2026-11-27",
	["every week on Sunday"] = "2026-11-29", ["every 2 weeks on Monday"] = "2026-12-07", ["every month on the 1st"] = "2026-12-01",
	["every month on the last"] = "2026-12-31", ["every month"] = "2026-12-25", ["every year"] = "2027-11-25", ["every other week"] = "2026-12-09",
	["every quarter"] = "2027-02-25",
}) do
	eq(T.next_date(rule, wed), want, "rule: " .. rule)
end
eq(T.next_date("every blue moon", wed), nil, "unknown rule")
eq(T.next_date("every weekday", "2026-11-27"), "2026-11-30", "weekday skips the weekend")
eq(T.next_date("every month", "2026-01-31"), "2026-02-28", "monthly at month end")
eq(T.set_date("- [ ] A 📅 2026-01-01 #x", "due", "2026-02-02"), "- [ ] A 📅 2026-02-02 #x", "change a date")
eq(T.set_date("- [ ] A 📅 2026-01-01 #x", "due", nil), "- [ ] A #x", "remove a date")
eq(T.set_date("- [ ] A [due:: 2026-01-01]", "due", "2026-02-02"), "- [ ] A [due:: 2026-02-02]", "keep the dataview format")
eq(T.set_date("- [ ] A @{2026-01-01}", "due", "2026-02-02"), "- [ ] A @{2026-02-02}", "keep the kanban format")
eq(T.set_priority("- [ ] A ⏫ 📅 2026-01-01", 3), "- [ ] A 📅 2026-01-01 🔼", "change priority")
eq(T.set_priority("- [ ] A ⏫", 4), "- [ ] A", "remove priority")
eq(T.set_recur("- [ ] A 🔁 every week 📅 2026-01-01", "every day"), "- [ ] A 📅 2026-01-01 🔁 every day", "change the rule")
eq(T.from_text("Call Anna tomorrow !high #phone", wed), "- [ ] Call Anna #phone ⏫ 📅 2026-11-26", "task from text")
eq(T.from_text("Water the plants every 3 days", wed), "- [ ] Water the plants 🔁 every 3 days 📅 2026-11-27", "recurring from text")
eq(T.from_text("Standup every weekday #work", wed), "- [ ] Standup #work 🔁 every weekday 📅 2026-11-25", "weekday from text")
eq(T.from_text("Read every paper on replay", wed), "- [ ] Read every paper on replay", "every isn't always a rule")
eq(T.from_text("What a day!", wed), "- [ ] What a day!", "exclamation marks")
eq(T.insert_under({ "# A", "", "## Tasks", "", "- [ ] one", "  more", "", "## B" }, "Tasks", { "- [ ] two" }), { "# A", "", "## Tasks", "", "- [ ] one", "  more", "- [ ] two", "", "## B" }, "insert after the list")
eq(T.insert_under({ "## Tasks", "", "## B" }, "Tasks", { "- x" }), { "## Tasks", "", "- x", "", "## B" }, "insert in an empty section")
eq(T.insert_under({ "## Tasks" }, "Tasks", { "- x" }), { "## Tasks", "", "- x" }, "insert at the very end")
eq(T.insert_under({ "text", "" }, "Tasks", { "- x" }), { "text", "", "## Tasks", "", "- x" }, "insert a new section")
eq(T.insert_under({ "## Tasks", "", "- a", "", "para", "", "- b" }, "tasks", { "- x" }), { "## Tasks", "", "- a", "- x", "", "para", "", "- b" }, "stay in the first list")

-- Index --------------------------------------------------------------------------------
write("Alpha.md", table.concat({
	"---", "aliases: [First, The Start]", "tags: [project, area/work]", "status: active", "rating: 4", "due: 2026-12-01", "up: \"[[Beta]]\"", "---", "",
	"# Alpha", "", "Links to [[Beta]], [[Beta|the second]], [[Sub/Gamma#Part one]] and [[Nowhere]].", "Inline #inline/tag and `#nottag [[Notlink]]`, http://x.y/#frag", "",
	"key one:: some value", "Text with [inner:: 12] field.", "", "```", "#code [[Code]] - [ ] not a task", "```", "", "![[pic.png]] and [md](Sub/Gamma.md) and [web](https://example.com)", "",
	"- [ ] open task #todo 📅 2026-11-30", "\t- [ ] child", "- [x] done task ✅ 2026-11-20", "A paragraph to refer to. ^ref1", "",
}, "\n"))
write("Beta.md", "# Beta\n\nBack to [[First]] and mentions Gamma here. Also alpha in lower case.\n")
write("Sub/Gamma.md", "---\ntags: project\nrating: 2\n---\n# Gamma\n\n## Part one\n\nText of part one.\n\n### Deeper\n\nMore.\n\n## Part two\n\nEnd. [[Alpha]]\n")
write("Sub/Alpha.md", "# The other Alpha\n\nSee [[Alpha]].\n")
write("Orphan.md", "Nothing here but #lonely.\n")
write("Templates/t.md", "# {{title}} [[Beta]] #template\n\n- [ ] template task\n")
write("pic.png", "x")
local index = require("notes.index").refresh()
local alpha = index.get("Alpha.md")
eq(alpha.aliases, { "First", "The Start" }, "aliases")
eq(alpha.tags, { "project", "area/work", "inline/tag", "todo" }, "tags")
eq({ alpha.fields["key one"], alpha.fields.inner }, { "some value", "12" }, "inline fields")
eq(#alpha.tasks, 3, "tasks, not those in code")
write("Bullets.md", "- [?] q\n- [i] i\n- [ ] t\n")
eq(#index.refresh().get("Bullets.md").tasks, 1, "fancy bullets are not tasks")
vim.uv.fs_unlink(root .. "/Bullets.md")
index.refresh()
eq({ alpha.tasks[1].due, alpha.tasks[2].indent, alpha.tasks[3].done }, { "2026-11-30", 4, "2026-11-20" }, "task details")
eq(alpha.blocks, { ref1 = 27 }, "block ids")
eq(vim.tbl_map(function(l) return l.target end, alpha.links), { "Beta", "Beta", "Beta", "Sub/Gamma", "Nowhere", "pic.png", "Sub/Gamma" }, "links, not those in code")
eq(index.resolve("first").rel, "Alpha.md", "resolve an alias")
eq(index.resolve("Gamma").rel, "Sub/Gamma.md", "resolve a name")
eq(index.resolve("sub/gamma").rel, "Sub/Gamma.md", "resolve a path")
eq(index.resolve("Alpha").rel, "Alpha.md", "shortest path wins")
eq(index.resolve("Alpha", index.get("Sub/Alpha.md")).rel, "Alpha.md", "an exact path wins, as in Obsidian")
eq(index.resolve("./Alpha", index.get("Sub/Gamma.md")).rel, "Alpha.md", "leading ./")
eq(index.resolve("Nope"), nil, "resolve nothing")
eq(#index.backlinks(index.get("Beta.md")), 3, "backlinks with duplicates and properties")
eq(vim.tbl_map(function(h) return h.link.target end, index.broken()), { "Nowhere" }, "broken links")
eq(vim.tbl_map(function(e) return e.rel end, index.orphans()), { "Orphan.md" }, "orphans")
eq(#index.tags().project, 2, "tag counts")
ok(index.tags().area, "parent tags")
eq(index.tags().template, nil, "templates are left out")
local mentions
index.mentions(index.get("Sub/Gamma.md"), function(list) mentions = list end)
vim.wait(4000, function() return mentions ~= nil end)
eq(vim.tbl_map(function(m) return m.entry.rel .. ":" .. m.word end, mentions or {}), { "Beta.md:Gamma" }, "unlinked mentions")
-- Changes
write("Beta.md", "# Beta\n\nNo links now, and longer than before.\n")
index.update(root .. "/Beta.md")
eq(#index.backlinks(index.get("Alpha.md")), 2, "backlinks after a change")
vim.uv.fs_unlink(root .. "/Sub/Alpha.md")
index.update(root .. "/Sub/Alpha.md")
eq(#index.backlinks(index.get("Alpha.md")), 1, "backlinks after a deletion")
eq(index.get("Sub/Alpha.md"), nil, "a deleted note is gone")

-- Dataview ------------------------------------------------------------------------------
local Q = require("notes.query.dql")
local X = require("notes.query.expr")
local function rows(text)
	local r = Q.query(text, index.get("Alpha.md"))
	if r.error then
		return "error: " .. r.error
	end
	return vim.tbl_map(function(row)
		return table.concat(vim.tbl_map(X.tostring, row.cells), "|")
	end, r.rows)
end
eq(rows("LIST FROM #project"), { "Alpha", "Gamma" }, "list by tag")
eq(rows('LIST FROM "Sub"'), { "Gamma" }, "list by folder")
eq(rows("LIST FROM #area"), { "Alpha" }, "list by parent tag")
eq(rows("LIST FROM #project AND -\"Sub\""), { "Alpha" }, "source operators")
eq(rows("LIST FROM [[Alpha]]"), { "Gamma" }, "inlinks")
eq(rows("LIST FROM outgoing([[Alpha]])"), { "Beta", "Gamma" }, "outlinks")
eq(rows("TABLE rating, status AS \"State\" FROM #project SORT rating ASC"), { "Gamma|2|—", "Alpha|4|active" }, "table and sort")
eq(rows("TABLE WITHOUT ID file.name FROM #project WHERE rating > 2"), { "Alpha" }, "where")
eq(rows("LIST FROM #project WHERE status"), { "Alpha" }, "truthiness")
eq(rows("LIST FROM #project WHERE !status"), { "Gamma" }, "negation")
eq(rows("LIST WHERE contains(file.tags, \"#area\")"), { "Alpha" }, "contains a tag")
eq(rows("LIST rating * 2 + 1 FROM #project SORT rating DESC LIMIT 1"), { "Alpha|9" }, "arithmetic and limit")
eq(rows("LIST WHERE due > date(2026-11-01) AND due <= date(2026-12-01)"), { "Alpha" }, "dates")
eq(rows("LIST WHERE due - date(2026-11-25) <= dur(1 week)"), { "Alpha" }, "durations")
eq(rows('LIST WHERE key-one = "some value"'), { "Alpha" }, "inline fields, hyphenated")
eq(rows("LIST WHERE inner = 12"), { "Alpha" }, "numbers in inline fields")
eq(rows("LIST WHERE up = [[Beta]]"), { "Alpha" }, "link equality")
eq(rows("LIST up.file.name WHERE up"), { "Alpha|Beta" }, "through a link")
eq(rows('LIST WHERE regextest("^B", file.name)'), { "Beta" }, "regex")
eq(rows('LIST upper(file.name) WHERE startswith(file.name, "Be")'), { "Beta|BETA" }, "functions")
eq(rows("TABLE length(rows) FROM #project GROUP BY status"), { "—|1", "active|1" }, "group by")
eq(rows("TABLE WITHOUT ID t.text FLATTEN file.tasks AS t WHERE !t.completed AND t.due"), { "open task #todo 📅 2026-11-30" }, "flatten")
eq(rows("LIST length(filter(file.tasks, (t) => !t.completed)) FROM #project WHERE file.tasks"), { "Alpha|2" }, "lambdas")
eq(rows("LIST choice(rating > 3, \"good\", \"meh\") FROM #project SORT file.name"), { "Alpha|good", "Gamma|meh" }, "choice")
eq(rows("LIST FROM #project // a comment\nSORT file.name DESC"), { "Gamma", "Alpha" }, "comments")
eq(rows("LIST WHERE file.name = this.file.name"), { "Alpha" }, "this")
eq(rows("LIST FROM #project WHERE (rating = 2 or rating = 4) and file.folder = \"Sub\""), { "Gamma" }, "precedence")
eq(Q.query("TASK FROM #project WHERE !completed").count, 2, "task query")
eq(Q.query("TASK WHERE due").groups[1].name, "Alpha", "task groups")
ok(Q.query("SELECT * FROM x").error, "unknown query")
ok(Q.query("LIST WHERE (").error, "syntax error")
ok(Q.query("LIST nofunc(1)").error:find("nofunc"), "unknown function")
ok(Q.query('LIST FROM "unfinished').error, "unfinished string")
eq(Q.inline("this.rating + 1", alpha), "5", "inline")
eq(Q.inline("this.file.tags", alpha), "#project, #area, #area/work, #inline, #inline/tag, #todo", "inline list")
eq(select(2, Q.inline("1 +", alpha)) ~= nil, true, "inline error")

-- Tasks queries ---------------------------------------------------------------------------
write("Work.md", table.concat({
	"# Work", "", "## One", "",
	"- [ ] late ⏫ 📅 2020-01-01 #a", "- [ ] soon 📅 2030-01-01 #b", "- [ ] nodate #a/sub", "- [x] gone ✅ 2026-11-20 📅 2026-11-21",
	"## Two", "- [/] busy 🔁 every day 🛫 2020-01-01", "- [-] cancelled ❌ 2026-11-01", "- [ ] low 🔽",
}, "\n"))
index.refresh()
local TQ = require("notes.query.tasksq")
local function texts(query)
	local r = TQ.query(query)
	if r.error then
		return "error: " .. r.error
	end
	local out = {}
	for _, g in ipairs(r.groups) do
		for _, row in ipairs(g.tasks) do
			out[#out + 1] = row.task.text:match("^%S+")
		end
	end
	return out
end
eq(texts("path includes Work\nnot done\nsort by description"), { "busy", "late", "low", "nodate", "soon" }, "not done")
eq(texts("path includes Work\ndone\nsort by description"), { "cancelled", "gone" }, "done")
eq(texts("path includes Work\ndue before 2026-01-01"), { "late" }, "due before")
eq(texts("path includes Work\nhas due date\nnot done\nsort by due"), { "late", "soon" }, "has due date")
eq(texts("path includes Work\nno due date\nnot done\nsort by description"), { "busy", "low", "nodate" }, "no due date")
eq(texts("path includes Work\n(tags include #a) OR (description includes soon)\nsort by description"), { "late", "nodate", "soon" }, "boolean")
eq(texts("path includes Work\nnot done\nNOT (tags include #a)\nsort by description"), { "busy", "low", "soon" }, "NOT")
eq(texts("path includes Work\n(not done) AND (heading includes Two) AND NOT (is recurring)"), { "low" }, "AND NOT")
eq(texts("path includes Work\npriority is above none"), { "late" }, "priority above")
eq(texts("path includes Work\npriority is low"), { "low" }, "priority is")
eq(texts("path includes Work\nis recurring"), { "busy" }, "recurring")
eq(texts("path includes Work\nstatus.type is IN_PROGRESS"), { "busy" }, "status type")
eq(texts("path includes Work\ndone 2026-11-20"), { "gone" }, "done on")
eq(texts("path includes Work\ndone in 2026-11"), { "gone" }, "done in a month")
eq(texts("path includes Work\ndone in 2026-11-16 2026-11-22"), { "gone" }, "done in a range")
eq(texts("path includes Work\ndescription regex matches /^l/\nsort by description"), { "late", "low" }, "regex")
eq(texts("path includes Work\nnot done\nsort by due reverse\nlimit 1"), { "nodate" }, "sort reverse and limit")
eq(#TQ.query("path includes Work\nnot done\ngroup by heading").groups, 2, "group by")
eq(TQ.query("path includes Work\nnot done\ngroup by due").groups[3].name, "No due date", "no date comes last")
ok(TQ.query("do the laundry").error, "unknown instruction")
eq(texts("path includes Alpha\nexclude sub-items\nnot done"), { "open" }, "sub-items")
eq(texts("# only a comment\npath includes Orphan"), {}, "nothing")

-- Editing where it is written ----------------------------------------------------------------
local work = index.get("Work.md")
T.edit(work.path, work.tasks[1].line, work.tasks[1].raw, T.toggle)
ok(read("Work.md"):find("- [x] late ⏫ 📅 2020-01-01 #a ✅ " .. D.today(), 1, true), "toggle in a file")
eq(index.get("Work.md").tasks[1].status, "x", "index follows")
local before = read("Work.md")
vim.notify = function() end
T.edit(work.path, 5, "- [ ] this line isn't there", T.toggle)
eq(read("Work.md"), before, "never edits the wrong line")
write("Work2.md", "inserted\n- [ ] moved\n")
T.edit(root .. "/Work2.md", 1, "- [ ] moved", T.toggle)
eq(read("Work2.md"), "inserted\n- [x] moved ✅ " .. D.today() .. "\n", "finds a line that moved")

-- Kanban ------------------------------------------------------------------------------------
local K = require("notes.kanban")
local board = {
	"---", "", "kanban-plugin: board", "tags: [keep]", "", "---", "", "## Backlog", "", "- [ ] one", "\tsecond line", "- [ ] two @{2026-12-01}", "", "", "## Done", "", "**Complete**", "- [x] three", "", "", "***", "", "## Archive", "", "- [x] old", "", "%% kanban:settings", "```", "{}", "```", "%%",
}
local columns = K.parse(board)
eq(vim.tbl_map(function(c) return c.title end, columns), { "Backlog", "Done" }, "columns, not the archive")
eq({ columns[1].cards[1].first, columns[1].cards[1].last, #columns[1].cards }, { 10, 11, 2 }, "cards with several lines")
eq(columns[2].complete, true, "complete column")

-- Flashcards -----------------------------------------------------------------------------------
local C = require("notes.cards")
local cards = C.parse({
	"# Deck", "", "What is 2+2?::4", "Haus:::house <!--SR:!2026-11-01,3,250!2026-11-02,4,270-->", "- in a list::yes", "",
	"A longer", "question", "?", "With an answer", "in two lines", "<!--SR:!2026-12-01,10,250-->", "", "Both ways", "??", "Other side", "",
	"The ==heart== has ==four== chambers.", "`code::not a card`", "```", "in::code", "```", "plain text",
})
eq(#cards, 6, "cards found")
eq({ cards[1].sides[1].front, cards[1].sides[1].back, #cards[1].sides }, { "What is 2+2?", "4", 1 }, "one card")
eq({ cards[2].sides[2].front, cards[2].sides[2].schedule.interval, cards[2].inline }, { "house", 4, 4 }, "both ways with a schedule")
eq(cards[3].sides[1].front, "in a list", "list marker removed")
eq({ cards[4].sides[1].front, cards[4].sides[1].back, cards[4].sides[1].schedule.date }, { "A longer\nquestion", "With an answer\nin two lines", "2026-12-01" }, "longer card")
eq(#cards[5].sides, 2, "longer card, both ways")
eq({ #cards[6].sides, cards[6].sides[1].front, cards[6].sides[2].back }, { 2, "The **[…]** has four chambers.", "The heart has ==four== chambers." }, "gaps")
eq(C.next_schedule(nil, 3, wed), { date = "2026-11-28", interval = 3, ease = 250 }, "a new card, good")
eq(C.next_schedule(nil, 1, wed).date, wed, "a new card, again")
eq(C.next_schedule({ date = wed, interval = 10, ease = 250 }, 3, wed), { date = "2026-12-20", interval = 25, ease = 250 }, "good grows by the ease")
eq(C.next_schedule({ date = wed, interval = 10, ease = 250 }, 2, wed), { date = "2026-11-30", interval = 5, ease = 230 }, "hard shrinks")
eq(C.next_schedule({ date = wed, interval = 10, ease = 130 }, 1, wed).ease, 130, "ease has a floor")
ok(C.next_schedule({ date = wed, interval = 10, ease = 250 }, 4, wed).interval > 25, "easy grows more")
write("Deck.md", "---\ntags: [flashcards/test]\n---\n\nQ1::A1\nWort:::word\n\nLong q\n?\nLong a\n\nA ==gap== here.\n")
local all = C.all()
eq({ #all, all[1].deck }, { 5, "flashcards/test" }, "cards of a deck")
for _, item in ipairs(all) do
	item.side.schedule = { date = "2026-12-24", interval = 12.5, ease = 260 }
	C.store(item)
end
eq(read("Deck.md"), "---\ntags: [flashcards/test]\n---\n\nQ1::A1 <!--SR:!2026-12-24,12.5,260-->\nWort:::word <!--SR:!2026-12-24,12.5,260!2026-12-24,12.5,260-->\n\nLong q\n?\nLong a\n<!--SR:!2026-12-24,12.5,260-->\n\nA ==gap== here. <!--SR:!2026-12-24,12.5,260-->\n", "schedules are written back")
local again = C.all()
eq({ #again, again[4].side.schedule.interval, again[4].side.front }, { 5, 12.5, "Long q" }, "and read again")

-- Refactoring -------------------------------------------------------------------------------------
local R = require("notes.refactor")
eq(R.rename_tag_in({ "---", "tags: [old, older, old/sub]", "other: old", "---", "Text #old, #older #old/sub (#old) x#old", "```", "#old", "```" }, "old", "new", 5), { "---", "tags: [new, older, new/sub]", "other: old", "---", "Text #new, #older #new/sub (#new) x#old", "```", "#old", "```" }, "rename a tag")
eq(R.rename_tag_in({ "---", "tags:", "  - old", "  - keep", "title: old", "---", "#Old" }, "old", "a/b", 7), { "---", "tags:", "  - a/b", "  - keep", "title: old", "---", "#a/b" }, "rename in a list of tags")
local buf = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "---", "a: 1", "tags:", "  - x", "b: 2", "---", "text" })
R.set_property("tags", "[y]", buf)
R.set_property("c", "3", buf)
eq(vim.api.nvim_buf_get_lines(buf, 0, -1, false), { "---", "a: 1", "tags: [y]", "b: 2", "c: 3", "---", "text" }, "set a property")
vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "# No properties" })
R.set_property("a", "1", buf)
eq(vim.api.nvim_buf_get_lines(buf, 0, -1, false), { "---", "a: 1", "---", "", "# No properties" }, "add properties")

-- Sections, export, templates, capture ------------------------------------------------------------------
local H = require("notes.hover")
local gamma = index.get("Sub/Gamma.md")
eq(H.section(gamma, "Part one"), { "## Part one", "", "Text of part one.", "", "### Deeper", "", "More.", "" }, "a section with its children")
eq(H.section(index.get("Alpha.md"), "^ref1")[1], "A paragraph to refer to. ^ref1", "a block")
local E = require("notes.export")
local out = E.prepare({ "---", "a: 1", "---", "==hi== %%secret%% text ^id", "[[Beta|two]] and [[Gamma]]", "> [!warning] Careful", "> body", "%%", "hidden", "%%", "![[Sub/Gamma#Part two]]", "```dataview", "LIST FROM #project", "```", "after" }, alpha)
eq(out, { "[hi]{.mark}  text", "two and Gamma", "> **Careful**", "> ", "> body", "## Part two", "", "End. Alpha", "", "- Alpha", "- Gamma", "", "after" }, "prepare for pandoc")
local tpl = require("notes.template")
eq(tpl.substitute("{{date:YYYY}} {{title}} {{week}} {{yesterday}} {{ tomorrow:DD }} {{unknown}}", { title = "T" }, wed), "2026 T 2026-W48 2026-11-24 26 {{unknown}}", "template variables")
eq(tpl.substitute("{{last_month}} {{next_month}} {{week_start}} {{week_end}}", nil, "2026-01-31"), "2025-12 2026-02 2026-01-26 2026-02-01", "period variables")
local P = require("notes.periodic")
write("Templates/daily.md", "# {{date:dddd D MMMM}}\n\n[[{{yesterday}}]]\n\n## Tasks\n\n## Log\n")
local settings = require("settings")
local daily = P.ensure("daily", "2026-11-20")
eq(read(settings.folders.daily .. "/2026-11-20.md"), "# Friday 20 November\n\n[[2026-11-19]]\n\n## Tasks\n\n## Log\n", "a daily note is about its own day")
eq({ P.identify(daily) }, { "daily", "2026-11-20" }, "identify a daily note")
eq({ P.identify(root .. "/" .. settings.folders.weekly .. "/2026-W53.md") }, { "weekly", "2026-12-28" }, "identify a weekly note")
eq(P.name("weekly", "2027-01-01"), "2026-W53", "weekly name across years")
local Cap = require("notes.capture")
Cap.to_daily({ "A thought", "continued", "- [ ] a task" })
local today_text = read(settings.folders.daily .. "/" .. D.today() .. ".md")
ok(today_text:find("## Tasks\n\n- [ ] a task", 1, true), "captured task")
ok(today_text:find("## Log\n\n%- %d%d:%d%d A thought\n  continued"), "captured text")
local note = Cap.to_note({ "# My: new/idea?", "body" })
eq(vim.fs.basename(note), "My new idea.md", "safe file names")
eq(vim.fs.basename(Cap.to_note({ "# My: new/idea?", "body" })), "My new idea 2.md", "never overwrites")

-- Calendar ---------------------------------------------------------------------------------------------
local cal_rows, at = require("notes.calendar").rows("2026-11")
eq(#cal_rows, 8, "weeks of November 2026")
eq(at(3, 4 + 6 * 4), "2026-11-01", "first Sunday")
eq(select(2, at(8, 1)), "2026-12-03", "the week number finds the week")

-- Blocks -------------------------------------------------------------------------------------------------
local B = require("notes.blocks")
local found = B.find({ "```tasks", "not done", "```", "", "````markdown", "```dataview", "LIST", "```", "````", "```dataview", "LIST", "```" })
eq(vim.tbl_map(function(b) return b.lang .. b.first .. "-" .. b.last end, found), { "tasks1-3", "dataview10-12" }, "blocks, not those inside other fences")
for _, line in ipairs(B.draw(Q.query("TABLE rating FROM #project", alpha), 30)) do
	local width = 0
	for _, chunk in ipairs(line) do
		width = width + vim.fn.strdisplaywidth(chunk[1])
	end
	ok(width <= 30, "tables fit")
end

-- Canvas ------------------------------------------------------------------------------------------------
local Cv = require("notes.canvas")
local cbuf = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(cbuf, 0, -1, false, { "# Topic", "", "Intro text", "", "## Plan", "", "- One", "  - One a", "  - One b", "- [ ] Two", "\t- Two a", "1. Three", "", "after" })
local tree, after = Cv.outline(cbuf, 7, 12)
eq({ tree.text, #tree.children, tree.children[1].children[2].text, tree.children[2].text, tree.children[2].children[1].text, tree.children[3].text, after }, { "Plan", 3, "One b", "Two", "Two a", "Three", 12 }, "outline of a list")
local svg = write("Canvas/A.svg", '<svg version="1.1" xmlns="http://www.w3.org/2000/svg"><!-- svg-source:excalidraw --><metadata></metadata></svg>')
ok(Cv.is_canvas(svg), "a canvas is recognised")
ok(not Cv.is_canvas(write("Attachments/plain.svg", "<svg></svg>")), "a plain SVG isn't a canvas")
local copy = Cv.image_path(svg)
ok(copy and vim.uv.fs_stat(copy) and copy ~= svg, "a canvas is drawn from a versioned copy")
eq(Cv.image_path(root .. "/Attachments/plain.svg"), nil, "other images are left alone")

-- Todoist ------------------------------------------------------------------------------------------------
local Td = require("notes.todoist")
Td.cache.projects = { p1 = "Thesis" }
local row = Td.row({ id = "X1", content = "Reply", project_id = "p1", priority = 4, labels = { "mail" }, checked = false, due = { date = "2026-12-01T15:00:00", datetime = "2026-12-01T15:00:00", string = "every monday", is_recurring = true } })
eq({ row.task.due, row.task.priority, row.task.recur, row.task.text, row.task.time, row.entry.name }, { "2026-12-01", 2, "every monday", "Reply #mail", "15:00", "󰄵 Thesis" }, "a Todoist task as a row")
eq(Td.row({ id = "X2", content = "Plain", project_id = "zz", priority = 1, labels = {} }).task.priority, 4, "normal priority")
eq(Td.quick_text("- [ ] Draft the email #thesis ⏫ 📅 2026-12-01"), "Draft the email @thesis {2026-12-01} p1", "quick add text")
eq(Td.quick_text("- [ ] Water 🔁 every week 📅 2026-12-01"), "Water {2026-12-01} every week", "quick add with a rule")
eq(Td.quick_text("- [ ] Start ⏳ 2026-11-28 📅 2026-12-01 🔽"), "Start 2026-11-28 {2026-12-01} p3", "scheduled and due")

eq(Td.parse_block("today | overdue"), { filter = "today | overdue", sorting = {} }, "a bare filter")
eq(Td.parse_block('name: "Today & overdue"\nfilter: "today | overdue"\nsorting:\n  - priority\n  - dateDescending'), { name = "Today & overdue", filter = "today | overdue", sorting = { "priority", "dateDescending" } }, "Obsidian Todoist plugin YAML")
eq(Td.parse_block("filter: '#{{filename}}'\nsorting: [date, priority]", { name = "Thesis" }), { filter = "#Thesis", sorting = { "date", "priority" } }, "filename and inline sorting")

-- Locations, weekly names, per-vault settings ------------------------------------------------------
local L = require("notes.location")
local folders = { "00 - Inbox", "01 - Library", "01 - Library/Literature Notes", "03 - Logs/Meetings/claustrum_meetings",
	"03 - Logs/Meetings/claustrum_meetings/2025", "04 - Archive/3rd_paper", "02 - Writing/Thesis", "04 - Archive/Thesis" }
eq(L.resolve("01 - Library", folders), "01 - Library", "location: a top folder")
eq(L.resolve("Literature Notes", folders), "01 - Library/Literature Notes", "location: a folder's name")
eq(L.resolve("claustrum_meetings/2025", folders), "03 - Logs/Meetings/claustrum_meetings/2025", "location: the end of a path")
eq(L.resolve(" literature notes/ ", folders), "01 - Library/Literature Notes", "location: any case, trailing slash")
eq({ L.resolve("Thesis", folders) }, { nil, { "02 - Writing/Thesis", "04 - Archive/Thesis" } }, "location: two folders fit")
eq(L.resolve("", folders), nil, "location: empty")
eq(L.resolve("Nowhere", folders), nil, "location: no folder of that name")

local settings = require("settings")
write("Templates/locnote.md", "---\ntitle: {{title}}\ntags: {{tags}}\nlocation: {{location}}\n---\n")
require("notes.vault").create(root .. "/00 - Inbox/Filed.md", { template = "locnote", open = false, vars = { tags = "[a, b]" } })
eq(read("00 - Inbox/Filed.md"), "---\ntitle: Filed\ntags: [a, b]\nlocation: 00 - Inbox\n---\n", "a new note's location is its folder")
write("01 - Library/.keep", "")
index.refresh()
eq({ L.move("01 - Library", nil, root .. "/00 - Inbox/Filed.md") }, { true }, "moving a note")
eq(read("01 - Library/Filed.md"), "---\ntitle: Filed\ntags: [a, b]\nlocation: 01 - Library\n---\n", "moving updates its location")
eq(vim.uv.fs_stat(root .. "/00 - Inbox/Filed.md"), nil, "and it's gone from the inbox")
eq(L.move("01 - Library", nil, root .. "/01 - Library/Filed.md"), false, "already there")

local P = require("notes.periodic")
settings.weekly_format = "YYYY_MM_DD"
eq(P.name("weekly", "2026-11-26"), "2026_11_23", "weekly note named after its Monday")
eq({ P.identify(root .. "/" .. settings.folders.weekly .. "/2026_01_12.md") }, { "weekly", "2026-01-12" }, "and recognised by it")
eq(require("notes.template").substitute("[[{{week}}]] [[{{last_week}}]]", nil, "2026-11-26"), "[[2026_11_23]] [[2026_11_16]]", "{{week}} links to it")
settings.weekly_format = nil
eq(P.name("weekly", "2026-11-26"), "2026-W48", "ISO weeks otherwise")

local per = require("notes.vault").settings_for({ folders = { inbox = "00 - Inbox" }, templates = { weekly = "weekly review" }, weekly_format = "YYYY_MM_DD", ask_location = true })
eq({ per.folders.inbox, per.folders.daily, per.templates.weekly, per.templates.note, per.weekly_format, per.ask_location },
	{ "00 - Inbox", settings.folders.daily, "weekly review", "note", "YYYY_MM_DD", true }, "a vault's settings over the defaults")
eq(require("notes.vault").settings_for(nil).weekly_format, nil, "defaults for an unknown vault")

local F = require("notes.figure")
eq(F.relative("/v/00 - Inbox", "/v/999-extra/Attachments/plot.svg"), "../999-extra/Attachments/plot.svg", "figure link from a folder")
eq(F.relative("/v", "/v/Attachments/plot.svg"), "Attachments/plot.svg", "figure link from the top")
eq(F.relative("/v/a/b", "/v/a/plot.svg"), "../plot.svg", "figure link one up")

vim.fn.delete(root, "rf")
print(("%d passed, %d failed"):format(passed, #failed))
for _, message in ipairs(failed) do
	print("  FAIL " .. message)
end
os.exit(#failed == 0 and 0 or 1)
