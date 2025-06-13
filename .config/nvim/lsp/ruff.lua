local blink = require("blink.cmp")
return {
    cmd = {
        "ruff",
        "server",
    },
    filetypes = {
        "python",
    },
    root_markers = {
        ".python-version",
        "Pipfile",
        "pyproject.toml",
        "pyrightconfig.json",
        "requirements.txt",
        "setup.cfg",
        "setup.py",
        "uv.lock",
    },
    -- https://github.com/microsoft/pyright/blob/main/docs/settings.md
    -- Breaks if we don't have at least `settings = { python = {} }` here.
    -- Where possible, configure using pyproject.toml instead.
    -- That way all developers share the same settings.
    settings = {},
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
