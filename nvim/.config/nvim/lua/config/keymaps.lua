-- Every key of this config, by group. doc/keys.md (<leader>?) describes them.
-- Your previous config's keys are here too. Where both had a key, it does the notes
-- thing in a vault note and your previous config's thing everywhere else (files,
-- grep, figures, images), unless doc/keys.md says it moved.

local function map(modes, lhs, rhs, desc, opts)
	vim.keymap.set(modes, lhs, rhs, vim.tbl_extend("force", { desc = desc, silent = true }, opts or {}))
end

--- A function of one of the notes.* modules, loaded on first use.
local function notes(module, fn, ...)
	local args = { ... }
	return function()
		return require("notes." .. module)[fn](unpack(args))
	end
end

local function obsidian(cmd)
	return function()
		vim.cmd("Obsidian " .. cmd)
	end
end

local function action(name, ...)
	local args = { ... }
	return function()
		require("obsidian.actions")[name](unpack(args))
	end
end

local function root()
	return require("notes.vault").root()
end

--- In a vault note, or in an empty buffer while Neovim's folder is a vault.
local function in_vault()
	local vault = require("notes.vault")
	local name = vim.api.nvim_buf_get_name(0)
	if name ~= "" then
		return vault.is_note(name)
	end
	return vault.rel(vim.fn.getcwd() .. "/x.md") ~= nil
end

--- `in_notes` in a vault, `elsewhere` outside one.
local function either(in_notes, elsewhere)
	return function()
		if in_vault() then
			return in_notes()
		end
		return elsewhere()
	end
end

local function explorer()
	return Snacks.picker.get({ source = "explorer" })[1]
end

-- Straight away ------------------------------------------------------------------
map("n", "<leader><leader>", notes("pickers", "switch"), "Find or create a note")
map("n", "<leader>/", notes("pickers", "grep"), "Search all notes")
map("n", "<leader>,", function()
	Snacks.picker.buffers()
end, "Open notes")
map("n", "<leader>.", notes("panel", "toggle"), "Context panel")
map("n", "<leader>?", notes("help", "open"), "Keys and help")
map("n", "<leader>u", function()
	Snacks.picker.undo()
end, "Undo history")
map("n", "<leader>Z", function()
	Snacks.zen()
end, "Zen mode")
map("n", "<leader>ee", function()
	local picker = explorer()
	if picker then
		picker:close()
	else
		Snacks.explorer({ cwd = in_vault() and root() or nil })
	end
end, "Toggle file explorer")
map("n", "<leader>ef", function()
	local picker = explorer()
	if picker then
		picker:close()
	else
		Snacks.explorer.reveal()
	end
end, "Toggle file explorer on current file")
map("n", "<leader>ec", function()
	local picker = explorer()
	if picker then
		picker:action("explorer_close_all")
	end
end, "Collapse file explorer")
map("n", "<leader>er", function()
	local picker = explorer()
	if picker then
		picker:action("explorer_update")
	end
end, "Refresh file explorer")

-- n: note --------------------------------------------------------------------------
map("n", "<leader>nn", function()
	if require("settings").ask_location then
		return require("notes.location").new_note() -- title, location, tags
	end
	require("notes.util").input({ prompt = "New note (folder/title works too)" }, function(name)
		local vault, util = require("notes.vault"), require("notes.util")
		local folder, title = name:match("^(.*)/([^/]+)$")
		vault.create((folder and vault.abs(folder) or vault.folder("inbox")) .. "/" .. util.filename(title or name) .. ".md", { template = "note" })
	end)
end, "New note")
map("n", "<leader>nt", obsidian("new_from_template"), "New note from a template")
map("n", "<leader>nu", obsidian("unique_note"), "New note with a timestamp name")
map("n", "<leader>nc", notes("capture", "open"), "Quick capture")
map("x", "<leader>nc", function()
	vim.cmd("normal! \27")
	local lines = vim.api.nvim_buf_get_lines(0, vim.fn.line("'<") - 1, vim.fn.line("'>"), false)
	require("notes.capture").open({ text = lines })
end, "Capture selection")
map("n", "<leader>nr", obsidian("rename"), "Rename note (updates links)")
map("n", "<leader>nm", notes("location", "move_current"), "Move note to a folder (updates location)")
map("n", "<leader>nf", notes("location", "file_current"), "File this note where its location says")
map("n", "<leader>nF", notes("location", "file_inbox"), "File the inbox notes where their location says")
map("n", "<leader>na", notes("location", "new_person"), "New person (people folder)")
map("n", "<leader>nM", action("merge_note"), "Merge into another note")
map("n", "<leader>nd", action("delete_note"), "Delete note")
map("n", "<leader>np", notes("refactor", "ask_property"), "Set a property")
map("n", "<leader>nP", obsidian("properties"), "Browse properties")
map("n", "<leader>nx", notes("pickers", "random"), "Random note")
map("n", "<leader>nb", action("add_bookmark"), "Bookmark this")
map("n", "<leader>ny", function()
	local name = vim.fs.basename(vim.api.nvim_buf_get_name(0)):gsub("%.md$", "")
	local entry = require("notes.index").buffer()
	local row, heading = vim.api.nvim_win_get_cursor(0)[1], nil
	for _, h in ipairs(entry and entry.headings or {}) do
		if h.line == row then
			heading = h.text
		end
	end
	local link = "[[" .. name .. (heading and ("#" .. heading) or "") .. "]]"
	vim.fn.setreg("+", link)
	require("notes.util").notify("Copied " .. link)
end, "Copy a link to this note or heading")

