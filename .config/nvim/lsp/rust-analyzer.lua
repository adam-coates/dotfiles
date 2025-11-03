local blink = require("blink.cmp")
return {
    cmd = {
        "rust-analyzer",
    },
    filetypes = {
        "rust",
    },
    root_markers = {
        "Cargo.lock",
    },
    settings = {
        ["rust-analyzer"] = {
            check = {
                command = "clippy",
            },
            diagnostics = {
                enable = true,
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
