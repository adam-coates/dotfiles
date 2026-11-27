-- The one file to edit. Everything else reads from here.

local M = {}

-- Vaults ---------------------------------------------------------------------
-- A vault is just a folder of markdown files (an existing Obsidian vault works
-- as is). The first one that contains the current directory is used, otherwise
-- the first in the list. $NOTES_VAULT goes in front of all of them.
--
-- A vault can have its own folders, templates, weekly_format and ask_location;
-- whatever it leaves out comes from the defaults further down.
M.vaults = {
	{
		name = "notes",
		path = "~/notes",
		folders = {
			inbox = "00 - Inbox",
			notes = "00 - Inbox",
			daily = "03 - Logs/Daily",
			weekly = "03 - Logs/Weekly Review",
			monthly = "03 - Logs/Monthly",
			yearly = "03 - Logs/Yearly",
			templates = "999-extra/Templates",
			attachments = "999-extra/Attachments",
			canvas = "999-extra/Excalidraw",
			boards = "999-extra/Boards",
			literature = "01 - Library/Literature Notes",
			people = "05 - People",
			export = "999-extra/Export",
		},
		templates = { weekly = "weekly review" },
		weekly_format = "YYYY_MM_DD", -- named after the Monday, like 2026_01_12
		-- New notes ask where they belong, are made there, and get it as `location`.
		ask_location = true,
	},
	{ name = "demo", path = "~/nvim-test-vault" },
}

-- Create the first vault from vault-template/ when its folder doesn't exist.
M.create_missing_vault = true

-- Folders, relative to the vault ----------------------------------------------
M.folders = {
	inbox = "Inbox", -- new notes and quick captures
	notes = "Notes",
	daily = "Journal/Daily",
	weekly = "Journal/Weekly",
	monthly = "Journal/Monthly",
	yearly = "Journal/Yearly",
	templates = "Templates",
	attachments = "Attachments",
	canvas = "Canvas", -- drawings, mind maps, boards of note cards
	boards = "Boards",
	literature = "Literature",
	people = "People",
	export = "Export",
}

-- Template file (in folders.templates) used for each kind of note. A missing
-- template just means an empty note.
M.templates = {
	note = "note",
	daily = "daily",
	weekly = "weekly",
	monthly = "monthly",
	yearly = "yearly",
	literature = "literature",
	board = "board",
	person = "person",
}

-- Dates ------------------------------------------------------------------------
M.daily_format = "YYYY-MM-DD"
M.weekly_format = nil -- nil: ISO weeks (2026-W48); or a date format for the week's Monday
M.week_start = 1 -- 1 Monday, 0 Sunday

-- New notes: ask for a location (folder) and tags, and write them in the
-- properties. Usually set per vault, above.
M.ask_location = false

-- Writing ------------------------------------------------------------------------
M.spelllang = "en_gb"
M.spell = true
M.autosave = true -- save notes when you pause, like Obsidian does
M.numbers = false -- line numbers in notes (<leader>vn toggles)
M.mouse = false -- as in your previous config; true to click links, panels and pickers
M.readable_width = 90 -- text width in zen mode
M.grammar = true -- Harper grammar checker (<leader>vg toggles)
M.grammar_dialect = "British" -- American, British, Australian, Canadian, Indian

-- Tasks ----------------------------------------------------------------------
-- Where <leader>ta puts a task: "daily" (today's note), "inbox" (a Tasks note
-- in the inbox), "todoist", or a path relative to the vault.
M.task_capture = "daily"
M.task_heading = "Tasks" -- heading in that note to add it under
M.agenda_days = 7 -- how far "Upcoming" looks ahead

-- Todoist ---------------------------------------------------------------------------
-- Connect with :TodoistToken (or $TODOIST_API_TOKEN). Its tasks then show in the
-- agenda, the calendar and ```todoist blocks, next to the tasks in your notes.
M.todoist = {
	enabled = true,
	filter = "overdue | next 7 days", -- what the agenda shows (Todoist's filter syntax)
	refresh_minutes = 5,
}

-- Images, drawings and diagrams in the terminal ----------------------------------
-- "auto" turns them on where the terminal can draw them (Ghostty, kitty, ..., also
-- inside herdr). true and false force it.
M.images = "auto"

-- Look -----------------------------------------------------------------------------
M.follow_omarchy = true -- use (and live-switch with) the current Omarchy theme
M.colorscheme = "gruvbox-material" -- otherwise, or when Omarchy isn't there
M.transparent = true

-- The start screen: "default" (your previous config's dashboard, `o` opens the notes
-- one), "notes", or "auto" (the notes one when Neovim starts inside a vault).
M.start_screen = "default"

-- Panels opened with the first note of a session: "context", "explorer"
M.open_panels = { "context" }
M.panel_width = 40

-- Git sync ---------------------------------------------------------------------------
-- Only in a vault that is a git repository (~/notes: github.com/adam-coates/notes).
M.sync = {
	on_start = true, -- pull (and push what's new) when Neovim starts
	on_quit = true, -- commit and push when Neovim quits
	auto_minutes = 5, -- and every few minutes in between; 0 = only on <leader>gs
	pull = true,
	push = true,
	message = "vault: %Y-%m-%d %H:%M", -- strftime
}

-- Flashcards ---------------------------------------------------------------------------
M.cards = {
	tag = "flashcards", -- notes with #flashcards (or #flashcards/deck) hold cards
	new_per_day = 20,
}

-- Zotero ---------------------------------------------------------------------------------
-- Citation keys and literature notes; switched off when the database is missing.
M.zotero = {
	database = "~/Zotero/zotero.sqlite",
	attachments = "~/Nextcloud/zotero",
}

return M
