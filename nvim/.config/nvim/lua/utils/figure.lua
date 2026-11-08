-- Turn the current line into an Inkscape figure: the line's text names the
-- figure, a copy of the template opens in Inkscape, and the line becomes a link.
-- Figures go in images/ next to the current file, where img-clip puts pastes too.

local M = {}

M.template = vim.fn.expand("~/dotfiles/templates/figure.svg")

-- How each filetype links to a figure. Others get the bare path.
local function link(ft, title, path)
	if ft == "markdown" or ft == "quarto" then
		return ("![%s](%s)"):format(title, path)
	elseif ft == "typst" then
		return ('#figure(image("%s"), caption: [%s])'):format(path, title)
	end
	return path
end

function M.create()
	local title = vim.trim(vim.api.nvim_get_current_line())
	if title == "" then
		vim.notify("Type the figure name on the current line first", vim.log.levels.WARN)
		return
	end
	if vim.fn.filereadable(M.template) == 0 then
		vim.notify("Figure template not found: " .. M.template, vim.log.levels.ERROR)
		return
	end

	-- "My first plot!" -> my-first-plot.svg
	local name = title:lower():gsub("[^%w%s_-]", ""):gsub("%s+", "-") .. ".svg"
	local base = vim.api.nvim_buf_get_name(0) ~= "" and vim.fn.expand("%:p:h") or vim.fn.getcwd()
	local dir = base .. "/images"
	local file = dir .. "/" .. name

	vim.fn.mkdir(dir, "p")
	if vim.fn.filereadable(file) == 0 then
		vim.uv.fs_copyfile(M.template, file)
	end
	vim.system({ "inkscape", file }, { detach = true })

	local row = vim.api.nvim_win_get_cursor(0)[1]
	local text = link(vim.bo.filetype, title, "images/" .. name)
	vim.api.nvim_buf_set_lines(0, row - 1, row, false, { text })
	vim.api.nvim_win_set_cursor(0, { row, #text })
end

return M
