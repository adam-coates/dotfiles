return {
	"obsidian-nvim/obsidian.nvim",
	version = "*", -- recommended, use latest release instead of latest commit
	lazy = true,
	ft = "markdown",
	dependencies = {
		"nvim-lua/plenary.nvim",
		"saghen/blink.cmp",
		"nvim-telescope/telescope.nvim",
		"nvim-treesitter/nvim-treesitter",
	},
	opts = {
		workspaces = {
			{
				name = "notes",
				path = "~/notes",
			},
		},
		open_notes_in = "vsplit",
		disable_frontmatter = true,
		ui = { enable = false },
		completion = {
			nvim_cmp = false,
			blink = true,
			min_chars = 2,
		},

		templates = {
			folder = "999 - extra/Templates",
			date_format = "%d-%m-%Y",
			substitutions = {
				citation_title = function()
					vim.cmd("FindCitation")
				end,
			},
		},
		-- Optional, customize how note IDs are generated given an optional title.
		---@param title string|?
		---@return string
		note_id_func = function(title)
			-- If a title is given, use it as the ID (convert to lowercase, replace spaces with dashes)
			if title ~= nil then
				return title:gsub(" ", "-"):gsub("[^A-Za-z0-9-]", ""):lower()
			else
				-- If no title is provided, return a default value like 'untitled'
				return "untitled"
			end
		end,

		-- Optional, customize how note file names are generated given the ID, target directory, and title.
		---@param spec { id: string, dir: obsidian.Path, title: string|? }
		---@return string|obsidian.Path The full path to the new note.
		note_path_func = function(spec)
			-- Use the `id` (which is just the sanitized title) for the file name.
			local path = spec.dir / spec.id
			return path:with_suffix(".md")
		end,
	},
}
