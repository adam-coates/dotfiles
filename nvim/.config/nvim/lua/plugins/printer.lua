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

-- <leader>P: <leader>p is the notes panels (backlinks, graph, calendar, …).
local map = vim.keymap.set
map("n", "<leader>Pb", printer.print_buffer, { desc = "Print buffer" })
map("n", "<leader>Pl", printer.print_current_line, { desc = "Print current line" })
map("n", "<leader>PL", printer.toggle_live_mode, { desc = "Toggle live printing" })
-- print_selection reads the '< and '> marks, which only update once visual mode
-- ends, so leave it first. Called directly, it printed the previous selection.
map("x", "<leader>Pp", "<Esc><Cmd>lua require('printer').print_selection()<CR>", { desc = "Print selection" })
