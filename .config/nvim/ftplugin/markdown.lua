---@type integer Current buffer.
local buffer = vim.api.nvim_get_current_buf();

local got_spec, spec = pcall(require, "markview.spec");
local got_util, utils = pcall(require, "markview.utils");

if not got_spec or not got_util then
    return;
end

--- Fold text creator.
---@return string
_G.heading_foldtext = function ()
    --- Start & end of the current fold.
    --- Note: These are 1-indexed!
    ---@type integer, integer
    local from, to = vim.v.foldstart, vim.v.foldend;

    --- Starting line
    ---@type string
    local line = vim.api.nvim_buf_get_lines(0, from - 1, from, false)[1];

    -- Check if the fold starts with a heading or callout
    local is_heading = line:match("^[%s%>]*%#+")
    local callout_type, callout_content = line:match("^>%s*%[!([A-Z]+)%]%s*(.*)")

    -- Return default foldtext if neither heading nor callout
    if not is_heading and not callout_type then
        return vim.fn.foldtext();
    end

    -- Process headings
    if is_heading then
        --- Heading configuration table.
        ---@type markdown.headings?
        local main_config = spec.get({ "markdown", "headings" }, { fallback = nil });

        if not main_config then
            --- Headings are disabled.
            return vim.fn.foldtext();
        end

        --- Indentation, markers & the content of a heading.
        ---@type string, string, string
        local indent, marker, content = line:match("^([%s%>]*)(%#+)(.*)$");
        --- Heading level.
        ---@type integer
        local level = marker:len();

        ---@type headings.atx
        local config = spec.get({ "heading_" .. level }, {
            source = main_config,
            fallback = nil,
            eval_args = {
                buffer,
                {
                    class = "markdown_atx_heading",
                    marker = marker,
                    text = { marker .. content },
                    range = {
                        row_start = from - 1,
                        row_end = from,
                        col_start = #indent,
                        col_end = #line
                    }
                }
            }
        });

        --- Amount of spaces to add per heading level.
        ---@type integer
        local shift_width = spec.get({ "shift_width" }, { source = main_config, fallback = 0 });

        if not config then
            --- Config not found.
            return vim.fn.foldtext();
        elseif config.style == "simple" then
            return {
                { marker .. content, utils.set_hl(config.hl) },
                {
                    string.format(" 󰘖 %d", to - from),
                    utils.set_hl(string.format("Palette%dFg", 7 - level))
                }
            };
        elseif config.style == "label" then
            local shift = string.rep(" ", level * shift_width);

            return {
                { shift, utils.set_hl(config.hl) },
                { config.corner_left or "", utils.set_hl(config.corner_left_hl or config.hl) },
                { config.padding_left or "", utils.set_hl(config.padding_left_hl or config.hl) },
                { config.icon or "", utils.set_hl(config.padding_left_hl or config.hl) },
                { content:gsub("^%s", ""), utils.set_hl(config.hl) },
                { config.padding_right or "", utils.set_hl(config.padding_right_hl or config.hl) },
                { config.corner_right or "", utils.set_hl(config.corner_right_hl or config.hl) },
                {
                    string.format(" 󰘖 %d", to - from),
                    utils.set_hl(string.format("Palette%dFg", 7 - level))
                }
            };
        elseif config.style == "icon" then
            local shift = string.rep(" ", level * shift_width);

            return {
                { shift, utils.set_hl(config.hl) },
                { config.icon or "", utils.set_hl(config.padding_left_hl or config.hl) },
                { content:gsub("^%s", ""), utils.set_hl(config.hl) },
                {
                    string.format(" 󰘖 %d", to - from),
                    utils.set_hl(string.format("Palette%dFg", 7 - level))
                }
            };
        end
    else
        -- Process callout blocks
        callout_content = callout_content:gsub("^%s*", ""):gsub("%s*$", "") -- Trim whitespace
        local num_lines = to - from
        return {
            { "[!" .. callout_type .. "] " .. callout_content, utils.set_hl("MarkdownCallout") },
            { string.format(" 󰘖 %d", num_lines), utils.set_hl("Palette6Fg") }
        }
    end
end

vim.o.fillchars = "fold: ";
vim.o.foldmethod = "expr";
vim.o.foldexpr = "v:lua.vim.treesitter.foldexpr()";
vim.o.foldtext = "v:lua.heading_foldtext()"
