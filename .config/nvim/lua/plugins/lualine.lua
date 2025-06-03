return {
	"nvim-lualine/lualine.nvim",
	dependencies = {
		"nvim-tree/nvim-web-devicons",
		"meuter/lualine-so-fancy.nvim",
	},
	enabled = true,
	lazy = false,
	event = { "bufreadpost", "bufnewfile" },
	config = function()
		local lazy_status = require("lazy.status")

		-- Word count functions
		local function wordcount()
			local wc_table = vim.fn.wordcount()

			-- If in visual mode and visual_words exists, show selection word count
			if wc_table.visual_words then
				return wc_table.visual_words .. " words selected"
			else
				-- Regular word count
				return tostring(wc_table.words) .. " words"
			end
		end

		local function readingtime()
			local wc_table = vim.fn.wordcount()
			local words = wc_table.visual_words or wc_table.words
			return tostring(math.ceil(words / 200.0)) .. " min"
		end

		local function is_markdown()
			return vim.bo.filetype == "markdown" or vim.bo.filetype == "asciidoc" or vim.bo.filetype == "quarto"
		end

		-- Scrollbar function - shows position in file with unicode block characters
		local function scrollbar()
			local sbar_chars = {
				"▔", -- top
				"🮂",
				"🬂",
				"🮃",
				"▀",
				"▄",
				"▃",
				"🬭",
				"▂",
				"▁", -- bottom
			}

			local cur_line = vim.api.nvim_win_get_cursor(0)[1]
			local lines = vim.api.nvim_buf_line_count(0)

			local i = math.floor((cur_line - 1) / lines * #sbar_chars) + 1
			return string.rep(sbar_chars[i], 2)
		end

		require("lualine").setup({
			options = {
				theme = "auto",
				globalstatus = true,
				icons_enabled = true,
				component_separators = { left = "|", right = "|" },
				section_separators = { left = "", right = "" },
				disabled_filetypes = {
					statusline = {
						"help",
						"nvim-tree",
						"toggleterm",
					},
					winbar = {},
				},
			},
			sections = {
				lualine_a = { { "fancy_mode", width = 1 } },
				lualine_b = {
					"fancy_branch",
					"fancy_diff",
				},
				lualine_c = {
					{
						"filename",
						symbols = {
							modified = "  ",
							readonly = "  ",
							unnamed = "  ",
						},
					},
					{ "fancy_searchcount" },
				},
				lualine_x = {
					{
						"fancy_diagnostics",
						sources = { "nvim_lsp" },
						symbols = { Error = " ", Warn = " ", Hint = "󰠠 ", Info = " " },
					},
					"g:obsidian",
					-- Add word count and reading time for markdown files
					{ wordcount, cond = is_markdown },
					{ readingtime, cond = is_markdown },
					-- Replace progress with scrollbar
					{ scrollbar },
				},
				lualine_y = { "fancy_filetype" },
				lualine_z = {
					{
						lazy_status.updates,
						cond = lazy_status.has_updates,
						color = { fg = "#ff9e64" },
					},
				},
			},
			inactive_sections = {
				lualine_a = {},
				lualine_b = {},
				lualine_c = { "filename" },
				lualine_y = {},
				lualine_z = {},
			},
			tabline = {},
			extensions = { "nvim-tree", "lazy" },
		})
	end,
}