-- d: daily and other periodic notes ---------------------------------------------------
map("n", "<leader>dd", notes("periodic", "open", "daily"), "Today")
map("n", "<leader>dy", function()
	require("notes.periodic").open("daily", require("notes.date").parse("yesterday"))
end, "Yesterday")
map("n", "<leader>dt", function()
	require("notes.periodic").open("daily", require("notes.date").parse("tomorrow"))
end, "Tomorrow")
map("n", "<leader>dw", notes("periodic", "open", "weekly"), "This week")
map("n", "<leader>dm", notes("periodic", "open", "monthly"), "This month")
map("n", "<leader>dY", notes("periodic", "open", "yearly"), "This year")
map("n", "<leader>dc", notes("calendar", "open"), "Calendar")
map("n", "<leader>dl", notes("periodic", "pick", "daily"), "List daily notes")
map("n", "<leader>dL", notes("periodic", "pick", "weekly"), "List weekly notes")
map("n", "<leader>do", notes("pickers", "on_this_day"), "On this day")
map("n", "<leader>dj", function()
	require("notes.util").input({ prompt = "Go to day (friday, 3 weeks ago, 1 dec)" }, function(text)
		local iso = require("notes.date").parse(text)
		if iso then
			require("notes.periodic").open("daily", iso)
		else
			require("notes.util").notify("Not a date: " .. text, "warn")
		end
	end)
end, "Go to a day")
map("n", "[p", notes("periodic", "step", -1), "Previous daily/weekly/… note")
map("n", "]p", notes("periodic", "step", 1), "Next daily/weekly/… note")

-- l: links ------------------------------------------------------------------------------
map("n", "<leader>lb", obsidian("backlinks"), "Backlinks")
map("n", "<leader>lo", obsidian("links"), "Links in this note")
map("n", "<leader>ll", notes("pickers", "insert_link"), "Insert a link")
map("x", "<leader>ll", action("link"), "Link selection to a note")
map("n", "<leader>ln", action("link_new"), "Link word to a new note")
map("x", "<leader>ln", action("link_new"), "Link selection to a new note")
map("n", "<leader>lr", action("unlink"), "Remove link, keep the text")
map("n", "<leader>lu", action("link_suggestions"), "Unlinked mentions in this note")
map("n", "<leader>lU", action("backlink_suggestions"), "Unlinked mentions of this note")
map("n", "<leader>lx", notes("pickers", "broken"), "Broken links")
map("n", "<leader>lf", obsidian("footnotes"), "Footnotes")
map("n", "<leader>lg", function()
	Snacks.lazygit()
end, "Open LazyGit")
map("n", "<leader>lv", obsidian("follow_link vsplit"), "Follow in a vertical split")
map("n", "<leader>ls", obsidian("follow_link hsplit"), "Follow in a split")

