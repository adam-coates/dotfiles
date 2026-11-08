local dap = require("dap")
local dapui = require("dapui")

dapui.setup({})
require("nvim-dap-virtual-text").setup({
	commented = true, -- Show virtual text alongside comment
})

-- debugpy comes from Mason (the system python3 doesn't have it). The program
-- itself runs with the active virtualenv's python ($VIRTUAL_ENV, $CONDA_PREFIX).
require("dap-python").setup(vim.fn.stdpath("data") .. "/mason/packages/debugpy/venv/bin/python")

vim.fn.sign_define("DapBreakpoint", {
	text = "",
	texthl = "DiagnosticSignError",
	linehl = "",
	numhl = "",
})

vim.fn.sign_define("DapBreakpointRejected", {
	text = "", -- or "❌"
	texthl = "DiagnosticSignError",
	linehl = "",
	numhl = "",
})

vim.fn.sign_define("DapStopped", {
	text = "", -- or "→"
	texthl = "DiagnosticSignWarn",
	linehl = "Visual",
	numhl = "DiagnosticSignWarn",
})

-- Open the UI when a session starts
dap.listeners.after.event_initialized["dapui_config"] = function()
	dapui.open()
end

local map = function(lhs, rhs, desc)
	vim.keymap.set("n", lhs, rhs, { silent = true, desc = desc })
end
map("<leader>db", dap.toggle_breakpoint, "Toggle Breakpoint")
map("<leader>dc", dap.continue, "Start/Continue Debugging")
map("<leader>do", dap.step_over, "Step Over")
map("<leader>di", dap.step_into, "Step Into")
map("<leader>dO", dap.step_out, "Step Out")
map("<leader>dq", dap.terminate, "Quit Debugging")
map("<leader>du", dapui.toggle, "Toggle DAP UI")
