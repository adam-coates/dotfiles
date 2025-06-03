local blink = require("blink.cmp")
return {
	cmd = { "vale-ls" },
	filetypes = { "markdown", "text", "tex", "rst", "quarto", "qmd" },
	init_options = {
		configPath = "C:/Users/coates/AppData/Local/vale/vale.ini",
	},
	cmd_env = { VALE_CONFIG_PATH = "C:/Users/coates/AppData/Local/vale/vale.ini" },
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