-- f: find ---------------------------------------------------------------------------------
-- In a vault these search the notes; elsewhere the folder Neovim is in.
map("n", "<leader>ff", either(notes("pickers", "switch"), function()
	Snacks.picker.files()
end), "Find files (notes in a vault)")
map("n", "<leader>fs", either(notes("pickers", "grep"), function()
	Snacks.picker.grep()
end), "Find string (in the notes in a vault)")
map("n", "<leader>fc", either(function()
	require("notes.pickers").grep({ search = vim.fn.expand("<cword>") })
end, function()
	Snacks.picker.grep_word()
end), "Find word under cursor")
map("x", "<leader>fc", function()
	Snacks.picker.grep_word({ cwd = in_vault() and root() or nil })
end, "Find selection")
map("n", "<leader>fr", either(notes("pickers", "recent"), function()
	Snacks.picker.recent()
end), "Recent files (notes in a vault)")
map("n", "<leader>fF", function()
	Snacks.picker.files()
end, "Files in this folder")
map("n", "<leader>fb", function()
	Snacks.picker.buffers()
end, "Find open buffers")
map("n", "<leader>ft", notes("pickers", "tags"), "Tags")
map("n", "<leader>fh", notes("pickers", "headings"), "Headings everywhere")
map("n", "<leader>fo", obsidian("toc"), "Outline of this note")
map("n", "<leader>fp", obsidian("properties"), "Properties")
map("n", "<leader>fm", obsidian("bookmarks"), "Bookmarks")
map("n", "<leader>fa", notes("pickers", "attachments"), "Attachments")
map("n", "<leader>fO", notes("pickers", "orphans"), "Orphans")
map("n", "<leader>fU", notes("pickers", "untagged"), "Notes without tags")
map("n", "<leader>fk", function()
	Snacks.picker.keymaps()
end, "Keymaps")
map("n", "<leader>fH", function()
	Snacks.picker.help()
end, "Neovim help")
map("n", "<leader>f.", function()
	Snacks.picker.resume()
end, "Last picker again")

-- t: tasks -----------------------------------------------------------------------------------
map("n", "<leader>tt", function()
	require("notes.agenda").open({ filter = false })
end, "Agenda")
map("n", "<leader>ta", notes("tasks", "capture"), "Add a task")
map("n", "<leader>tx", notes("tasks", "toggle_current"), "Done / not done (or make it a task)")
map("x", "<leader>tx", function()
	vim.cmd("normal! \27")
	require("notes.tasks").toggle_range(vim.fn.line("'<"), vim.fn.line("'>"))
end, "Done / not done")
map("n", "<leader>tc", notes("tasks", "cycle_current"), "Next status")
map("n", "<leader>td", notes("tasks", "date_current", "due"), "Due date")
map("n", "<leader>ts", notes("tasks", "date_current", "scheduled"), "Scheduled date")
map("n", "<leader>tS", notes("tasks", "date_current", "start"), "Start date")
map("n", "<leader>tp", notes("tasks", "priority_current"), "Priority")
map("n", "<leader>tr", notes("tasks", "recur_current"), "Repeat")
map("n", "<leader>tl", notes("pickers", "tasks"), "List tasks")
map("n", "<leader>tT", notes("todoist", "capture"), "Add to Todoist")
map("n", "<leader>tm", notes("todoist", "send_current"), "Send this task to Todoist")
map("n", "<leader>to", function()
	local item = require("notes.todoist").at_cursor()
	if item then
		vim.ui.open(require("notes.todoist").url(item.id))
	else
		vim.ui.open("https://app.todoist.com/app/today")
	end
end, "Open in Todoist")
map("n", "<leader>tk", notes("pickers", "boards"), "Kanban boards")
map("n", "<leader>tK", notes("kanban", "open"), "This note as a board")
local function next_task(step)
	return function()
		vim.fn.search([=[^\s*[-*+]\s\+\[[ /!]\]]=], step > 0 and "W" or "bW")
	end
end
map("n", "]t", next_task(1), "Next open task")
map("n", "[t", next_task(-1), "Previous open task")

