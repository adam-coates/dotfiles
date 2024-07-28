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

local obsidian = require("obsidian")

_G.preview_obsidian_link = function()
	local client = obsidian.get_client()
	if not client then
		vim.api.nvim_err_writeln("Obsidian client not initialized")
		return
	end

	client:resolve_link_async(nil, function(...)
		local results = { ... }
		vim.schedule(function()
			if #results == 0 then
				vim.api.nvim_err_writeln("No link found under cursor")
				return
			end

			local result = results[1] -- Take the first result

			if result.path then
				local path_str = tostring(result.path)
				local previewers = require("telescope.previewers")
				local pickers = require("telescope.pickers")
				local finders = require("telescope.finders")
				local conf = require("telescope.config").values

				pickers
					.new({}, {
						prompt_title = "Preview: " .. vim.fn.fnamemodify(path_str, ":t"),
						finder = finders.new_table({
							results = { path_str },
							entry_maker = function(entry)
								return {
									value = entry,
									display = vim.fn.fnamemodify(entry, ":t"),
									ordinal = entry,
								}
							end,
						}),
						previewer = previewers.new_buffer_previewer({
							title = "File Preview",
							define_preview = function(self, entry)
								local lines = vim.fn.readfile(entry.value)
								vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
								vim.api.nvim_buf_set_option(self.state.bufnr, "filetype", "markdown")
								if result.line then
									vim.api.nvim_win_set_cursor(self.state.winid, { result.line, 0 })
								end
							end,
						}),
						sorter = conf.generic_sorter({}),
						attach_mappings = function(prompt_bufnr)
							require("telescope.actions").select_default:replace(function()
								require("telescope.actions").close(prompt_bufnr)
								vim.cmd("edit " .. path_str)
								if result.line then
									vim.api.nvim_win_set_cursor(0, { result.line, 0 })
								end
							end)
							return true
						end,
					})
					:find()
			elseif result.url then
				vim.api.nvim_out_write("URL link: " .. result.url .. "\n")
				if client.opts.follow_url_func then
					client.opts.follow_url_func(result.url)
				end
			else
				vim.api.nvim_err_writeln("Could not resolve link")
			end
		end)
	end)
end

vim.api.nvim_set_keymap("n", "<leader>op", "<cmd>lua preview_obsidian_link()<CR>", { noremap = true, silent = true })

return M
