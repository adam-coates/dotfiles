-- :checkhealth notes
local M = {}

function M.check()
	local h = vim.health
	local settings = require("settings")
	local vault = require("notes.vault")

	h.start("Vault")
	if vim.uv.fs_stat(vault.root()) then
		local index = require("notes.index").refresh()
		h.ok(("%s (%s): %d notes"):format(vault.name(), vault.root(), #index.all()))
		local broken, orphans = #index.broken(), #index.orphans()
		h.info(("%d broken links, %d orphans (<leader>lx, <leader>fO)"):format(broken, orphans))
	else
		h.error("No vault at " .. vault.root(), { "Set M.vaults in lua/settings.lua" })
	end
	for key, name in pairs(settings.templates) do
		if not require("notes.template").path(key) then
			h.warn(("Template “%s” for %s notes is missing"):format(name, key))
		end
	end

	local function tool(cmd, why, required)
		if vim.fn.executable(cmd) == 1 then
			h.ok(cmd .. ": " .. why)
		else
			h[required and "error" or "warn"](cmd .. " not found: " .. why)
		end
	end
	h.start("Tools")
	tool("rg", "search and unlinked mentions", true)
	tool("git", "sync, plugins", true)
	tool("tree-sitter", "building parsers", true)
	tool("wl-paste", "pasting images")
	tool("magick", "showing images")
	tool("pandoc", "export")
	tool("typst", "PDF export")
	tool("sqlite3", "Zotero")
	tool("inkscape", "drawings")
	tool("ffmpeg", "audio recordings")
	tool("npm", "browser preview")
	tool("harper-ls", "grammar (installed by mason)")
	tool("prettier", "formatting with <leader>mp (installed by mason)")
	tool("tectonic", "maths as images (installed by mason)")
	tool("mmdc", "Mermaid diagrams as images (mermaid-cli); the browser preview shows them without it")

	h.start("Images in the terminal")
	if settings.images == false then
		h.info("Switched off in settings")
	else
		local ok, env = pcall(function()
			return Snacks.image.terminal.env()
		end)
		if ok and env.supported then
			h.ok("This terminal shows images" .. (env.placeholders and ", inline" or ""))
		else
			h.warn("This terminal doesn't announce image support", { "Use Ghostty or kitty. Inside herdr, check that kitty_graphics isn't switched off in its config." })
		end
	end

	h.start("Todoist")
	local todoist = require("notes.todoist")
	if not todoist.token() then
		h.info("Not connected. :TodoistToken (or $TODOIST_API_TOKEN) connects it.")
	elseif todoist.cache.error then
		h.error(todoist.cache.error)
	elseif todoist.cache.time > 0 then
		h.ok(("Connected: %d tasks in the agenda filter"):format(#todoist.cache.tasks))
	else
		h.info("Token set, not fetched yet")
	end

	h.start("Zotero")
	if require("notes.zotero").database() then
		h.ok("Database found")
	else
		h.info("No database at " .. settings.zotero.database)
	end
end

return M
