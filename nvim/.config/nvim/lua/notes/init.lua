-- The local part of this config: everything in lua/notes/ is plain Lua on top of the
-- plugins, one module per feature.

local util = require("notes.util")
local vault = require("notes.vault")

local M = {}

local function command(name, fn, opts)
	vim.api.nvim_create_user_command(name, fn, opts or {})
end

-- The <CR> key in notes: follow links and tags, tick tasks, list query results,
-- fold headings.
local function enter()
	local blocks, tasks = require("notes.blocks"), require("notes.tasks")
	if require("notes.canvas").open_at_cursor() then
		return ""
	end
	if blocks.current() then
		vim.schedule(blocks.pick)
		return ""
	end
	local api = require("obsidian.api")
	local link = api.cursor_link()
	if not link and not api.cursor_tag() and tasks.on_task() then
		vim.schedule(tasks.toggle_current)
		return ""
	end
	return require("obsidian.actions").smart_action()
end

function M.setup()
	require("notes.panel").setup()
	require("notes.blocks").setup()
	require("notes.decor").setup()
	require("notes.sync").setup()
	require("notes.todoist").setup()
	require("utils.statusline").setup() -- your previous config's, with the notes details

	local group = vim.api.nvim_create_augroup("notes", { clear = true })

	-- Keep the index current.
	vim.api.nvim_create_autocmd({ "BufWritePost", "BufDelete" }, {
		group = group,
		pattern = "*.md",
		callback = function(ev)
			if vault.is_note(ev.match) then
				require("notes.index").update(vim.fs.normalize(ev.match))
			end
		end,
	})
	local rescan = util.debounce(300, function()
		local index = require("notes.index")
		local before = index.version
		index.refresh()
		if index.version ~= before then
			vim.api.nvim_exec_autocmds("User", { pattern = "NotesChanged", data = {} })
		end
	end)
	vim.api.nvim_create_autocmd("FocusGained", { group = group, callback = rescan })

	-- Keys that obsidian.nvim also sets have to come after it.
	vim.api.nvim_create_autocmd("User", {
		group = group,
		pattern = "ObsidianNoteEnter",
		callback = function(ev)
			vim.keymap.set("n", "<CR>", enter, { buffer = ev.buf, expr = true, desc = "Follow, tick, fold or list" })
		end,
	})

	command("Today", function()
		require("notes.periodic").open("daily")
	end, { desc = "Today's note" })
	command("Week", function()
		require("notes.periodic").open("weekly")
	end, { desc = "This week's note" })
	command("Calendar", function()
		require("notes.calendar").open()
	end, { desc = "Calendar" })
	command("Agenda", function(args)
		require("notes.agenda").open({ filter = args.args ~= "" and args.args or false })
	end, { nargs = "?", desc = "Agenda" })
	command("Capture", function()
		require("notes.capture").open({ standalone = vim.fn.argc() == 0 and vim.api.nvim_buf_get_name(0) == "" and vim.v.vim_did_enter == 0 })
	end, { desc = "Quick capture" })
	command("Task", function(args)
		if args.args == "" then
			return require("notes.tasks").capture()
		end
		local T = require("notes.tasks")
		local line = T.from_text(args.args)
		T.add_to_note(T.capture_path(), require("settings").task_heading, { line })
		util.notify(line:gsub("^%- %[ %] ", ""))
	end, { nargs = "*", desc = "Add a task" })
	command("Board", function(args)
		if args.args ~= "" then
			require("notes.kanban").open(vault.abs(args.args))
		else
			require("notes.kanban").open()
		end
	end, {
		nargs = "?",
		desc = "Open this note (or another) as a kanban board",
		complete = function()
			return vim.tbl_map(
				function(e)
					return e.rel
				end,
				vim.tbl_filter(function(e)
					return e.fm["kanban-plugin"] ~= nil
				end, require("notes.index").all())
			)
		end,
	})
	command("Graph", function(args)
		require("notes.graph").open({ mode = args.args })
	end, {
		nargs = "?",
		complete = function()
			return { "local" }
		end,
		desc = "Live graph in the browser",
	})
	command("Review", function()
		require("notes.cards").review()
	end, { desc = "Review flashcards" })
	command("Sync", function()
		require("notes.sync").sync()
	end, { desc = "Commit, pull and push the vault" })
	command("Export", function(args)
		local export = require("notes.export")
		for _, format in ipairs(export.formats) do
			if format.ext == args.args or format.name:lower() == args.args:lower() then
				return export.run(format)
			end
		end
		export.pick()
	end, {
		nargs = "?",
		complete = function()
			return { "pdf", "docx", "html", "tex", "typ", "epub", "md" }
		end,
		desc = "Export this note",
	})
	command("Canvas", function(args)
		local canvas = require("notes.canvas")
		if args.args == "" then
			return canvas.new()
		end
		canvas.open(vault.folder("canvas") .. "/" .. util.filename(args.args) .. ".svg")
	end, { nargs = "?", desc = "New canvas (or open one by name)" })
	command("MindMap", function(args)
		if args.range > 0 then
			require("notes.canvas").mindmap(args.line1, args.line2)
		else
			require("notes.canvas").mindmap()
		end
	end, { range = true, desc = "Mind map of the list (or headings)" })
	command("Keys", function()
		require("notes.help").open()
	end, { desc = "Keys and help" })

	vim.api.nvim_create_autocmd("VimEnter", {
		group = group,
		callback = vim.schedule_wrap(function()
			require("notes.index").ensure()
		end),
	})

	-- Panels from settings.open_panels, with the first note.
	vim.api.nvim_create_autocmd("User", {
		group = group,
		pattern = "ObsidianNoteEnter",
		once = true,
		callback = vim.schedule_wrap(function()
			local settings = require("settings")
			if vim.o.columns < settings.panel_width + 70 or #vim.api.nvim_list_uis() == 0 then
				return
			end
			for _, name in ipairs(settings.open_panels) do
				if name == "context" then
					require("notes.panel").open()
				elseif name == "explorer" then
					local win = vim.api.nvim_get_current_win()
					Snacks.explorer({ cwd = vault.root() })
					vim.schedule(function()
						pcall(vim.api.nvim_set_current_win, win)
					end)
				end
			end
		end),
	})
end

return M
