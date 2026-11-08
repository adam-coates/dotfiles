require("mason").setup({
	ui = {
		icons = {
			package_installed = "✓",
			package_pending = "➜",
			package_uninstalled = "✗",
		},
	},
})

require("mason-tool-installer").setup({
	ensure_installed = {
		-- Language servers
		"lua-language-server",
		"zls",
		"typescript-language-server",
		"rust-analyzer",
		"bash-language-server",
		"pyright",
		"css-lsp",
		"html-lsp",
		"json-lsp",
		"yaml-language-server",
		"ltex-ls-plus",
		"tinymist",
		-- Linters
		"eslint_d",
		"luacheck",
		"shellcheck",
		"markdownlint",
		"yamllint",
		"jsonlint",
		"htmlhint",
		"stylelint",
		"phpstan",
		"ruff",
		"mypy",
		-- Formatters
		"stylua",
		"prettier",
		"black",
		"isort",
		"shfmt",
		-- Debuggers
		"debugpy",
	},
	auto_update = false,
	run_on_start = true,
})

require("lazydev").setup({})

-- Server configs ------------------------------------------------------------
local capabilities = {
	workspace = {
		fileOperations = {
			didRename = true,
			willRename = true,
		},
	},
}

vim.lsp.config("*", {
	capabilities = require("blink.cmp").get_lsp_capabilities(capabilities),
})

vim.lsp.config("lua_ls", {
	settings = {
		Lua = {
			diagnostics = {
				globals = { "vim" },
				disable = { "inject-field", "undefined-field", "missing-fields" },
			},
			runtime = { version = "LuaJIT" },
			workspace = {
				library = {
					[vim.fn.expand("$VIMRUNTIME/lua")] = true,
					[vim.fn.stdpath("config") .. "/lua"] = true,
				},
				checkThirdParty = false,
			},
			telemetry = { enable = false },
		},
	},
})

vim.lsp.config("ltex_plus", {
	settings = {
		ltex = {
			language = "en-US",
			disabledRules = {
				["en-US"] = {
					"MORFOLOGIK_RULE_EN_US",
					"EN_QUOTES",
					"WHITESPACE_RULE",
					"UPPERCASE_SENTENCE_START",
					"CONSECUTIVE_SPACES",
				},
			},
			markdown = {
				nodes = { Link = "dummy" },
			},
		},
	},
})

vim.lsp.enable({
	"lua_ls",
	"zls",
	"ts_ls",
	"rust_analyzer",
	"bashls",
	"pyright",
	"cssls",
	"html",
	"jsonls",
	"yamlls",
	"ltex_plus",
	"tinymist",
})

-- Keymaps ---------------------------------------------------------------------
-- Snacks' LSP pickers fail on otter's answers in quarto and markdown code chunks
-- ("callback yielded after done"), so use Neovim's own functions there.
local function goto(picker, native)
	return function()
		for _, client in ipairs(vim.lsp.get_clients({ bufnr = 0 })) do
			if client.name:match("^otter%-ls") then
				return native()
			end
		end
		Snacks.picker[picker]()
	end
end

local function setup_keymaps(bufnr)
	local function map(mode, lhs, rhs, desc, opts)
		opts = vim.tbl_extend("force", { buffer = bufnr, desc = desc, silent = true }, opts or {})
		vim.keymap.set(mode, lhs, rhs, opts)
	end

	-- Hover & signature
	map("n", "K", vim.lsp.buf.hover, "Hover")
	-- Insert mode only: in normal mode <C-k> moves to the window or pane above.
	map("i", "<C-k>", vim.lsp.buf.signature_help, "Signature Help")

	-- Go to, through the Snacks picker. nowait: Neovim's default gr* maps would
	-- otherwise make gr pause for timeoutlen.
	map("n", "gd", goto("lsp_definitions", vim.lsp.buf.definition), "Go to Definition")
	map("n", "gD", goto("lsp_declarations", vim.lsp.buf.declaration), "Go to Declaration")
	map("n", "gr", goto("lsp_references", vim.lsp.buf.references), "References", { nowait = true })
	map("n", "gi", goto("lsp_implementations", vim.lsp.buf.implementation), "Go to Implementation")
	map("n", "gy", goto("lsp_type_definitions", vim.lsp.buf.type_definition), "Go to Type Definition")

	-- Diagnostics navigation
	map("n", "[d", function()
		vim.diagnostic.jump({ count = -1 })
	end, "Prev Diagnostic")
	map("n", "]d", function()
		vim.diagnostic.jump({ count = 1 })
	end, "Next Diagnostic")

	-- <leader>c = Code
	map({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, "Code Action")
	map("n", "<leader>cr", vim.lsp.buf.rename, "Rename Symbol")
	map("n", "<leader>cd", vim.diagnostic.open_float, "Line Diagnostic")
	map("n", "<leader>cv", "<cmd>vsplit | lua vim.lsp.buf.definition()<cr>", "Definition in Vsplit")

	-- <leader>l = LSP
	map("n", "<leader>li", "<cmd>checkhealth vim.lsp<cr>", "LSP Info")
	map("n", "<leader>lr", "<cmd>lsp restart<cr>", "LSP Restart")
	map("n", "<leader>lh", function()
		vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr }), { bufnr = bufnr })
	end, "Toggle Inlay Hints")
end

-- Document highlight on cursor hold comes from Snacks words (plugins/ui.lua).
vim.api.nvim_create_autocmd("LspAttach", {
	group = vim.api.nvim_create_augroup("UserLspConfig", { clear = true }),
	callback = function(args)
		setup_keymaps(args.buf)
	end,
})

-- Diagnostics -----------------------------------------------------------------
vim.diagnostic.config({
	virtual_text = true,
	underline = true,
	update_in_insert = false,
	severity_sort = true,
	float = { border = "rounded", source = true, header = "", prefix = "" },
	signs = {
		text = {
			[vim.diagnostic.severity.ERROR] = "󰅚 ",
			[vim.diagnostic.severity.WARN] = "󰀪 ",
			[vim.diagnostic.severity.INFO] = "󰋽 ",
			[vim.diagnostic.severity.HINT] = "󰌶 ",
		},
		numhl = {
			[vim.diagnostic.severity.ERROR] = "ErrorMsg",
			[vim.diagnostic.severity.WARN] = "WarningMsg",
		},
	},
})
