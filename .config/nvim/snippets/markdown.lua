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

	s(
		{ trig = "(%d)x(%d)", regTrig = true, dscr = "Rows x columns" },
		fmta(
			[[
               <>
            ]],
			{
				d(1, function(_, snip)
					local nodes = {}
					local nr_rows = snip.captures[1]
					local nr_cols = snip.captures[2]
					local idx = 0

					local hlines = ""
					for _ = 1, nr_cols do
						idx = idx + 1
						table.insert(nodes, t("| "))
						table.insert(nodes, i(idx))
						table.insert(nodes, t(" "))
						hlines = hlines .. "|-----"
					end
					table.insert(nodes, t({ "|", "" }))
					hlines = hlines .. "|"
					table.insert(nodes, t({ hlines, "" }))

					for _ = 1, nr_rows do
						for _ = 1, nr_cols do
							idx = idx + 1
							table.insert(nodes, t("| "))
							table.insert(nodes, i(idx))
							table.insert(nodes, t(" "))
						end
						table.insert(nodes, t({ "|", "" }))
					end
					return sn(nil, nodes)
				end),
			}
		),
		{ condition = line_begin }
	),
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
	s(
		"selected_text",
		f(function(args, snip)
			local res, env = {}, snip.env
			table.insert(res, "Selected Text (current line is " .. env.TM_LINE_NUMBER .. "):")
			for _, ele in ipairs(env.LS_SELECT_RAW) do
				table.insert(res, ele)
			end
			return res
		end, {})
	),
}
