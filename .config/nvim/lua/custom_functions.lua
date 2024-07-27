local M = {}

M.citation_key = function()
	local lnum = vim.api.nvim_win_get_cursor(0)[1]
	local line = vim.api.nvim_buf_get_lines(0, lnum - 1, lnum, true)[1]
	local pos = vim.api.nvim_win_get_cursor(0)[2]
	local found_i = false
	local i = pos + 1
	local k
	while i > 0 do
		k = line:sub(i, i)
		if k:find("@") then
			found_i = true
			i = i + 1
			break
		end
		if not k:find("[A-Za-z0-9_#%-]") then
			break
		end
		i = i - 1
	end
	if found_i then
		local j = i + 8
		k = line:sub(j, j)
		if k == "#" then
			local key = line:sub(i, j - 1)
			return key
		end
	end
	return ""
end
M.title = function()
	local wrd = M.citation_key()
	if wrd ~= "" then
		local repl = vim.fn.py3eval('ZotCite.GetRefData("' .. wrd .. '")')
		if not repl then
			vim.api.nvim_err_writeln("Citation key not found")
			return
		end
		if repl.title then
			vim.api.nvim_put({ repl.title }, "l", true, true)
		else
			vim.api.nvim_err_writeln("No title found associated with article")
		end
	end
end

M.yaml_ref = function()
	local wrd = M.citation_key()
	if wrd ~= "" then
		-- Fetch the YAML-formatted reference data using ZotCite
		local repl = vim.fn.py3eval('ZotCite.GetYamlRefs(["' .. wrd .. '"])')
		repl = repl:gsub("^references:[\n\r]*", "")

		-- Check if the reference data is empty
		if repl == "" then
			vim.api.nvim_err_writeln("Citation key not found")
		else
			-- Split the YAML data by lines and paste it into the buffer
			local lines = vim.split(repl, "\n")
			-- Add YAML tags
			table.insert(lines, 1, "---")
			table.insert(lines, "---")
			-- Paste the YAML data into the buffer
			vim.api.nvim_put(lines, "l", true, true)
		end
	end
end

return M
