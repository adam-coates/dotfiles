-- Language servers, linters, formatters and debuggers: your previous config's set,
-- plus Harper (grammar) and Tectonic (LaTeX maths drawn as images) for notes.
-- Mason installs them into this config's own data folder.

local settings = require("settings")

require("mason").setup({
	ui = {
		border = "rounded",
		icons = { package_installed = "✓", package_pending = "➜", package_uninstalled = "✗" },
	},
})

local tools = {
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
	"harper-ls",
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
}
if settings.images ~= false then
	tools[#tools + 1] = "tectonic" -- LaTeX maths as images
end

require("mason-tool-installer").setup({
	ensure_installed = tools,
	auto_update = false,
	run_on_start = true,
	start_delay = 1500, -- after the first screen is drawn
})

require("lazydev").setup({})

-- Server configs ------------------------------------------------------------------
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

-- Grammar, twice over (you chose both): LTeX+ as in your previous config, and Harper.
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

vim.lsp.config("harper_ls", {
	cmd = { "harper-ls", "--stdio" },
	filetypes = { "markdown", "quarto", "gitcommit", "typst" },
	root_markers = { ".obsidian", ".git" },
	settings = {
		["harper-ls"] = {
			dialect = settings.grammar_dialect,
			userDictPath = vim.fn.stdpath("config") .. "/spell/harper.txt",
			linters = {
				SpellCheck = false, -- Vim's own spell checker does that
				SentenceCapitalization = false,
				UseTitleCase = false,
				LongSentences = false,
				Dashes = false,
				ToDoHyphen = false,
				ExpandTimeShorthands = false,
				ExpandMinimum = false,
			},
			markdown = { IgnoreLinkTitle = true },
			isolateEnglish = true, -- leave notes in other languages alone
			diagnosticSeverity = "hint",
		},
	},
})

local servers = {
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
	"tinymist",
}
if settings.grammar then
	vim.list_extend(servers, { "ltex_plus", "harper_ls" })
end
vim.lsp.enable(servers)

-- Servers mason installs after the first start attach to the open buffers then.
vim.api.nvim_create_autocmd("User", {
	pattern = "MasonToolsUpdateCompleted",
	group = vim.api.nvim_create_augroup("config_mason_done", { clear = true }),
	callback = vim.schedule_wrap(function(ev)
		if type(ev.data) == "table" and #ev.data > 0 then
			vim.lsp.enable(servers)
		end
	end),
})

-- Keys ----------------------------------------------------------------------------
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

-- Buffers where K previews links and <leader>l means links (config/keymaps.lua).
local function markdown(buf)
	local ft = vim.bo[buf].filetype
	return ft == "markdown" or ft == "quarto"
end

local function setup_keymaps(bufnr)
	local function map(mode, lhs, rhs, desc, opts)
		opts = vim.tbl_extend("force", { buffer = bufnr, desc = desc, silent = true }, opts or {})
		vim.keymap.set(mode, lhs, rhs, opts)
	end

	-- Hover & signature. In notes K previews the link, and falls back to this in code blocks.
	if not markdown(bufnr) then
		map("n", "K", vim.lsp.buf.hover, "Hover")
	end
	-- Insert mode only: in normal mode <C-k> moves to the window or pane above.
	map("i", "<C-k>", vim.lsp.buf.signature_help, "Signature Help")

	-- Go to, through the Snacks picker. nowait: Neovim's default gr* maps would
	-- otherwise make gr pause for timeoutlen. In notes gd follows the link and gr
	-- lists the backlinks (obsidian.nvim's language server).
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

	-- <leader>l = LSP in code; in notes <leader>l is links, and <leader>lr removes one.
	map("n", "<leader>li", "<cmd>checkhealth vim.lsp<cr>", "LSP Info")
	if not markdown(bufnr) then
		map("n", "<leader>lr", "<cmd>lsp restart<cr>", "LSP Restart")
	end
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

-- Diagnostics -----------------------------------------------------------------------
-- In prose, grammar hints are only underlined (gl or K reads them); warnings and
-- errors, like those from code blocks, show as in code.
local PROSE = { markdown = true, quarto = true, text = true, gitcommit = true }
local function prose(bufnr)
	return PROSE[vim.bo[bufnr].filetype] == true
end
local serious = { min = vim.diagnostic.severity.WARN }
local signs = {
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
}

vim.diagnostic.config({
	virtual_text = function(_, bufnr)
		return prose(bufnr) and { severity = serious } or true
	end,
	signs = function(_, bufnr)
		return prose(bufnr) and vim.tbl_extend("force", signs, { severity = serious }) or signs
	end,
	underline = true,
	update_in_insert = false,
	severity_sort = true,
	float = { border = "rounded", source = true, header = "", prefix = "" },
})