-- p: panels ------------------------------------------------------------------------------------
map("n", "<leader>pp", notes("panel", "toggle"), "Context panel")
map("n", "<leader>pf", notes("panel", "focus"), "Go to the context panel")
map("n", "<leader>po", notes("panel", "focus", "outline"), "Outline")
map("n", "<leader>pb", notes("panel", "focus", "backlinks"), "Backlinks")
map("n", "<leader>pm", notes("panel", "focus", "mentions"), "Unlinked mentions")
map("n", "<leader>pe", function()
	Snacks.explorer({ cwd = root() })
end, "File explorer")
map("n", "<leader>pg", notes("graph", "open"), "Graph (browser)")
map("n", "<leader>pl", notes("graph", "open", { mode = "local" }), "Local graph (browser)")
map("n", "<leader>pt", notes("graph", "tree"), "Neighbourhood (terminal)")
map("n", "<leader>pc", notes("calendar", "open"), "Calendar")
map("n", "<leader>ph", notes("home", "open"), "Start screen")
map("n", "<leader>pn", function()
	Snacks.notifier.show_history()
end, "Notifications")

-- i: insert --------------------------------------------------------------------------------------
map("n", "<leader>it", obsidian("template"), "Template")
map("n", "<leader>ip", either(function()
	-- An image from the clipboard, otherwise a URL or file path to one.
	vim.cmd("Obsidian paste_img")
end, function()
	vim.cmd("PasteImage") -- into images/ next to the file
end), "Paste image from clipboard")
map("n", "<localleader>p", "<cmd>PasteImage<cr>", "Paste image from clipboard")
map("n", "<leader>iP", "<cmd>PasteImage<cr>", "Image from a copied URL or path")
-- Your previous config's Inkscape figure: the current line names it, your template
-- (~/dotfiles/templates/figure.svg) opens in Inkscape, the line becomes the link.
-- Into images/ next to the file, or in a vault into its attachments folder.
local figure = either(notes("figure", "open"), function()
	require("utils.figure").create()
end)
map("n", "<leader>if", figure, "Inkscape figure from current line")
map("i", "<C-f>", figure, "Inkscape figure from current line")
map("n", "<leader>iw", notes("canvas", "new"), "Canvas (Excalidraw)")
map("n", "<leader>im", notes("canvas", "mindmap"), "Mind map of this list or the headings")
map("x", "<leader>im", function()
	vim.cmd("normal! \27")
	require("notes.canvas").mindmap(vim.fn.line("'<"), vim.fn.line("'>"))
end, "Mind map of the selection")
map("n", "<leader>ia", action("add_attachment"), "Attachment (file or URL)")
map("n", "<leader>ir", action("toggle_recording"), "Start / stop an audio recording")
map("n", "<leader>il", notes("pickers", "insert_link"), "Link")
map("n", "<leader>ie", notes("pickers", "insert_link", true), "Embed a note or section")
map("n", "<leader>ig", action("insert_tag"), "Tag")
map("n", "<leader>iG", action("add_tag"), "Tag in the properties")
map("n", "<leader>id", function()
	local win, pos = vim.api.nvim_get_current_win(), vim.api.nvim_win_get_cursor(0)
	require("notes.calendar").open({
		title = "Insert a date",
		on_pick = function(iso)
			vim.api.nvim_set_current_win(win)
			vim.api.nvim_win_set_cursor(win, pos)
			vim.api.nvim_put({ "[[" .. require("notes.date").format(iso, require("settings").daily_format) .. "]]" }, "c", true, true)
		end,
	})
end, "Date (from a calendar)")
map("n", "<leader>iT", function()
	vim.api.nvim_put({ os.date("%H:%M") }, "c", true, true)
end, "Time")
map("n", "<leader>iq", "<Plug>(MarkdownPlusInsertCallout)", "Callout")
map("x", "<leader>iq", "<Plug>(MarkdownPlusInsertCallout)", "Wrap in a callout")
map("n", "<leader>ib", "<Plug>(MarkdownPlusTableCreate)", "Table")
map("n", "<leader>ic", "<Plug>(MarkdownPlusCodeBlockInsert)", "Code block")
map("n", "<leader>in", "<Plug>(MarkdownPlusFootnoteInsert)", "Footnote")
map("n", "<leader>iz", notes("zotero", "pick"), "Citation / literature note")
map("n", "<leader>ij", "<cmd>lua Snacks.picker.icons()<cr>", "Emoji or icon")

-- c: cards ------------------------------------------------------------------------------------------
map("n", "<leader>kk", notes("cards", "review"), "Review due cards")
map("n", "<leader>kd", notes("cards", "decks"), "Choose a deck")
map("n", "<leader>kn", notes("cards", "review_note"), "Review this note")
map("n", "<leader>ks", notes("cards", "stats"), "Statistics")

