return {
	"saghen/blink.cmp",
	dependencies = {
		"mikavilpas/blink-ripgrep.nvim",
		{
			"L3MON4D3/LuaSnip",
			version = "v2.*",
			build = "make install_jsregexp",
			dependencies = {
				"rafamadriz/friendly-snippets",
				config = function()
					require("luasnip.loaders.from_vscode").lazy_load()
					require("luasnip.loaders.from_vscode").lazy_load({
						paths = { vim.fn.stdpath("config") .. "/snippets" },
					})
					require("luasnip.loaders.from_lua").lazy_load({
						paths = { vim.fn.stdpath("config") .. "/snippets" },
					})

					local extends = {
						lua = { "luadoc" },
						python = { "pydoc" },
						sh = { "shelldoc" },
						quarto = { "markdown" },
					}
					-- friendly-snippets - enable standardized comments snippets
					for ft, snips in pairs(extends) do
						require("luasnip").filetype_extend(ft, snips)
					end
				end,
			},
			opts = { history = true, delete_check_events = "TextChanged", enable_autosnippets = true },
		}, -- snippet engine
		"onsails/lspkind.nvim", -- vs-code like pictograms
		{
			"jmbuhr/cmp-pandoc-references",
			ft = { "quarto", "markdown", "rmarkdown" },
		},
	},
	version = "1.*",
	opts = {
		--
		keymap = { preset = "default" },
		appearance = {
			nerd_font_variant = "mono",
		},
		-- (Default) Only show the documentation popup when manually triggered
		completion = {
			accept = {
				auto_brackets = { enabled = true },
			},
			documentation = {
				auto_show = true,
			},
			menu = {
				max_height = 50,
				draw = {
					components = {
						kind_icon = {
							text = function(ctx)
								local icon = ctx.kind_icon
								if vim.tbl_contains({ "Path" }, ctx.source_name) then
									local dev_icon, _ = require("nvim-web-devicons").get_icon(ctx.label) -- Fixed this line
									if dev_icon then
										icon = dev_icon
									end
								else
									icon = require("lspkind").symbolic(ctx.kind, {
										mode = "symbol",
									})
								end
								return icon .. ctx.icon_gap
							end,
							highlight = function(ctx)
								local hl = ctx.kind_hl
								if vim.tbl_contains({ "Path" }, ctx.source_name) then
									local dev_icon, dev_hl = require("nvim-web-devicons").get_icon(ctx.label)
									if dev_icon then
										hl = dev_hl
									end
								end
								return hl
							end,
						},
					},
				},
			},
		},
		snippets = { preset = "luasnip" },
		-- Default list of enabled providers defined so that you can extend it
		-- elsewhere in your config, without redefining it, due to `opts_extend`
		sources = {
			default = { "lsp", "path", "snippets", "buffer", "ripgrep", "references" },
			providers = {
				lsp = {
					name = "LSP",
					module = "blink.cmp.sources.lsp",
					score_offset = 150, -- the higher the number, the higher the priority
					-- Filter text items from the LSP provider, since we have the buffer provider for that
					transform_items = function(_, items)
						for _, item in ipairs(items) do
							if item.kind == require("blink.cmp.types").CompletionItemKind.Snippet then
								item.score_offset = item.score_offset - 3
							end
						end

						return vim.tbl_filter(function(item)
							return item.kind ~= require("blink.cmp.types").CompletionItemKind.Text
						end, items)
					end,
				},
				path = {
					name = "Path",
					module = "blink.cmp.sources.path",
					score_offset = 25,
					opts = {
						trailing_slash = false,
						label_trailing_slash = true,
					},
				},
				buffer = {
					name = "Buffer",
					module = "blink.cmp.sources.buffer",
					min_keyword_length = 3,
					score_offset = 15, -- the higher the number, the higher the priority
				},
				snippets = {
					name = "Snippets",
					module = "blink.cmp.sources.snippets",
					min_keyword_length = 2,
					score_offset = 60,
				},
				ripgrep = {
					module = "blink-ripgrep",
					name = "Ripgrep",
					---@module "blink-ripgrep"
					---@type blink-ripgrep.Options
					opts = {
						prefix_min_len = 4,
						score_offset = 10, -- should be lower priority
						max_filesize = "300K",
						search_casing = "--smart-case",
					},
				},
				references = {
					name = "pandoc_references",
					module = "cmp-pandoc-references.blink",
				},
			},
		},
		-- (Default) Rust fuzzy matcher for typo resistance and significantly better performance
		-- You may use a lua implementation instead by using `implementation = "lua"` or fallback to the lua implementation,
		-- when the Rust fuzzy matcher is not available, by using `implementation = "prefer_rust"`
		--
		-- See the fuzzy documentation for more information
		signature = { enabled = true },
		fuzzy = { implementation = "prefer_rust_with_warning" },
	},
	opts_extend = { "sources.default" },
}
