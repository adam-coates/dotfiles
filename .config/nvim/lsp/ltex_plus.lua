local blink = require("blink.cmp")
return {
	cmd = { "ltex-ls-plus" },
	filetypes = { "markdown", "text", "tex", "rst", "quarto", "qmd" },
	settings = {
		ltex = {
			enabled = {
				"bib",
				"context",
				"gitcommit",
				"html",
				"markdown",
				"org",
				"pandoc",
				"plaintex",
				"quarto",
				"mail",
				"mdx",
				"rmd",
				"rnoweb",
				"rst",
				"tex",
				"latex",
				"text",
				"typst",
				"xhtml",
			},
			language = "en-US",
			languageModel = "/run/media/adam/f68df5d2-81b1-4947-85c8-ed91e36b2051/adam/models/ngrams",
			disabledRules = {
				["en-US"] = {
					"MORFOLOGIK_RULE_EN_US",
				},
			},
		},
	},
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
