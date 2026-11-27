-- Parsers for markdown and for the code people paste into notes.
local TS = require("nvim-treesitter")

-- Your previous config's list plus the notes ones. Others install themselves the
-- first time a file needs them (treesitter-autoinstall).
local parsers = {
	"astro", "bash", "c", "cmake", "cpp", "css", "diff", "dockerfile", "fish", "gitignore",
	"go", "graphql", "html", "http", "java", "javascript", "jsdoc", "json", "julia", "latex",
	"lua", "luadoc", "luap", "make", "markdown", "markdown_inline", "matlab", "mermaid", "nix",
	"php", "printf", "python", "query", "r", "regex", "rust", "scss", "sql", "svelte", "toml",
	"tsx", "typescript", "typst", "vim", "vimdoc", "xml", "yaml",
}

-- Checking what is installed takes a moment, so not while starting.
vim.defer_fn(function()
	if vim.fn.executable("tree-sitter") == 1 then
		TS.install(parsers)
	end
end, 800)

-- Neovim's markdown query hides the fences of code blocks, and with them anything
-- drawn on those lines (language labels, query results). render-markdown switches
-- that off too, but only after the first note has been drawn.
local function keep_fences()
	local ok, query = pcall(vim.treesitter.query.get, "markdown", "highlights")
	if not ok or not query then
		return
	end
	for id, directives in pairs(query.info.patterns) do
		for _, directive in ipairs(directives) do
			if directive[1] == "set!" and vim.tbl_contains(directive, "conceal_lines") then
				query.query:disable_pattern(id)
				break
			end
		end
	end
end
keep_fences()

-- Quarto and MDX notes are markdown as far as highlighting goes.
vim.filetype.add({ extension = { mdx = "mdx" } })
vim.treesitter.language.register("markdown", { "quarto", "mdx", "rmd" })
-- Query blocks get a highlighter that roughly fits.
vim.treesitter.language.register("sql", { "dataview" })

require("treesitter-autoinstall").setup()

-- Highlighting for every language with a parser, and treesitter indenting for
-- code (notes keep Vim's own, which markdown-plus builds on).
local PROSE = { markdown = true, quarto = true, text = true, gitcommit = true }
vim.api.nvim_create_autocmd("FileType", {
	group = vim.api.nvim_create_augroup("notes_treesitter", { clear = true }),
	callback = function(ev)
		local lang = vim.treesitter.language.get_lang(ev.match)
		if lang and pcall(vim.treesitter.language.add, lang) and vim.treesitter.language.add(lang) then
			pcall(vim.treesitter.start, ev.buf, lang)
			if not PROSE[ev.match] then
				vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
			end
		end
	end,
})
