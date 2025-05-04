return {
	"obsidian-nvim/obsidian.nvim",
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
		notes_subdir = "00 - Inbox", --all new notes go into the inbox
		attachments = {
			img_folder = "999 - extra/images",
		},
		new_notes_location = "notes_subdir",
		disable_frontmatter = false,

		-- Optional, customize the frontmatter data for new notes.
		---@return table
		note_frontmatter_func = function(note)
			-- Create a formatted date string for today in DD-MM-YYYY format
			local current_date = os.date("%d-%m-%Y")

			-- Define the frontmatter table with fields in the desired order
			-- NOTE: This won't guarantee field order in all versions of Lua/Neovim
			-- But will work in many common configurations
			local out = {}

			-- Set the fields in our desired order
			out.title = note.title or ""
			out.tags = { "" } -- This creates a YAML array with an empty item, which renders as "- "
			out.location = ""
			out.date = current_date

			-- Preserve any existing metadata if present
			if note.metadata ~= nil and not vim.tbl_isempty(note.metadata) then
				for k, v in pairs(note.metadata) do
					if k ~= "title" and k ~= "tags" and k ~= "location" and k ~= "date" then
						out[k] = v
					end
				end
			end

			return out
		end,

		-- Optional, customize how note IDs are generated given an optional title.
		---@param title string|?
		---@return string
		note_id_func = function(title)
			-- Simply return the title exactly as is without any transformations
			if title then
				return title
			else
				-- If no title, generate a random ID
				local suffix = ""
				for _ = 1, 4 do
					suffix = suffix .. string.char(math.random(65, 90))
				end
				return "untitled_" .. suffix
			end
		end,
		-- Optional, customize how note file names are generated given the ID, target directory, and title.
		---@param spec { id: string, dir: obsidian.Path, title: string|? }
		---@return string|obsidian.Path The full path to the new note.
		-- note_path_func = function(spec)
		-- 	-- Use the id (which is now the untransformed title) directly
		-- 	local id_str = tostring(spec.id)
		--
		-- 	-- Add .md extension only if it doesn't already have one
		-- 	if not string.match(id_str, "%.md$") then
		-- 		return spec.dir / (id_str .. ".md")
		-- 	else
		-- 		-- If it already ends with .md, use as is
		-- 		return spec.dir / id_str
		-- 	end
		-- end,
		statusline = {
			enabled = true,
			format = "{{backlinks}} backlinks",
		},
	},
}
