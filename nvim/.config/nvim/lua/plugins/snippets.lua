-- Selection-aware replacements for friendly-snippets' Quarto and Markdown snippets.
--
-- Workflow: select text, press <C-s> (cuts it and enters insert mode), type the
-- trigger and expand. The selection lands inside the snippet. Without a selection
-- each snippet behaves like the original it replaces.
--
-- priority = 2000 makes these win over friendly-snippets' same-named snippets
-- (default priority 1000) when a trigger is expanded.
--
-- Snippets friendly-snippets already makes selection-aware are left alone:
--   quarto:   bold, italic, quote, code (inline), heading1-6, link, image,
--             strikethrough, div (.class), callout, fenced/executable/raw codeblock

local ls = require("luasnip")
local s, t, i, f, d, sn = ls.snippet, ls.text_node, ls.insert_node, ls.function_node, ls.dynamic_node, ls.snippet_node
local parse = ls.parser.parse_snippet

local PRIORITY = 2000

-- Selected lines (dedented), or nil if nothing was selected.
local function selection(parent)
	local lines = parent.snippet.env.LS_SELECT_DEDENT
	if type(lines) ~= "table" or #lines == 0 or (#lines == 1 and lines[1] == "") then
		return nil
	end
	return lines
end

local function prefixed(lines, prefix)
	local out = {}
	for n, line in ipairs(lines) do
		out[n] = line == "" and prefix:gsub("%s+$", "") or prefix .. line
	end
	return out
end

-- Selection with every line prefixed (blockquotes, alerts); just the prefix when empty.
local function prefix_lines(prefix)
	return f(function(_, parent)
		local lines = selection(parent)
		return lines and prefixed(lines, prefix) or { prefix }
	end)
end

-- Selection turned into a list with `make_prefix(n)` per line, or the original
-- three placeholder items when nothing was selected.
local function list(make_prefix)
	return d(1, function(_, parent)
		local lines = selection(parent)
		if lines then
			local out = {}
			for n, line in ipairs(lines) do
				out[n] = make_prefix(n) .. line
			end
			return sn(nil, { t(out) })
		end
		return sn(nil, {
			t(make_prefix(1)), i(1, "first"), t({ "", make_prefix(2) }),
			i(2, "second"), t({ "", make_prefix(3) }), i(3, "third"),
		})
	end)
end

-- VS Code-syntax snippet registered under each trigger.
local function wrap(triggers, desc, body)
	local out = {}
	for _, trig in ipairs(type(triggers) == "table" and triggers or { triggers }) do
		table.insert(out, parse({ trig = trig, desc = desc .. " (wraps selection)", priority = PRIORITY }, body))
	end
	return out
end

local function add(ft, groups)
	local all = {}
	for _, group in ipairs(groups) do
		vim.list_extend(all, group)
	end
	ls.add_snippets(ft, all)
end

