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

-- <leader>d is daily notes everywhere else, so these keys are only set in files
-- that can be debugged (python, through dap-python). There they take over
-- <leader>dc (calendar: <leader>pc) and <leader>do (on this day).
local function debug_keys(buf)
	local map = function(lhs, rhs, desc)
		vim.keymap.set("n", lhs, rhs, { buffer = buf, silent = true, desc = desc })
	end
	map("<leader>db", dap.toggle_breakpoint, "Toggle Breakpoint")
	map("<leader>dc", dap.continue, "Start/Continue Debugging")
	map("<leader>do", dap.step_over, "Step Over")
	map("<leader>di", dap.step_into, "Step Into")
	map("<leader>dO", dap.step_out, "Step Out")
	map("<leader>dq", dap.terminate, "Quit Debugging")
	map("<leader>du", dapui.toggle, "Toggle DAP UI")
end

vim.api.nvim_create_autocmd("FileType", {
	group = vim.api.nvim_create_augroup("UserDebugKeys", { clear = true }),
	callback = function(ev)
		if dap.configurations[ev.match] and vim.bo[ev.buf].buftype == "" then
			debug_keys(ev.buf)
		end
	end,
})
