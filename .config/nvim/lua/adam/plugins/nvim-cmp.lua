return {
	"hrsh7th/nvim-cmp",
	event = "InsertEnter",
	dependencies = {
		"hrsh7th/cmp-buffer", -- source for text in buffer
		"hrsh7th/cmp-path", -- source for file system paths
		"L3MON4D3/LuaSnip", -- snippet engine
		"saadparwaiz1/cmp_luasnip", -- for autocompletion
		"rafamadriz/friendly-snippets", -- useful snippets
		"onsails/lspkind.nvim", -- vs-code like pictograms
		"jalvesaq/cmp-zotcite",
	},
	config = function()
		local cmp = require("cmp")

		local luasnip = require("luasnip")

		local lspkind = require("lspkind")
		_G.LuaSnipConfig = {}
		-- Helpers
		function _G.LuaSnipConfig.visual_selection(_, parent)
			return parent.snippet.env.LS_SELECT_DEDENT or {}
		end

		function _G.LuaSnipConfig.intext_cite(_, parent)
			local selected_text = parent.snippet.env.LS_SELECT_DEDENT or {}
			local extracted_names = {}

			for _, text in ipairs(selected_text) do
				-- Extract the portion of the text after #
				local substring = text:match("#(.+)")
				if substring then
					-- Replace "Etal" or "Et al." with "et al."
					substring = substring:gsub("_Etal_", " et al.,")
					substring = substring:gsub("_Et al%.", " et al.,")
					-- Remove any numbers after "et al."
					substring = substring:gsub(" et al%..*", " et al.,")
					-- Truncate at the last occurrence of a number
					local truncated = substring:gsub("_%d+$", "")
					-- Split by underscores and add to extracted_names
					local names = {}
					for name in truncated:gmatch("([^_]+)") do
						table.insert(names, name .. " ") -- Add a space at the end of each name
					end
					-- Check if "etal" is present
					local has_etal = string.find(truncated, "etal")
					-- Concatenate names without "and" if "etal" is present
					if has_etal then
						table.insert(extracted_names, table.concat(names))
					else
						-- Concatenate names with "and" if there are more than one
						if #names > 1 then
							table.insert(extracted_names, table.concat(names, "and "))
						else
							table.insert(extracted_names, names[1])
						end
					end
				end
			end

			return extracted_names
		end

		local check_back_space = function()
			local col = vim.fn.col(".") - 1
			if col == 0 or vim.fn.getline("."):sub(col, col):match("%s") then
				return true
			else
				return false
			end
		end
		require("luasnip.loaders.from_vscode").lazy_load({})
		require("luasnip.loaders.from_vscode").lazy_load({ paths = "./my_snippets" })
		require("luasnip.loaders.from_lua").lazy_load({ paths = "./lua_snippets" })
		require("luasnip").config.setup({ store_selection_keys = "<C-s>" })
		vim.api.nvim_set_keymap(
			"i",
			"<C-u>",
			'<cmd>lua require("luasnip.extras.select_choice")()<CR>',
			{ noremap = true }
		)
		luasnip.filetype_extend("quarto", { "markdown" })

		cmp.setup({
			completion = {
				completeopt = "menu,menuone,preview,noselect",
			},
			snippet = { -- configure how nvim-cmp interacts with snippet engine
				expand = function(args)
					luasnip.lsp_expand(args.body)
				end,
			},
			mapping = cmp.mapping.preset.insert({
				["<C-k>"] = cmp.mapping.select_prev_item(), -- previous suggestion
				["<C-j>"] = cmp.mapping.select_next_item(), -- next suggestion
				["<C-b>"] = cmp.mapping.scroll_docs(-4),
				["<C-f>"] = cmp.mapping.scroll_docs(4),
				["<C-Space>"] = cmp.mapping.complete(), -- show completion suggestions
				["<C-e>"] = cmp.mapping.abort(), -- close completion window
				["<CR>"] = cmp.mapping.confirm({ select = false }),
				["<Tab>"] = cmp.mapping(function(fallback)
					if cmp.visible() then
						cmp.confirm({ select = true })
					elseif luasnip.jumpable(1) then
						luasnip.jump(1)
					elseif check_back_space() then
						fallback()
					else
						cmp.complete()
					end
				end, { "i", "s" }),
				["<S-Tab>"] = cmp.mapping(function()
					luasnip.jump(-1)
				end, { "i", "s" }),
			}),
			vim.keymap.set({ "i", "s" }, "<C-s>", function()
				if luasnip.expandable() then
					luasnip.expand({})
				end
			end),
			-- sources for autocompletion
			sources = cmp.config.sources({
				{ name = "luasnip" }, -- snippets
				{ name = "nvim_lsp" },
				{ name = "buffer" }, -- text within current buffer
				{ name = "path" }, -- file system paths
				{ name = "cmp_zotcite" },
				{ name = "otter" },
			}),
			-- configure lspkind for vs-code like pictograms in completion menu
			formatting = {
				format = lspkind.cmp_format({
					maxwidth = 50,
					ellipsis_char = "...",
				}),
			},
		})
	end,
}
