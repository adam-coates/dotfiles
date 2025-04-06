return {
	{
		"neovim/nvim-lspconfig",
		dependencies = {
			{
				-- `lazydev` configures Lua LSP for your Neovim config, runtime and plugins
				-- used for completion, annotations and signatures of Neovim apis
				"folke/lazydev.nvim",
				ft = "lua",
				opts = {
					library = {
						-- Load luvit types when the `vim.uv` word is found
						{ path = "luvit-meta/library", words = { "vim%.uv" } },
						{ path = "/usr/share/awesome/lib/", words = { "awesome" } },
					},
				},
			},
			"saghen/blink.cmp",
			{ "antosha417/nvim-lsp-file-operations", config = true },
			"williamboman/mason.nvim",
			"williamboman/mason-lspconfig.nvim",
			"WhoIsSethDaniel/mason-tool-installer.nvim",
			-- Uncomment if you want to use schemastore for YAML
			-- "b0o/schemastore.nvim",
		},
		config = function ()
			local capabilities = require("blink.cmp").get_lsp_capabilities()
			local lspconfig = require("lspconfig")

			local servers = {
				bashls = true,
				lua_ls = {
					server_capabilities = {
						semanticTokensProvider = vim.NIL,
					},
				},
				pyright = true,

				yamlls = {
					settings = {
						yaml = {
							schemaStore = {
								enable = false,
								url = "",
							},
							-- Uncomment to use schemastore
							-- schemas = require("schemastore").yaml.schemas(),
						},
					},
				},
			}
			vim.diagnostic.config({
				signs = {
					text = {
						[vim.diagnostic.severity.ERROR] = " ",
						[vim.diagnostic.severity.WARN] = " ",
						[vim.diagnostic.severity.HINT] = "󰠠 ",
						[vim.diagnostic.severity.INFO] = " ",
					},
					texthl = {},
					numhl = {},
				},
				underline = true,
				update_in_insert = false, -- false so diags are updated on InsertLeave
				virtual_text = { current_line = true, severity = { min = "HINT", max = "WARN" } },
				virtual_lines = { current_line = true, severity = { min = "ERROR" } },
				severity_sort = true,
				float = {
					focusable = false,
					style = "minimal",
					border = "rounded",
					source = true,
					header = "",
				},
			})

			local servers_to_install = vim.tbl_filter(function(key)
				local t = servers[key]
				if type(t) == "table" then
					return not t.manual_install
				else
					return t
				end
			end, vim.tbl_keys(servers))

			require("mason").setup({
				ui = {
					icons = {
						package_installed = "✓",
						package_pending = "➜",
						package_uninstalled = "✗",
					},
				},
			})

			local ensure_installed = {
				"html",
				"cssls",
				"tailwindcss",
				"lua_ls",
				"pyright",
				"matlab_ls",
				"bashls",
				"marksman",
				"clangd",
				"prettier", -- prettier formatter
				"stylua", -- lua formatter
				"isort", -- python formatter
				"black", -- python formatter
				"clang-format",
			}

			vim.list_extend(ensure_installed, servers_to_install)

			require("mason-tool-installer").setup({
				ensure_installed = ensure_installed,
			})

			for name, config in pairs(servers) do
				if config == true then
					config = {}
				end
				config = vim.tbl_deep_extend("force", {}, {
					capabilities = capabilities,
				}, config)

				lspconfig[name].setup(config)
			end

			local disable_semantic_tokens = {
				lua = true,
			}

			vim.api.nvim_create_autocmd("LspAttach", {
				callback = function(args)
					local bufnr = args.buf
					local client = assert(vim.lsp.get_client_by_id(args.data.client_id), "must have valid client")

					local settings = servers[client.name]
					if type(settings) ~= "table" then
						settings = {}
					end

					local builtin = require("telescope.builtin")

					vim.opt_local.omnifunc = "v:lua.vim.lsp.omnifunc"

					vim.keymap.set("n", "gR", "<cmd>Telescope lsp_references<CR>", { desc = "Show LSP references" }) -- show definition, references

					vim.keymap.set("n", "gD", vim.lsp.buf.declaration, { desc = "Go to declaration" }) -- go to declaration

					vim.keymap.set("n", "gd", "<cmd>Telescope lsp_definitions<CR>", { desc = "Show LSP definitions" }) -- show lsp definitions

					vim.keymap.set(
						"n",
						"gi",
						"<cmd>Telescope lsp_implementations<CR>",
						{ desc = "Show LSP implementations" }
					) -- show lsp implementations

					vim.keymap.set(
						"n",
						"gt",
						"<cmd>Telescope lsp_type_definitions<CR>",
						{ desc = "Show LSP type definitions" }
					) -- show lsp type definitions

					vim.keymap.set(
						{ "n", "v" },
						"<leader>ca",
						vim.lsp.buf.code_action,
						{ desc = "See available code actions" }
					) -- see available code actions, in visual mode will apply to selection

					vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, { desc = "Smart rename" }) -- smart rename

					vim.keymap.set(
						"n",
						"<leader>D",
						"<cmd>Telescope diagnostics bufnr=0<CR>",
						{ desc = "Show buffer diagnostics" }
					) -- show diagnostics for file

					vim.keymap.set("n", "<leader>d", vim.diagnostic.open_float, { desc = "Show line diagnostics" }) -- show diagnostics for line

					vim.keymap.set("n", "[d", function()
						vim.diagnostic.jump({ count = -1, float = true })
					end, { desc = "Go to previous diagnostic" }) -- jump to previous diagnostic in buffer

					vim.keymap.set("n", "]d", function()
						vim.diagnostic.jump({ count = 1, float = true })
					end, { desc = "Go to next diagnostic" }) -- jump to next diagnostic in buffer

					vim.keymap.set(
						"n",
						"K",
						vim.lsp.buf.hover,
						{ desc = "Show documentation for what is under cursor" }
					) -- show documentation for what is under cursor

					vim.keymap.set("n", "<leader>rs", ":LspRestart<CR>", { desc = "Restart LSP" })

					vim.keymap.set("n", "<space>ca", vim.lsp.buf.code_action, { buffer = 0, desc = "Code action" })

					vim.keymap.set(
						"n",
						"<space>wd",
						builtin.lsp_document_symbols,
						{ buffer = 0, desc = "Document symbols" }
					)

					local filetype = vim.bo[bufnr].filetype
					if disable_semantic_tokens[filetype] then
						client.server_capabilities.semanticTokensProvider = nil
					end

					-- Override server capabilities
					if settings.server_capabilities then
						for k, v in pairs(settings.server_capabilities) do
							if v == vim.NIL then
								---@diagnostic disable-next-line: cast-local-type
								v = nil
							end

							client.server_capabilities[k] = v
						end
					end
				end,
			})
		end,
	},
}
