return {
	"neovim/nvim-lspconfig",
	--event = { "BufReadPre", "BufNewFile" },
	dependencies = {
		"hrsh7th/cmp-nvim-lsp",
		{ "antosha417/nvim-lsp-file-operations", config = true },
	},
	config = function()
		-- import lspconfig plugin
		local lspconfig = require("lspconfig")

		-- import cmp-nvim-lsp plugin
		local cmp_nvim_lsp = require("cmp_nvim_lsp")

		local keymap = vim.keymap -- for conciseness
		vim.api.nvim_create_autocmd("LspAttach", {
			group = vim.api.nvim_create_augroup("UserLspConfig", {}),
			callback = function(ev)
				-- Buffer local mappings.
				-- See `:help vim.lsp.*` for documentation on any of the below functions
				local opts = { buffer = ev.buf, silent = true }

				-- set keybinds
				opts.desc = "Show LSP references"
				keymap.set("n", "gR", "<cmd>Telescope lsp_references<CR>", opts) -- show definition, references

				opts.desc = "Go to declaration"
				keymap.set("n", "gD", vim.lsp.buf.declaration, opts) -- go to declaration

				opts.desc = "Show LSP definitions"
				keymap.set("n", "gd", "<cmd>Telescope lsp_definitions<CR>", opts) -- show lsp definitions

				opts.desc = "Show LSP implementations"
				keymap.set("n", "gi", "<cmd>Telescope lsp_implementations<CR>", opts) -- show lsp implementations

				opts.desc = "Show LSP type definitions"
				keymap.set("n", "gt", "<cmd>Telescope lsp_type_definitions<CR>", opts) -- show lsp type definitions

				opts.desc = "See available code actions"
				keymap.set({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, opts) -- see available code actions, in visual mode will apply to selection

				opts.desc = "Smart rename"
				keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts) -- smart rename

				opts.desc = "Show buffer diagnostics"
				keymap.set("n", "<leader>D", "<cmd>Telescope diagnostics bufnr=0<CR>", opts) -- show  diagnostics for file

				opts.desc = "Show line diagnostics"
				keymap.set("n", "<leader>d", vim.diagnostic.open_float, opts) -- show diagnostics for line

				opts.desc = "Go to previous diagnostic"
				keymap.set("n", "[d", function()
					vim.diagnostic.jump({ count = -1, float = true })
				end, opts) -- jump to previous diagnostic in buffer

				opts.desc = "Go to next diagnostic"
				keymap.set("n", "]d", function()
					vim.diagnostic.jump({ count = 1, float = true })
				end, opts) -- jump to next diagnostic in buffer

				opts.desc = "Show documentation for what is under cursor"
				keymap.set("n", "K", vim.lsp.buf.hover, opts) -- show documentation for what is under cursor

				opts.desc = "Restart LSP"
				keymap.set("n", "<leader>rs", ":LspRestart<CR>", opts) -- mapping to restart lsp if necessary
			end,
		})

		-- used to enable autocompletion (assign to every lsp server config)
		local capabilities = cmp_nvim_lsp.default_capabilities()
		-- Change the Diagnostic symbols in the sign column (gutter)
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
		-- configure html server
		lspconfig["html"].setup({
			capabilities = capabilities,
			--      on_attach = on_attach,
		})

		-- configure css server
		lspconfig["cssls"].setup({
			capabilities = capabilities,
			--      on_attach = on_attach,
		})

		-- configure tailwindcss server
		lspconfig["tailwindcss"].setup({
			capabilities = capabilities,
			--      on_attach = on_attach,
		})

		-- configure python server
		lspconfig["pyright"].setup({
			capabilities = capabilities,
			--      on_attach = on_attach,
		})
		-- configure matlab server
		lspconfig["matlab_ls"].setup({
			capabilities = capabilities,
			--        on_attach = on_attach,
		})
		-- configure bash server
		lspconfig["bashls"].setup({
			capabilities = capabilities,
			--        on_attach = on_attach,
		})
		lspconfig["marksman"].setup({
			capabilities = capabilities,
			--            on_attach = on_attach,
			filetypes = { "markdown", "quarto" },
		})
		lspconfig["clangd"].setup({
			capabilities = capabilities,
		})
		lspconfig["r_language_server"].setup({
			capabilities = capabilities,
			--        on_attach = on_attach,
			settings = {
				r = {
					lsp = {
						rich_documentation = false,
					},
				},
			},
		})
		lspconfig["ltex"].setup({
			capabilities = capabilities,
			settings = {
				ltex = {
					language = "en-US",
					languageModel = "~/models/ngrams/",
					disabledRules = {
						["en-US"] = {
							"MORFOLOGIK_RULE_EN_US",
						},
					},
				},
			},
		})
		lspconfig["vale_ls"].setup({
			capabilities = capabilities,
			init_options = {
				configPath = "/home/adam/.config/vale/.vale.ini",
			},
			cmd_env = { VALE_CONFIG_PATH = "/home/adam/.config/vale/.vale.ini" },
			filetypes = { "markdown", "text", "tex", "rst", "quarto", "qmd" },
		})
		lspconfig["lua_ls"].setup({
			capabilities = capabilities,
			--      on_attach = on_attach,
			settings = { -- custom settings for lua
				Lua = {
					-- make the language server recognize "vim" global
					diagnostics = {
						globals = { "vim" },
					},
					workspace = {
						-- make language server aware of runtime files
						library = {
							[vim.fn.expand("$VIMRUNTIME/lua")] = true,
							[vim.fn.stdpath("config") .. "/lua"] = true,
						},
					},
				},
			},
		})
	end,
}
