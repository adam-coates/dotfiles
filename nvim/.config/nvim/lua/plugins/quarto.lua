require("otter").setup({
	buffers = { set_filetype = true },
})

require("quarto").setup({
	lspFeatures = {
		enabled = true,
		chunks = "curly",
		languages = { "r", "python", "julia", "bash", "html" },
		diagnostics = {
			enabled = true,
			triggers = { "BufWritePost" },
		},
		completion = { enabled = true },
	},
	codeRunner = {
		enabled = true,
		default_method = "slime",
	},
})

-- quarto-nvim activates otter in .qmd files. Do the same for code blocks in markdown.
vim.api.nvim_create_autocmd("FileType", {
	group = vim.api.nvim_create_augroup("UserOtterMarkdown", { clear = true }),
	pattern = "markdown",
	callback = function(ev)
		-- Skip LSP hover/signature floats and other scratch buffers: they are
		-- markdown too, and otter would create a ".otter.lua" next to cwd for them.
		if vim.bo[ev.buf].buftype ~= "" or vim.api.nvim_buf_get_name(ev.buf) == "" then
			return
		end
		require("otter").activate()
	end,
})

require("utils.repl").setup()

local map = vim.keymap.set
local function run(fn)
	return function()
		require("utils.repl").update()
		require("quarto.runner")[fn]()
	end
end

map("n", "<leader>qp", require("quarto").quartoPreview, { desc = "Quarto Preview" })
map("n", "<leader>qq", require("quarto").quartoClosePreview, { desc = "Quarto Close Preview" })
map("n", "<leader>qa", "<cmd>QuartoActivate<cr>", { desc = "Quarto Activate" })

map("n", "<localleader>rc", run("run_cell"), { desc = "Run cell" })
map("n", "<localleader>ra", run("run_above"), { desc = "Run cell and above" })
map("n", "<localleader>rb", run("run_below"), { desc = "Run cell and below" })
map("n", "<localleader>rA", run("run_all"), { desc = "Run all cells" })
map("n", "<localleader>rl", run("run_line"), { desc = "Run line" })
map("v", "<localleader>r", run("run_range"), { desc = "Run visual range" })
