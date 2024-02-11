local extras = require('luasnip.extras')
local ls = require('luasnip')

local c = ls.choice_node
local d = ls.dynamic_node
local f = ls.function_node
local i = ls.insert_node
local s = ls.snippet
local t = ls.text_node
local sn = ls.snippet_node

local p = extras.partial
local rep = extras.rep
local fmta = require('luasnip.extras.fmt').fmta
local line_begin = require('luasnip.extras.expand_conditions').line_begin

-- example function to search for a string in current buffer
-- here I wanted a snippet to only expand if a phrase was not in buffer
--
--local function searchForFooInBuffer()
--    -- Get the content of the current buffer
--    local current_buffer = vim.api.nvim_get_current_buf()
--    local document = vim.api.nvim_buf_get_lines(current_buffer, 0, -1, false)
--
--    -- Concatenate lines into a single string
--    document = table.concat(document, "\n")
--
--    -- Search for "foo" in the document
--    if string.find(document, "functional magnetic resonance imaging (fMRI)") then
--        return false  -- Return false if "foo" is found
--    else
--        return true  -- Return true if "foo" is not found
--    end
--end


return {
    -- Pandoc-- Pandoc
    s(
        { trig = 'fm', dscr = 'Front matter' },
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
                i(2, 'Adam Coates'),
                p(os.date, '%d/%m/%Y'),
            }
        ),
        { condition = line_begin }
    ),
        s(
        { trig = '(%d)x(%d)', regTrig = true, dscr = 'Rows x columns' },
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

                    local hlines = ''
                    for _ = 1, nr_cols do
                        idx = idx + 1
                        table.insert(nodes, t('| '))
                        table.insert(nodes, i(idx))
                        table.insert(nodes, t(' '))
                        hlines = hlines .. '|-----'
                    end
                    table.insert(nodes, t({ '|', '' }))
                    hlines = hlines .. '|'
                    table.insert(nodes, t({ hlines, '' }))

                    for _ = 1, nr_rows do
                        for _ = 1, nr_cols do
                            idx = idx + 1
                            table.insert(nodes, t('| '))
                            table.insert(nodes, i(idx))
                            table.insert(nodes, t(' '))
                        end
                        table.insert(nodes, t({ '|', '' }))
                    end
                    return sn(nil, nodes)
                end),
            }
        ),
        { condition = line_begin }
    ),

    -- Note-taking
    s(
        { trig = 'cd', dscr = 'Current Date' },
        fmta(
            [[
                <>
            ]],
            {
                p(os.date, '%d/%m/%Y'),
            }
        )
    ),
            s(
        { trig = "fmri", dscr = 'fMRI phrase' },
        c(1, {
            t("Functional magnetic resonance imaging (fMRI)"),
 	        t("functional magnetic resonance imaging (fMRI)"),
 	        t("fMRI")
        }
        )
    )
}



