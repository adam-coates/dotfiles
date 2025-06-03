local blink = require("blink.cmp")
return {
    cmd = { "R", "--no-echo", "-e", "languageserver::run()" },
	filetypes = { "r", "rmd", "quarto" },
	capabilities = vim.tbl_deep_extend(
		"force",
		{},
		vim.lsp.protocol.make_client_capabilities(),
		blink.get_lsp_capabilities(),
		{
			fileOperations = {
				didRename = true,
				willRename = true,
			},
		}
	),
}
