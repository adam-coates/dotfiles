return {
	"vimwiki/vimwiki",
	event = "VeryLazy",
	init = function()
		local sysname = vim.loop.os_uname().sysname
		if sysname == "Linux" then
			vim.g.notepath = "/mnt/g/notes/"
		elseif sysname == "Darwin" then
			vim.g.notepath = "~/notes/"
		else
			vim.g.notepath = "Windows specific value"
		end
		vim.g.vimwiki_list = { { path = vim.g.notepath, syntax = "markdown", ext = ".md", listsyms = " ○◐●✓" } }
		--    vim.g.vimwiki_folding = "list"
		vim.treesitter.language.register("markdown", "vimwiki")
		vim.g.vimwiki_global_ext = 0
	end,
}
