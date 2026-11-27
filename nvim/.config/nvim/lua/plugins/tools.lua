require("gitsigns").setup({})

-- Close and rename HTML/JSX tags as you type
require("nvim-ts-autotag").setup({})

require("grug-far").setup({
	headerMaxWidth = 80,
	windowCreationCommand = "tabnew",
})

-- Zotero: citation keys complete after @, and <leader>z works on the one under
-- the cursor. Literature notes are in notes.zotero.
local zotero = require("settings").zotero
local database = vim.fn.expand(zotero.database)
if vim.uv.fs_stat(database) and vim.fn.executable("sqlite3") == 1 then
	require("zotcite").setup({
		zotero_sqlite_path = database,
		attach_dir = vim.fn.expand(zotero.attachments),
		open_in_zotero = true,
		key_type = "better-bibtex",
	})
	-- Your previous config's additions: Snacks instead of Telescope for zotcite's
	-- pickers, and :ZoteroAnnotations.
	require("utils.zotcite_snacks").setup()
	require("utils.zotero_annotations").setup()
else
	vim.g.loaded_zotcite = true
end