-- Quarto only (filetype quarto; markdown files don't get these).
add("quarto", {
	-- Divs
	wrap("frag", "Fragment", "::: {.fragment}\n${TM_SELECTED_TEXT}$0\n:::"),
	wrap("notes", "Speaker notes", "::: {.notes}\n${TM_SELECTED_TEXT}$0\n:::"),
	wrap("aside", "Aside", "::: {.aside}\n${TM_SELECTED_TEXT}$0\n:::"),
	wrap("call", "Callout", "::: {.callout-$1}\n${TM_SELECTED_TEXT}$0\n:::"),
	wrap("pl", "Pull left", "::: {.pull-left}\n${TM_SELECTED_TEXT}$0\n:::"),
	wrap("pr", "Pull right", "::: {.pull-right}\n${TM_SELECTED_TEXT}$0\n:::"),
	wrap("con", "Container", "::: {.container}\n${TM_SELECTED_TEXT}$1\n:::"),
	wrap("inc", "Incremental list", "::: {.incremental}\n${TM_SELECTED_TEXT:-$1}\n:::"),
	wrap("noninc", "Non-incremental list", "::: {.nonincremental}\n${TM_SELECTED_TEXT:-$1}\n:::"),
	wrap("lay", "Layout", '::: {layout="[$1]"}\n${TM_SELECTED_TEXT}$0\n:::'),
	wrap("col2", "Two-column layout", "::: {layout-ncol=2}\n${TM_SELECTED_TEXT}$0\n:::"),
	wrap("col3", "Three-column layout", "::: {layout-ncol=3}\n${TM_SELECTED_TEXT}$0\n:::"),
	-- Columns: the selection goes in the first column.
	wrap("2col", "Two columns", "::: {.columns}\n::: {.column width=50%}\n${TM_SELECTED_TEXT}$1\n:::\n::: {.column width=50%}\n$2\n:::\n:::"),
	wrap("cols", "Columns", '::: {.columns}\n::: {.column width="$1"}\n${TM_SELECTED_TEXT}$2\n:::\n::: {.column width="$3"}\n$4\n:::\n:::'),
	-- Inline
	wrap("alert", "Alert span", "[${TM_SELECTED_TEXT}$0]{.alert}"),
	-- Code chunks
	wrap("pyc", "Python chunk", "```{python}\n${TM_SELECTED_TEXT}$1\n```"),
	wrap("rco", "R chunk", "```{r}\n${TM_SELECTED_TEXT}$1\n```"),
	wrap("bco", "Bash chunk", "```{bash}\n${TM_SELECTED_TEXT}$1\n```"),
})

-- Markdown (quarto inherits these through filetype_extend).
local alerts = {
	{ { "note", "n" }, "NOTE" },
	{ { "tip", "t" }, "TIP" },
	{ { "important", "imp" }, "IMPORTANT" },
	{ { "warning", "w" }, "WARNING" },
	{ { "caution", "c" }, "CAUTION" },
}
local alert_snippets = {}
for _, alert in ipairs(alerts) do
	for _, trig in ipairs(alert[1]) do
		table.insert(alert_snippets, s(
			{ trig = trig, desc = alert[2] .. " alert (wraps selection)", priority = PRIORITY },
			{ t({ "> [!" .. alert[2] .. "]", "" }), prefix_lines("> "), i(0) }
		))
	end
end

add("markdown", {
	alert_snippets,
	{ s({ trig = "quote", desc = "Blockquote (wraps selection)", priority = PRIORITY }, { prefix_lines("> "), i(0) }) },
	-- Lists: each selected line becomes an item.
	{ s({ trig = "unordered list", desc = "Bulleted list (wraps selection)", priority = PRIORITY }, { list(function() return "- " end), t({ "", "" }), i(0) }) },
	{ s({ trig = "ordered list", desc = "Numbered list (wraps selection)", priority = PRIORITY }, { list(function(n) return n .. ". " end), t({ "", "" }), i(0) }) },
	{ s({ trig = "task", desc = "Task (wraps selection)", priority = PRIORITY }, { list(function() return "- [ ] " end), t({ "", "" }), i(0) }) },
	{ s({ trig = "todo", desc = "Task (wraps selection)", priority = PRIORITY }, { list(function() return "- [ ] " end), t({ "", "" }), i(0) }) },
	-- Headings
	wrap("h1", "Heading 1", "# ${TM_SELECTED_TEXT}$0"),
	wrap("h2", "Heading 2", "## ${TM_SELECTED_TEXT}$0"),
	wrap("h3", "Heading 3", "### ${TM_SELECTED_TEXT}$0"),
	wrap("h4", "Heading 4", "#### ${TM_SELECTED_TEXT}$0"),
	wrap("h5", "Heading 5", "##### ${TM_SELECTED_TEXT}$0"),
	wrap("h6", "Heading 6", "###### ${TM_SELECTED_TEXT}$0"),
	-- Inline
	wrap({ "bold", "b" }, "Bold", "**${1:${TM_SELECTED_TEXT}}**$0"),
	wrap({ "italic", "i" }, "Italic", "*${1:${TM_SELECTED_TEXT}}*$0"),
	wrap({ "bold and italic", "bi" }, "Bold italic", "***${1:${TM_SELECTED_TEXT}}***$0"),
	wrap("strikethrough", "Strikethrough", "~~${1:${TM_SELECTED_TEXT}}~~$0"),
	wrap("code", "Inline code", "`${1:${TM_SELECTED_TEXT}}`$0"),
	wrap({ "link", "l" }, "Link", "[${TM_SELECTED_TEXT:${1:text}}](${2:url})$0"),
	wrap({ "url", "u" }, "Autolink", "<${1:${TM_SELECTED_TEXT}}>$0"),
	wrap("img", "Image", "![${TM_SELECTED_TEXT:${1:alt text}}](${2:path})$0"),
	wrap("sub", "Subscript", "<sub>${1:${TM_SELECTED_TEXT}}</sub>$0"),
	wrap("sup", "Superscript", "<sup>${1:${TM_SELECTED_TEXT}}</sup>$0"),
	-- Blocks
	wrap("codeblock", "Code block", "```${1:language}\n${TM_SELECTED_TEXT}$0\n```"),
})
