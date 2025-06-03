local extras = require("luasnip.extras")
local ls = require("luasnip")

local c = ls.choice_node
local d = ls.dynamic_node
local f = ls.function_node
local i = ls.insert_node
local s = ls.snippet
local t = ls.text_node
local sn = ls.snippet_node

local p = extras.partial
local rep = extras.rep
local fmta = require("luasnip.extras.fmt").fmta
local line_begin = require("luasnip.extras.expand_conditions").line_begin

local function get_current_datetime(offset_hours)
	local date_table = os.date("*t")
	date_table.hour = date_table.hour + (offset_hours or 0)
	return os.date("%Y-%m-%dT%H:%M:%S", os.time(date_table))
end

return {
	s(
		{ trig = "fm", dscr = "Front matter" },
		fmta(
			[[
                ---
                fontsize: 12pt
                geometry: margin=3cm

                title: <>
                author: <>
                date: <>
                ---
            ]],
			{
				i(1),
				i(2, "Adam Coates"),
				p(os.date, "%d/%m/%Y"),
			}
		),
		{ condition = line_begin }
	),
	s(
		{ trig = "fmn", dscr = "Front matter for notes" },
		fmta(
			[[
                ---
                title: <>
                tags:
                  - <>
                date: <>
                ---

                # <>
            ]],
			{
				i(1),
				i(2),
				p(os.date, "%d/%m/%Y"),
				i(3),
			}
		),
		{ condition = line_begin }
	),

	s({ trig = "table(%d+)x(%d+)", regTrig = true, snippetType = 'autosnippet' }, {
		---@diagnostic disable-next-line: unused-local
		d(1, function(args, snip)
			local nodes = {}
			local i_counter = 0
			local hlines = ""
			for _ = 1, snip.captures[2] do
				i_counter = i_counter + 1
				table.insert(nodes, t("| "))
				table.insert(nodes, i(i_counter, "Column" .. i_counter))
				table.insert(nodes, t(" "))
				hlines = hlines .. "|---"
			end
			table.insert(nodes, t({ "|", "" }))
			hlines = hlines .. "|"
			table.insert(nodes, t({ hlines, "" }))
			for _ = 1, snip.captures[1] do
				for _ = 1, snip.captures[2] do
					i_counter = i_counter + 1
					table.insert(nodes, t("| "))
					table.insert(nodes, i(i_counter))
					table.insert(nodes, t(" "))
				end
				table.insert(nodes, t({ "|", "" }))
			end
			return sn(nil, nodes)
		end),
	}),
	s(
		{ trig = "event", dscr = "YAML Event Snippet" },
		fmta(
			[[
            ---
            event:
              summary: "<>"
              start: "<>"
              end: "<>"
              location: "<>"
              description: "<>"
              timezone: "<>"
              color: <>
            ---
            ]],
			{
				i(1), -- Summary placeholder
				i(2, get_current_datetime(0)), -- Current date and time for start
				i(3, get_current_datetime(1)), -- Current date and time + 1 hour for end
				i(4), -- Location placeholder
				i(5), -- Description placeholder
				i(6, "CET"), -- Timezone placeholder (default to UTC)
				i(7, "7"),
			}
		)
	),

	-- Note-taking
	s(
		{ trig = "cd", dscr = "Current Date" },
		fmta(
			[[
                <>
            ]],
			{
				p(os.date, "%d/%m/%Y"),
			}
		)
	),
	s(
		{ trig = "fmri", dscr = "fMRI phrase" },
		c(1, {
			t("Functional magnetic resonance imaging (fMRI)"),
			t("functional magnetic resonance imaging (fMRI)"),
			t("fMRI"),
		})
	),
	s("box", {
		t("```"),
		t({ "", "" }),
		f(function(args)
			local text = args[1][1] or ""
			local width = #text
			return "┌" .. string.rep("─", width + 2) .. "┐"
		end, { 1 }),
		t({ "", "│ " }),
		i(1, "text"),
		t({ " │", "" }),
		f(function(args)
			local text = args[1][1] or ""
			local width = #text
			return "└" .. string.rep("─", width + 2) .. "┘"
		end, { 1 }),
		t({ "", "" }),
		t("```"),
		i(0),
	}),
	s("div-box", {
		t("```{=html}"),
		t({
			"",
			'<div style="border: 1px solid #333; padding: 0.5em 1em; margin: 1em 0; border-radius: 4px; text-align: center; display: block;">',
		}),
		t({ "", "  " }),
		i(1, "text"),
		t({ "", "" }),
		t("</div>"),
		t({ "", "```" }),
		i(0),
	}),
}