-- v: view ---------------------------------------------------------------------------------------------
map("n", "<leader>vz", function()
	Snacks.zen()
end, "Zen mode")
map("n", "<leader>vr", "<cmd>RenderMarkdown buf_toggle<cr>", "Rendering on / off")
map("n", "<leader>vq", notes("blocks", "toggle"), "Query results on / off")
map("n", "<leader>vn", function()
	local on = not vim.wo.number
	vim.wo.number, vim.wo.relativenumber = on, on
end, "Line numbers")
map("n", "<leader>vs", function()
	vim.wo.spell = not vim.wo.spell
	require("notes.util").notify("Spelling " .. (vim.wo.spell and "on" or "off"))
end, "Spelling")
map("n", "<leader>vg", function()
	local on = not vim.lsp.is_enabled("harper_ls")
	vim.lsp.enable("harper_ls", on)
	require("notes.util").notify("Grammar " .. (on and "on" or "off"))
end, "Grammar")
map("n", "<leader>vl", function()
	local langs = { "en_gb", "en_us", "de", "en_gb,de", "fr", "es", "nl", "it" }
	vim.ui.select(langs, { prompt = "Spelling language" }, function(lang)
		if lang then
			vim.opt_local.spelllang = lang
			vim.wo.spell = true
		end
	end)
end, "Spelling language")
map("n", "<leader>vw", function()
	vim.wo.wrap = not vim.wo.wrap
end, "Wrap")
map("n", "<leader>vt", function()
	local on = vim.o.scrolloff < 100
	vim.o.scrolloff = on and 999 or 6
	require("notes.util").notify("Typewriter scrolling " .. (on and "on" or "off"))
end, "Typewriter scrolling")
map("n", "<leader>vd", function()
	if Snacks.dim.enabled then
		Snacks.dim.disable()
	else
		Snacks.dim.enable()
	end
end, "Dim other paragraphs")
map("n", "<leader>vc", function()
	vim.wo.conceallevel = vim.wo.conceallevel == 0 and 2 or 0
end, "Show markup")
map("n", "<leader>vi", function()
	Snacks.image.hover()
end, "Image under the cursor")

-- g: git ------------------------------------------------------------------------------------------------
map("n", "<leader>gs", notes("sync", "sync"), "Sync vault (commit, pull, push)")
map("n", "<leader>gg", function()
	Snacks.lazygit({ cwd = root() })
end, "Lazygit")
map("n", "<leader>gl", function()
	Snacks.picker.git_log_file()
end, "History of this note")
map("n", "<leader>gL", function()
	Snacks.picker.git_log({ cwd = root() })
end, "History of the vault")
map("n", "<leader>gd", function()
	require("gitsigns").diffthis()
end, "Changes to this note")
map("n", "<leader>gt", function()
	require("gitsigns").toggle_signs()
end, "Change signs on / off")
map("n", "<leader>gb", function()
	require("gitsigns").blame_line({ full = true })
end, "Who and when")
map("n", "<leader>gi", notes("sync", "init"), "Make the vault a git repository")

-- x: export ---------------------------------------------------------------------------------------------------
map("n", "<leader>xe", notes("export", "pick"), "Export…")
map("n", "<leader>xp", "<cmd>MarkdownPreviewToggle<cr>", "Preview in the browser")
map("n", "<leader>xs", action("start_presentation"), "Present as slides")
map("n", "<leader>xo", obsidian("open"), "Open in the Obsidian app")
map("n", "<leader>xf", "<cmd>Export pdf<cr>", "Export PDF")

-- r: refactor ----------------------------------------------------------------------------------------------------
map("n", "<leader>rr", function()
	require("grug-far").open({ prefills = { paths = root(), filesFilter = "*.md" } })
end, "Search and replace in the vault")
map("x", "<leader>rr", function()
	require("grug-far").with_visual_selection({ prefills = { paths = root(), filesFilter = "*.md" } })
end, "Replace selection in the vault")
map("n", "<leader>rt", notes("refactor", "rename_tag"), "Rename a tag everywhere")
map("n", "<leader>re", notes("refactor", "extract_section"), "Section to its own note")
map("n", "<leader>rE", notes("refactor", "extract_section", true), "Section to its own note, embedded")
map("x", "<leader>re", action("extract_note"), "Selection to its own note")
map({ "n", "x" }, "<leader>rf", function()
	require("conform").format({ async = true })
end, "Tidy formatting")
map("n", "<leader>rw", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]], "Replace word in this note", { silent = false })

