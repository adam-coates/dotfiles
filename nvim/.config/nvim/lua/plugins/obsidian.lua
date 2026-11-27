-- obsidian.nvim is the note engine. It works with any folder of markdown files and
-- with existing Obsidian vaults; the Obsidian app isn't needed.

local settings = require("settings")
local vault = require("notes.vault")
local template = require("notes.template")

-- Each vault with its own folders and templates (settings.vaults).
local function overrides(v)
	local s = vault.settings_for(v)
	local f, t = s.folders, s.templates
	local function tpl(key)
		return t[key] and (t[key] .. ".md") or nil
	end
	return {
		notes_subdir = f.inbox,
		note = { template = tpl("note") },
		daily_notes = { folder = f.daily, date_format = s.daily_format, template = tpl("daily") },
		unique_note = { folder = f.inbox, template = tpl("note") },
		templates = {
			folder = f.templates,
			customizations = { literature = { notes_subdir = f.literature }, person = { notes_subdir = f.people } },
		},
		attachments = { folder = f.attachments },
		file = { ignore_filters = { f.export .. "/**", ".trash/**" } },
	}
end

local workspaces = {}
for _, v in ipairs(vault.prepare()) do
	workspaces[#workspaces + 1] = { name = v.name, path = v.path, overrides = overrides(v) }
end
if #workspaces == 0 then
	vim.schedule(function()
		vim.notify("No vault found. Set M.vaults in lua/settings.lua", vim.log.levels.WARN)
	end)
	return
end

-- Every {{variable}} of notes.template. For daily notes the date is the note's
-- own, so {{yesterday}} in last Tuesday's note is last Monday.
local substitutions = {}
for name, fn in pairs(template.variables) do
	substitutions[name] = function(ctx, suffix)
		local note = ctx and ctx.partial_note
		local iso = note and tostring(note.id or ""):match("^%d%d%d%d%-%d%d%-%d%d$")
		return fn(iso or require("notes.date").today(), suffix)
	end
end

-- {{location}}: the folder the new note is in. {{tags}}: its tags, as [a, b].
substitutions.location = function(ctx)
	local path = ctx and (ctx.destination_path or (ctx.partial_note and ctx.partial_note.path))
	local rel = path and vault.rel(tostring(path))
	return rel and rel:match("^(.*)/[^/]+$") or ""
end
substitutions.tags = function(ctx)
	return require("notes.util").yaml_tags(ctx and ctx.partial_note and ctx.partial_note.tags or {})
end
substitutions.title_yaml = function(ctx)
	local note = ctx and ctx.partial_note
	return require("notes.util").yaml_scalar(note and (note.title or note.id) or "")
end

-- Until obsidian.nvim has picked a vault, the first one's settings.
vault.apply(workspaces[1].path)

-- A template only when its file exists; obsidian.nvim errors on missing ones.
local function tpl(key)
	local name = settings.templates[key]
	return name and (name .. ".md") or nil
end

require("obsidian").setup({
	legacy_commands = false,
	workspaces = workspaces,
	log_level = vim.log.levels.WARN,

	-- Notes are named after their title and their properties are yours: nothing is
	-- added to a note when it is saved.
	notes_subdir = settings.folders.inbox,
	new_notes_location = "notes_subdir",
	note_id_func = function(title)
		return require("notes.util").filename(title or os.date("%Y-%m-%d %H%M%S"))
	end,
	frontmatter = { enabled = false },
	note = { template = tpl("note") },

	link = {
		-- [[Note]], [[Note|alias]], and [[Note#Heading]] without a label
		style = function(opts)
			local stem = tostring(opts.path or ""):gsub("%.md$", "")
			if opts.anchor or opts.block then
				opts = vim.tbl_extend("force", opts, { label = stem })
				for _, key in ipairs({ "anchor", "block" }) do
					if type(opts[key]) == "table" then
						opts[key] = key == "anchor" and opts[key].anchor or ("#" .. opts[key].id)
					end
				end
			end
			return require("obsidian.builtin").wiki_link(opts)
		end,
		format = "shortest",
		auto_update = true,
	},
	picker = { name = "snacks.picker" },
	file = { ignore_filters = { settings.folders.export .. "/**", ".trash/**" } },
	cache = { enabled = true },
	completion = { min_chars = 0, match_case = false, create_new = true },
	backlinks = { parse_headers = true },
	search = { sort_by = "modified", sort_reversed = true },

	daily_notes = {
		folder = settings.folders.daily,
		date_format = settings.daily_format,
		default_tags = {},
		template = tpl("daily"),
		workdays_only = false,
		start_of_week = settings.week_start,
	},
	unique_note = { format = "YYYYMMDDHHmm", folder = settings.folders.inbox, template = tpl("note") },
	templates = {
		folder = settings.folders.templates,
		date_format = "YYYY-MM-DD",
		time_format = "HH:mm",
		substitutions = substitutions,
		customizations = {
			literature = { notes_subdir = settings.folders.literature },
			project = { notes_subdir = "Projects" },
			meeting = { notes_subdir = "Meetings" },
			person = { notes_subdir = "People" },
		},
	},
	attachments = {
		folder = settings.folders.attachments,
		confirm_img_paste = false,
		-- With the folder, so the embed stays unambiguous.
		img_text_func = function(path)
			local rel = require("notes.vault").rel(tostring(path))
			return "![[" .. (rel or vim.fs.basename(tostring(path))) .. "]]"
		end,
	},
	checkbox = { enabled = true, create_new = false, order = { " ", "/", "x", "-" } },

	-- render-markdown draws, the panel and the statusline count.
	ui = { enable = false },
	footer = { enabled = false },
	statusline = { enabled = false },

	open = { schemes = { "https", "http", "file", "mailto", "zotero", "obsidian" } },
	callbacks = {
		post_set_workspace = function(workspace)
			-- Folders, templates and formats follow the vault.
			vault.apply(tostring(workspace.root))
			vim.schedule(function()
				require("notes.index").refresh()
				vim.api.nvim_exec_autocmds("User", { pattern = "NotesChanged", data = {} })
			end)
		end,
	},
})

-- Embedded notes are drawn as virtual lines, which Neovim doesn't wrap, so wrap
-- them to the window here.
local ts = require("obsidian.ts")
local to_virt_lines = ts.to_virt_lines
local function wrap(line, width)
	local total = 0
	for _, chunk in ipairs(line) do
		total = total + vim.fn.strdisplaywidth(chunk[1])
	end
	if total <= width then
		return { line }
	end
	local out, current, used = {}, {}, 0
	for _, chunk in ipairs(line) do
		-- Words with the spaces after them
		for word in chunk[1]:gmatch("%s*%S+%s*") do
			local w = vim.fn.strdisplaywidth(word)
			if used + vim.fn.strdisplaywidth((word:gsub("%s+$", ""))) > width and used > 0 then
				out[#out + 1], current, used = current, {}, 0
				word = word:gsub("^%s+", "")
				w = vim.fn.strdisplaywidth(word)
			end
			current[#current + 1] = { word, chunk[2] }
			used = used + w
		end
		if chunk[1]:match("^%s+$") then
			current[#current + 1] = { chunk[1], chunk[2] }
			used = used + #chunk[1]
		end
	end
	out[#out + 1] = current
	return out
end
if type(to_virt_lines) == "function" then
	ts.to_virt_lines = function(...)
		local width = math.max(30, math.min(110, vim.api.nvim_win_get_width(0) - 4))
		local out = {}
		for _, line in ipairs(to_virt_lines(...)) do
			vim.list_extend(out, wrap(line, width))
		end
		return out
	end
end
