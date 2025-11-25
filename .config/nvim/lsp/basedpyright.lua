return {
	cmd = { "basedpyright-langserver", "--stdio" },
	filetypes = { "python" },
	root_markers = {
		"pyproject.toml",
		"uv.lock",
		".python-version",
		"requirements.txt",
		"setup.py",
		"setup.cfg",
		".venv",
	},
	settings = {
		basedpyright = {
			analysis = {
				autoSearchPaths = true,
				useLibraryCodeForTypes = true,
				autoImportCompletions = true,
				diagnosticMode = "workspace",
			},
		},
	},
}
