require("adam.core")
require("adam.lazy")
require("custom_functions")

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

vim.g.python3_host_prog = "C:/Users/coates/Desktop/python3.exe"
vim.g.python_host_prog = "C:/Users/coates/Pyportable-2.7.10rc1/python.exe"

-- function to renmae buffer to the currently selected highlighted text
local function rename_buffer_from_selection()
	local start_pos = vim.fn.getpos("'<")
	local end_pos = vim.fn.getpos("'>")

	local lines = vim.api.nvim_buf_get_lines(0, start_pos[2] - 1, end_pos[2], false)

	local new_name = table.concat(lines, " ")

	new_name = new_name .. ".md"

	vim.api.nvim_buf_set_name(0, new_name)
	print("Buffer renamed to: " .. new_name)
end

vim.api.nvim_create_user_command("RenameBufferFromSelection", rename_buffer_from_selection, { range = true })

_G.rename_buffer_from_selection = rename_buffer_from_selection

vim.api.nvim_set_keymap(
	"v",
	"<leader>rrr",
	[[:<C-u>lua _G.rename_buffer_from_selection()<CR>]],
	{ noremap = true, silent = true }
)

vim.api.nvim_create_user_command("AddGoogleEvent", function()
	-- Save the current buffer
	vim.cmd("write")

	-- Get the full path of the current buffer
	local file_path = vim.fn.expand("%:p")

	-- Execute the Python script with the file path as an argument
	vim.cmd("!py C:\\Users\\coates\\add_event.py " .. file_path)
end, {})
