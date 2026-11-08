local conform = require("conform")

conform.setup({
	formatters_by_ft = {
		javascript = { "prettier" },
		typescript = { "prettier" },
		javascriptreact = { "prettier" },
		typescriptreact = { "prettier" },
		svelte = { "prettier" },
		css = { "prettier" },
		html = { "prettier" },
		json = { "prettier" },
		yaml = { "prettier" },
		markdown = { "prettier" },
		graphql = { "prettier" },
		liquid = { "prettier" },
		lua = { "stylua" },
		python = { "isort", "black" },
		nix = { "nixfmt" },
		-- Code chunks, each with its own language's formatters (python: isort, black).
		quarto = { "injected" },
	},
	format_on_save = {
		lsp_format = "fallback",
		timeout_ms = 3000,
	},
})

-- isort 9 leaves the imports alone when --filename names a file that doesn't
-- exist, which is every quarto code chunk (conform names them file.qmd.1.py).
-- Pass the name only when there is a real file, so chunks get sorted too.
conform.formatters.isort = {
	args = function(_, ctx)
		local args = { "--stdout", "--line-ending", require("conform.util").buf_line_ending(ctx.buf) }
		if vim.uv.fs_stat(ctx.filename) then
			vim.list_extend(args, { "--filename", ctx.filename })
		end
		table.insert(args, "-")
		return args
	end,
}

vim.keymap.set({ "n", "v" }, "<leader>mp", function()
	conform.format({ lsp_format = "fallback", timeout_ms = 1000 })
end, { desc = "Format file or range (in visual mode)" })