-- w: vault ----------------------------------------------------------------------------------------------------------
map("n", "<leader>ww", obsidian("workspace"), "Switch vault")
map("n", "<leader>wr", function()
	require("notes.index").refresh()
	vim.cmd("Obsidian rebuild_cache")
	vim.api.nvim_exec_autocmds("User", { pattern = "NotesChanged", data = {} })
end, "Re-read the vault")
map("n", "<leader>wo", function()
	vim.ui.open(root())
end, "Open in the file manager")
map("n", "<leader>ws", function()
	vim.cmd.edit(vim.fn.stdpath("config") .. "/lua/settings.lua")
end, "Settings")
map("n", "<leader>wh", "<cmd>checkhealth notes obsidian<cr>", "Health")

-- z: zotero (zotcite adds zo zv zi za zb in notes) ------------------------------------------------------------------
map("n", "<leader>zz", notes("zotero", "pick"), "Zotero: literature note or citation")
map("n", "<leader>zu", notes("zotero", "update_annotations"), "Zotero: add new annotations")

-- s: splits, spelling, replacing ----------------------------------------------------------------------------------------------
-- <leader>s alone (after a pause) replaces the word under the cursor, as in your previous config.
map("n", "<leader>s", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]], "Replace current word", { silent = false })
map("n", "<leader>sv", "<C-w>v", "Split vertically")
map("n", "<leader>sh", "<C-w>s", "Split horizontally")
map("n", "<leader>se", "<C-w>=", "Same size")
map("n", "<leader>sx", "<cmd>close<cr>", "Close split")
map("n", "<leader>ss", function()
	Snacks.picker.spelling()
end, "Spelling suggestions")
map("n", "<leader>sa", "zg", "Add word to the dictionary")
map("i", "<C-l>", "<C-g>u<Esc>[s1z=`]a<C-g>u", "Fix the last spelling mistake")

-- Moving around -----------------------------------------------------------------------------------------------------------
for _, key in ipairs({ "h", "j", "k", "l" }) do
	map("n", "<C-" .. key .. ">", notes("navigate", "move", key), "Window or pane")
end
map({ "n", "x" }, "j", "v:count == 0 ? 'gj' : 'j'", "Down", { expr = true })
map({ "n", "x" }, "k", "v:count == 0 ? 'gk' : 'k'", "Up", { expr = true })
map("n", "<C-d>", "<C-d>zz", "Half page down")
map("n", "<C-u>", "<C-u>zz", "Half page up")
map("n", "<BS>", "<C-o>", "Back")
map("n", "<S-h>", "<cmd>bprevious<cr>", "Previous buffer")
map("n", "<S-l>", "<cmd>bnext<cr>", "Next buffer")
map("n", "<Esc>", "<cmd>nohlsearch<cr><Esc>", "Clear search")

-- Editing --------------------------------------------------------------------------------------------------------------------
-- In insert and visual mode Ctrl-S belongs to snippets (plugins/completion.lua).
map("n", "<C-s>", "<cmd>silent update<cr>", "Save")
map("x", "p", '"_dP', "Paste, keep the register")
map("x", "J", ":m '>+1<CR>gv=gv", "Move lines down")
map("x", "K", ":m '<-2<CR>gv=gv", "Move lines up")
map("x", "<", "<gv", "Outdent")
map("x", ">", ">gv", "Indent")
map("n", "gl", function()
	vim.diagnostic.open_float({ scope = "line" })
end, "What's wrong here")
-- In prose, undo goes back a sentence at a time.
vim.api.nvim_create_autocmd("FileType", {
	group = vim.api.nvim_create_augroup("config_prose_undo", { clear = true }),
	pattern = { "markdown", "quarto", "text", "gitcommit" },
	callback = function(ev)
		for _, char in ipairs({ ",", ".", "!", "?", ";", ":" }) do
			vim.keymap.set("i", char, char .. "<C-g>u", { buffer = ev.buf })
		end
	end,
})
