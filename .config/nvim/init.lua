require("config.keymaps")
require("config.options")
require("config.autocmds")
require("core.lazy")
require("core.lsp")
package.path = package.path .. ";" .. vim.fn.expand("$HOME") .. "/.luarocks/share/lua/5.1/?/init.lua"
package.path = package.path .. ";" .. vim.fn.expand("$HOME") .. "/.luarocks/share/lua/5.1/?.lua"


vim.g.python3_host_prog = "/home/adam/.pyenv/versions/py3/bin/python3"

local function create_obsidian_figure()
  -- Get the current line (figure name)
  local line = vim.api.nvim_get_current_line():match("^%s*(.-)%s*$") -- trim whitespace
  
  if line == "" then
    vim.notify("Type figure name on current line first", vim.log.levels.WARN)
    return
  end
  
  -- Run the script and get the markdown syntax
  local result = vim.fn.system('obsidian-inkscape "' .. line .. '"')
  
  -- Check if command succeeded
  if vim.v.shell_error ~= 0 then
    vim.notify("Error creating figure: " .. result, vim.log.levels.ERROR)
    return
  end
  
  -- Clean the result (remove any trailing whitespace/newlines)
  local markdown_link = result:gsub("%s+$", "")
  
  -- Replace current line with markdown syntax
  local row = vim.api.nvim_win_get_cursor(0)[1]
  vim.api.nvim_buf_set_lines(0, row - 1, row, false, {markdown_link})
  
  vim.notify("Figure created: " .. line, vim.log.levels.INFO)
end

-- Set up keybind for markdown files
vim.api.nvim_create_autocmd("FileType", {
  pattern = "markdown",
  callback = function()
    vim.keymap.set({'i', 'n'}, '<C-f>', create_obsidian_figure, 
      { buffer = true, desc = "Create Obsidian figure" })
  end
})-- own statusline

-- Define highlight groups (use :hi to inspect them live)
-- vim.cmd([[
--   hi StatusLineGitBranch guifg=#61afef guibg=NONE gui=bold
--   hi StatusLineFilename    guifg=#ffffff guibg=NONE
--   hi StatusLineDiagnostics guifg=#e5c07b guibg=NONE
--   hi StatusLineWordcount   guifg=#98c379 guibg=NONE
--   hi StatusLineScrollbar   guifg=#c678dd guibg=NONE
-- ]])
--
-- -- Git branch
-- function _G.git_branch()
-- 	local handle = io.popen("git rev-parse --abbrev-ref HEAD 2>/dev/null")
-- 	if handle then
-- 		local result = handle:read("*l")
-- 		handle:close()
-- 		if result and result ~= "HEAD" then
-- 			return "%#StatusLineGitBranch# " .. result
-- 		end
-- 	end
-- 	return ""
-- end
--
-- -- Diagnostics (LSP)
-- function _G.diagnostics()
-- 	local e = #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.ERROR })
-- 	local w = #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.WARN })
-- 	local i = #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.INFO })
-- 	local h = #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.HINT })
--
-- 	local parts = {}
-- 	if e > 0 then table.insert(parts, " " .. e) end
-- 	if w > 0 then table.insert(parts, " " .. w) end
-- 	if i > 0 then table.insert(parts, " " .. i) end
-- 	if h > 0 then table.insert(parts, "󰠠 " .. h) end
--
-- 	return "%#StatusLineDiagnostics#" .. table.concat(parts, " ")
-- end
--
-- -- Word count & reading time for text formats
-- function _G.wordcount()
-- 	local ft = vim.bo.filetype
-- 	if ft == "markdown" or ft == "asciidoc" or ft == "quarto" then
-- 		local wc = vim.fn.wordcount()
-- 		local words = wc.visual_words or wc.words
-- 		return string.format(" %d words •  %d min", words, math.ceil(words / 200))
-- 	end
-- 	return ""
-- end
--
-- -- Scrollbar position
-- function _G.scrollbar()
-- 	local sbar_chars = { "▔", "🮂", "🬂", "🮃", "▀", "▄", "▃", "🬭", "▂", "▁" }
-- 	local line = vim.fn.line(".")
-- 	local total = vim.fn.line("$")
-- 	local idx = math.floor((line - 1) / total * #sbar_chars) + 1
-- 	return "%#StatusLineScrollbar#" .. string.rep(sbar_chars[idx], 2)
-- end
--
-- -- Mode symbol
-- function _G.mode_icon()
-- 	local m = vim.fn.mode()
-- 	local map = {
-- 		n = "", i = "", v = "󰈈", V = "󰈈", [""] = "󰈈",
-- 		c = "", R = "", s = "󰆐", S = "󰆐", [""] = "󰆐",
-- 	}
-- 	return (map[m] or "") .. " "
-- end
--
-- -- Filename
-- function _G.filename()
-- 	local name = vim.fn.expand("%:t")
-- 	if name == "" then name = "[No Name]" end
-- 	if vim.bo.modified then name = name .. " ●" end
-- 	return "%#StatusLineFilename#" .. name
-- end
--
-- -- Final statusline assembly
-- function _G.statusline()
-- 	return table.concat({
-- 		" ",
-- 		mode_icon(),
-- 		git_branch(),
-- 		" ",
-- 		filename(),
-- 		"%=",
-- 		diagnostics(),
-- 		"  ",
-- 		wordcount(),
-- 		"  ",
-- 		scrollbar(),
-- 		" ",
-- 	})
-- end
--
-- -- Apply and update dynamically
-- vim.o.statusline = "%!v:lua.statusline()"
--
-- vim.api.nvim_create_autocmd({ "BufEnter", "CursorHold", "InsertLeave", "TextChanged", "DiagnosticChanged" }, {
-- 	callback = function()
-- 		vim.o.statusline = "%!v:lua.statusline()"
-- 	end,
-- })
