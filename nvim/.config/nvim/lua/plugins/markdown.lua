-- Drawing markdown, and editing it comfortably.

require("render-markdown").setup({
	file_types = { "markdown", "quarto" },
	-- Quarto divs and spans, styled from the document's css (your previous config's
	-- utils/quarto_render.lua). Runs alongside the builtin markdown rendering.
	custom_handlers = {
		markdown = {
			extends = true,
			parse = function(ctx)
				return require("utils.quarto_render").parse(ctx)
			end,
		},
	},
	render_modes = true, -- while typing too, except on the cursor line
	anti_conceal = { enabled = true, ignore = { code_background = true, sign = true, heading_background = true } },
	completions = { lsp = { enabled = true } }, -- checkboxes and callouts
	sign = { enabled = false },
	heading = {
		sign = false,
		position = "inline",
		icons = { "󰲡 ", "󰲣 ", "󰲥 ", "󰲧 ", "󰲩 ", "󰲫 " },
		width = "full",
		border = false,
	},
	code = {
		sign = false,
		width = "block",
		min_width = 60,
		left_pad = 1,
		right_pad = 2,
		language_pad = 1,
		border = "thin",
		inline_pad = 1,
		disable = { "tasks", "dataview", "todoist", "query" }, -- drawn by notes.blocks
	},
	dash = { width = "full" },
	bullet = { icons = { "•", "◦", "▪", "▫" } },
	checkbox = {
		unchecked = { icon = "󰄱 " },
		checked = { icon = "󰱒 ", scope_highlight = "NotesDone" },
		custom = {
			todo = { raw = "[-]", rendered = "󰜺 ", highlight = "NotesMuted", scope_highlight = "NotesDone" },
			progress = { raw = "[/]", rendered = "󰡖 ", highlight = "NotesYellow" },
			forwarded = { raw = "[>]", rendered = "󰒊 ", highlight = "NotesBlue" },
			scheduled = { raw = "[<]", rendered = "󰃰 ", highlight = "NotesBlue" },
			important = { raw = "[!]", rendered = "󰀦 ", highlight = "NotesRed" },
			question = { raw = "[?]", rendered = "󰘥 ", highlight = "NotesMagenta" },
			star = { raw = "[*]", rendered = "󰓎 ", highlight = "NotesYellow" },
			idea = { raw = "[i]", rendered = "󰌵 ", highlight = "NotesYellow" },
			quote = { raw = '["]', rendered = "󰉾 ", highlight = "NotesCyan" },
			pro = { raw = "[p]", rendered = "󰔓 ", highlight = "NotesGreen" },
			con = { raw = "[c]", rendered = "󰔑 ", highlight = "NotesRed" },
		},
	},
	quote = { repeat_linebreak = true },
	win_options = {
		showbreak = { default = "", rendered = "" },
		breakindent = { default = true, rendered = true },
		breakindentopt = { default = "list:-1", rendered = "list:-1" },
	},
	pipe_table = { preset = "round", cell = "padded" },
	link = {
		image = "󰥶 ",
		wiki = { icon = "", highlight = "RenderMarkdownWikiLink", scope_highlight = "RenderMarkdownWikiLink" },
		custom = {
			zotero = { pattern = "^zotero:", icon = "󰂺 " },
			pdf = { pattern = "%.pdf$", icon = "󰈦 " },
			doi = { pattern = "doi%.org", icon = "󰙨 " },
			arxiv = { pattern = "arxiv%.org", icon = "󰙨 " },
		},
	},
	latex = { enabled = true, converter = { "utftex", "latex2text" }, position = "below" },
	html = { comment = { conceal = true } },
})

require("markdown-plus").setup({
	filetypes = { "markdown", "quarto" },
	features = {
		list_management = true,
		text_formatting = true,
		headers_toc = true,
		links = true,
		images = true,
		quotes = true,
		callouts = true,
		code_block = true,
		table = true,
		footnotes = true,
	},
	links = { smart_paste = { enabled = true, timeout = 5 } },
	table = { auto_format = true },
})

-- Pasted and dropped images: in a vault note into the attachments folder as
-- ![[...]]; anywhere else into images/ next to the file, as in your previous config.
local function in_vault()
	return require("notes.vault").is_note(vim.api.nvim_buf_get_name(0))
end

require("img-clip").setup({
	default = {
		dir_path = function()
			return in_vault() and require("notes.vault").folder("attachments") or "images"
		end,
		use_absolute_path = in_vault,
		relative_to_current_file = function()
			return not in_vault()
		end,
		prompt_for_file_name = function()
			return not in_vault()
		end,
		file_name = function()
			return in_vault() and "Pasted image %Y%m%d%H%M%S" or "%Y-%m-%d-%H-%M-%S"
		end,
		copy_images = true, -- a pasted or dropped file is copied, not linked
		drag_and_drop = { enabled = true, insert_mode = true },
		show_dir_path_in_prompt = false,
	},
	filetypes = {
		markdown = {
			template = function(ctx)
				if in_vault() then
					return "![[" .. (require("notes.vault").rel(ctx.file_path) or ctx.file_name) .. "]]$CURSOR"
				end
				return "![$CURSOR]($FILE_PATH)"
			end,
			url_encode_path = false,
			download_images = true,
		},
		quarto = { template = "![$CURSOR]($FILE_PATH)", download_images = true },
	},
})

-- Browser preview (your fork), themed by the CSS Omarchy renders for it and
-- opened as an app window: your previous config's utils/markdown_preview.lua.
vim.g.mkdp_auto_close = 0
vim.g.mkdp_combine_preview = 1
require("utils.markdown_preview").setup()
