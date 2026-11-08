local luasnip = require("luasnip")

luasnip.config.setup({ store_selection_keys = "<C-s>" })
require("luasnip.loaders.from_vscode").lazy_load()
luasnip.filetype_extend("quarto", { "markdown" })

vim.keymap.set("i", "<C-u>", function()
	require("luasnip.extras.select_choice")()
end, { desc = "Select snippet choice" })

vim.keymap.set({ "i", "s" }, "<C-s>", function()
	if luasnip.expandable() then
		luasnip.expand({})
	end
end, { desc = "Expand snippet" })

-- Tab accepts, then jumps through snippets. With neither to do it indents after
-- whitespace, and otherwise opens the menu.
local function tab_fallback(cmp)
	local col = vim.fn.col(".") - 1
	if col == 0 or vim.fn.getline("."):sub(col, col):match("%s") then
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

require("blink.cmp").setup({
	keymap = {
		preset = "none",
		["<C-p>"] = { "select_prev", "fallback" },
		["<C-n>"] = { "select_next", "fallback" },
		["<C-b>"] = { "scroll_documentation_up", "fallback" },
		-- fallback_to_mappings: Ctrl-f also creates an Inkscape figure (core/keymaps.lua).
		["<C-f>"] = { "scroll_documentation_down", "fallback_to_mappings" },
		["<C-Space>"] = { "show", "fallback" },
		["<C-e>"] = { "cancel", "fallback" },
		["<CR>"] = { "accept", "fallback" },
		["<Tab>"] = { "select_and_accept", "snippet_forward", tab_fallback, "fallback" },
		["<S-Tab>"] = { "snippet_backward", "fallback" },
	},
	snippets = { preset = "luasnip" },
	-- Show a function's parameters and docs while typing its arguments.
	signature = { enabled = true },
	-- Zotcite provides citation keys through its own language server, so the lsp
	-- source covers them too.
	sources = {
		default = { "lazydev", "lsp", "snippets", "buffer", "path" },
		providers = {
			lazydev = {
				name = "LazyDev",
				module = "lazydev.integrations.blink",
				score_offset = 100,
			},
		},
	},
	completion = {
		list = { selection = { preselect = false } },
		documentation = { auto_show = true },
		menu = {
			draw = {
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
				},
			},
		},
	},
})
