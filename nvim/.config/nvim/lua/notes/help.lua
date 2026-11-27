-- <leader>? : the keys, as a note you can search and scroll.
local M = {}

function M.open()
	local util = require("notes.util")
	local path = vim.fn.stdpath("config") .. "/doc/keys.md"
	local lines = util.lines(util.read(path) or "doc/keys.md is missing")
	local buf, win = util.float(lines, { width = math.min(100, vim.o.columns - 6), height = vim.o.lines - 6, title = "Keys", footer = "/ search · q close" })
	vim.bo[buf].filetype = "markdown"
	vim.wo[win].conceallevel, vim.wo[win].spell, vim.wo[win].wrap = 2, false, true
end

return M
