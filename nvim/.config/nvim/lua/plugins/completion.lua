-- Completion and snippets. Your previous config's LuaSnip and blink setup, with the
-- note sources added: [[ for notes, [[## for headings anywhere, [[^^ for blocks,
-- # for tags, [^ for footnotes (all from obsidian.nvim's language server), @ for
-- dates and citation keys, : for emoji.

local luasnip = require("luasnip")

luasnip.config.setup({ store_selection_keys = "<C-s>" })
require("luasnip.loaders.from_vscode").lazy_load() -- friendly-snippets
require("luasnip.loaders.from_vscode").lazy_load({ paths = { vim.fn.stdpath("config") .. "/snippets" } }) -- notes
luasnip.filetype_extend("quarto", { "markdown" })

-- Selection-aware versions of friendly-snippets' Quarto/Markdown snippets.
require("plugins.snippets")

vim.keymap.set("i", "<C-u>", function()
	require("luasnip.extras.select_choice")()
end, { desc = "Select snippet choice" })

-- Ctrl-S expands a snippet; in insert mode with nothing to expand it saves.
vim.keymap.set({ "i", "s" }, "<C-s>", function()
	if luasnip.expandable() then
		luasnip.expand({})
	elseif vim.fn.mode() == "i" then
		vim.cmd("silent update")
	end
end, { desc = "Expand snippet (or save)" })

-- Tab accepts, then jumps through snippets. With neither to do it indents after
-- whitespace, and otherwise opens the menu. On a list item in a note it's left to
-- markdown-plus, which indents the item.
local function tab_fallback(cmp)
	local line = vim.fn.getline(".")
	local ft = vim.bo.filetype
	if (ft == "markdown" or ft == "quarto") and (line:match("^%s*[-*+]%s") or line:match("^%s*%d+[.)]%s")) then
		return false
	end
	local col = vim.fn.col(".") - 1
	if col == 0 or line:sub(col, col):match("%s") then
		return false
	end
	return cmp.show()
end

-- Files and folders from the path source get their real icon, the rest their LSP kind.
local function menu_icon(ctx)
	if ctx.source_id == "path" then
		local category = ctx.kind == "Folder" and "directory" or "file"
		return MiniIcons.get(category, (ctx.label:gsub("/$", "")))
	end
	return MiniIcons.get("lsp", ctx.kind)
end

local function prose()
	local ft = vim.bo.filetype
	return ft == "markdown" or ft == "quarto" or ft == "gitcommit"
end

local note_sources = { "lsp", "dates", "snippets", "path", "emoji", "buffer" }

require("blink.cmp").setup({
	keymap = {
		preset = "none",
		["<C-n>"] = { "select_next", "fallback" },
		["<C-p>"] = { "select_prev", "fallback" },
		["<Down>"] = { "select_next", "fallback" },
		["<Up>"] = { "select_prev", "fallback" },
		["<C-b>"] = { "scroll_documentation_up", "fallback" },
		-- fallback_to_mappings: Ctrl-f also makes an Inkscape figure (config/keymaps.lua).
		["<C-f>"] = { "scroll_documentation_down", "fallback_to_mappings" },
		["<C-Space>"] = { "show", "fallback" },
		["<C-e>"] = { "cancel", "fallback" },
		["<CR>"] = { "accept", "fallback" },
		["<Tab>"] = { "select_and_accept", "snippet_forward", tab_fallback, "fallback" },
		["<S-Tab>"] = { "snippet_backward", "fallback" },
	},
	appearance = { nerd_font_variant = "mono" },
	snippets = { preset = "luasnip" },
	-- Show a function's parameters and docs while typing its arguments.
	signature = { enabled = true },
	completion = {
		list = {
			selection = {
				preselect = false,
				auto_insert = function()
					return not prose() -- notes: [[links]] shouldn't be typed out while browsing
				end,
			},
		},
		documentation = { auto_show = true, auto_show_delay_ms = 250, window = { max_width = 70 } },
		ghost_text = { enabled = false },
		menu = {
			draw = {
				columns = { { "kind_icon" }, { "label", "label_description", gap = 1 }, { "source_name" } },
				components = {
					kind_icon = {
						text = function(ctx)
							return (menu_icon(ctx)) .. ctx.icon_gap
						end,
						highlight = function(ctx)
							local _, hl = menu_icon(ctx)
							return { { group = hl, priority = 20000 } }
						end,
					},
					label = { width = { fill = true, max = 50 } },
					source_name = {
						text = function(ctx)
							return "[" .. ctx.source_name .. "]"
						end,
						highlight = "NotesMuted",
					},
				},
			},
		},
	},
	sources = {
		-- Zotcite provides citation keys through its own language server, so the lsp
		-- source covers them too.
		default = { "lsp", "snippets", "buffer", "path" },
		per_filetype = {
			markdown = note_sources,
			quarto = note_sources,
			gitcommit = { "lsp", "snippets", "path", "emoji", "buffer" },
			lua = { "lazydev", "lsp", "snippets", "buffer", "path" },
		},
		providers = {
			lazydev = {
				name = "LazyDev",
				module = "lazydev.integrations.blink",
				score_offset = 100,
			},
			lsp = {
				name = "lsp",
				fallbacks = {},
				-- "Create this note" comes after the notes that exist.
				transform_items = function(_, items)
					for _, item in ipairs(items) do
						if item.label and item.label:find("(create)", 1, true) then
							item.score_offset = (item.score_offset or 0) - 100
						end
					end
					return items
				end,
			},
			snippets = {
				name = "snip",
				-- Not right after a trigger that belongs to another source.
				should_show_items = function(ctx)
					local before = ctx.line:sub(1, ctx.cursor[2])
					return not before:match("%[%[[^%]]*$") and not before:match("[@#:][%w_/-]*$")
				end,
			},
			dates = { name = "date", module = "notes.blink_dates", score_offset = 20 },
			emoji = {
				name = "emoji",
				module = "blink-emoji",
				score_offset = 10,
				opts = { insert = true },
			},
			-- In notes, words from the page only when nothing better fits.
			buffer = {
				name = "word",
				min_keyword_length = function()
					return prose() and 4 or 0
				end,
				max_items = function()
					return prose() and 4 or 200
				end,
				score_offset = -20,
			},
			path = { name = "path", opts = { show_hidden_files_by_default = false } },
		},
	},
	cmdline = {
		keymap = { preset = "cmdline" },
		completion = { menu = { auto_show = false } },
	},
})
