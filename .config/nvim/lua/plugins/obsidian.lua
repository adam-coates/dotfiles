return {
	"obsidian-nvim/obsidian.nvim",
	version = "*",
	lazy = true,
	ft = "markdown",
	dependencies = {
		"hrsh7th/nvim-cmp",
		"nvim-telescope/telescope.nvim",
		"nvim-treesitter/nvim-treesitter",
	},
	keys = {
		{ "<leader>os", ":Obsidian search<cr>", desc = "Obsidian Search" },
	},
	opts = {
		legacy_commands = false,
		workspaces = {
			{
				name = "notes",
				path = "~/notes",
			},
		},
		open_notes_in = "vsplit",
		ui = { enable = false },
		completion = {
			nvim_cmp = true,
			blink = false,
			min_chars = 2,
		},
		templates = {
			enabled = true,
			folder = "999-extra/Templates",
			date_format = "%Y-%m-%d",
		},
		notes_subdir = "00 - Inbox",
		attachments = {
			folder = "999-extra/images",
		},
		new_notes_location = "notes_subdir",
		link = {
			style = "markdown",
		},
		frontmatter = {
			enabled = true,
		},
		note_id_func = function(title)
			if title then
				return title
			else
				local suffix = ""
				for _ = 1, 4 do
					suffix = suffix .. string.char(math.random(65, 90))
				end
				return "untitled_" .. suffix
			end
		end,
		note = {
			template = "note.md",
			id_func = function(title)
				if title then
					return title
				else
					local suffix = ""
					for _ = 1, 4 do
						suffix = suffix .. string.char(math.random(65, 90))
					end
					return "untitled_" .. suffix
				end
			end,
		},
		footer = {
			enabled = true,
			separator = "",
			format = "{{backlinks}} backlinks",
		},
		daily_notes = {
			enabled = true,
			folder = "03 - Logs/Daily",
			date_format = "YYYY-MM-DD",
			default_tags = { "Daily" },
			workdays_only = false,
			template = "999-extra/Templates/daily.md",
		},
	},
}
