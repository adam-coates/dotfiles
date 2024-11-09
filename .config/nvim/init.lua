require("adam.core")
require("adam.lazy")
require("custom_functions")
package.path = package.path .. ";" .. vim.fn.expand("$HOME") .. "/.luarocks/share/lua/5.1/?/init.lua"
package.path = package.path .. ";" .. vim.fn.expand("$HOME") .. "/.luarocks/share/lua/5.1/?.lua"


-- Create a key mapping to call the title function
vim.api.nvim_set_keymap(
	"n",
	"<leader>zt",
	':lua require("custom_functions").title()<CR>',
	{ noremap = true, silent = true }
)
vim.api.nvim_set_keymap(
	"n",
	"<leader>zp",
	':lua require("custom_functions").yaml_ref()<CR>',
	{ noremap = true, silent = true }
)
vim.g.python3_host_prog = "/home/adam/.pyenv/versions/py3/bin/python3"

-- function to renmae buffer to the currently selected highlighted text
function _G.rename_buffer_from_selection()
    -- Get the range of selected text in visual mode
    local start_pos = vim.fn.getpos("'<")
    local end_pos = vim.fn.getpos("'>")

    local start_line, start_col = start_pos[2], start_pos[3]
    local end_line, end_col = end_pos[2], end_pos[3]

    -- Ensure only one line is selected
    if start_line ~= end_line then
        print("Selection spans multiple lines. Only single-line selection is allowed.")
        return
    end

    -- Get the selected text in the current buffer
    local current_line = vim.fn.getline(start_line)
    local selected_text = string.sub(current_line, start_col, end_col)

    -- Trim whitespace and add ".md" extension for renaming
    selected_text = vim.trim(selected_text) .. ".md"

    -- Rename the buffer (and file) if it's a real file
    local current_path = vim.api.nvim_buf_get_name(0)
    if current_path ~= "" then
        local new_path = vim.fn.fnamemodify(current_path, ":h") .. "/" .. selected_text
        vim.cmd("file " .. new_path)
        print("Renamed buffer to " .. new_path)
    else
        print("Buffer is not associated with a file.")
    end
end
vim.api.nvim_set_keymap(
	"v",
	"<leader>rrr",
	[[:<C-u>lua _G.rename_buffer_from_selection()<CR>]],
	{ noremap = true, silent = true }
)

local highlight_group = vim.api.nvim_create_augroup('YankHighlight', { clear = true })
vim.api.nvim_create_autocmd('TextYankPost', {
  callback = function()
    vim.highlight.on_yank()
  end,
  group = highlight_group,
  pattern = '*',
})

