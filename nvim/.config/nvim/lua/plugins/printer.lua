-- Receipt printer (Epson TM, over USB). The plugin's defaults are these values,
-- set here so they're easy to change.
local printer = require("printer")

printer.setup({
	python_cmd = "uv run",
	printer_vendor_id = "0x04B8",
	printer_product_id = "0x0E39",
	line_width = 48, -- characters per line
})

vim.api.nvim_create_user_command("PrintBuffer", printer.print_buffer, {})
vim.api.nvim_create_user_command("PrintLine", printer.print_current_line, {})
vim.api.nvim_create_user_command("PrintLive", printer.toggle_live_mode, {})

local map = vim.keymap.set
map("n", "<leader>pb", printer.print_buffer, { desc = "Print buffer" })
map("n", "<leader>pl", printer.print_current_line, { desc = "Print current line" })
map("n", "<leader>pL", printer.toggle_live_mode, { desc = "Toggle live printing" })
-- print_selection reads the '< and '> marks, which only update once visual mode
-- ends, so leave it first. Called directly, it printed the previous selection.
map("x", "<leader>pp", "<Esc><Cmd>lua require('printer').print_selection()<CR>", { desc = "Print selection" })
