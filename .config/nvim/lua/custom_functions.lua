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

M.title_with_prefix = function()
	local title = M.get_title()
	if title ~= "" then
		-- Format the title with the prefix
		local title_prefix = "> Title: "
		local indent = "    "
		local formatted_title = indent .. title
		vim.api.nvim_put({ title_prefix }, "l", true, true)
		vim.api.nvim_put({ "" }, "l", true, true)
		vim.api.nvim_put({ formatted_title }, "l", true, true)
		vim.api.nvim_put({ "" }, "l", true, true)
	else
		vim.api.nvim_err_writeln(title) -- Error message if title is empty
	end
end

M.get_title = function()
	local wrd = M.citation_key()
	if wrd ~= "" then
		local repl = vim.fn.py3eval('ZotCite.GetRefData("' .. wrd .. '")')
		if not repl then
			return "Citation key not found"
		end
		if repl.title then
			return repl.title
		else
			return "No title found associated with article"
		end
	end
	return ""
end

M.abstract_with_prefix = function()
	local abstract = M.get_abstract()
	if abstract ~= "" then
		local abstract_prefix = "> Abstract: "
		local indent = "    "
		local formatted_abstract = indent .. abstract
		vim.api.nvim_put({ abstract_prefix }, "l", true, true)
		vim.api.nvim_put({ "" }, "l", true, true) -- Add an empty line to separate the title
		vim.api.nvim_put({ formatted_abstract }, "l", true, true)
		vim.api.nvim_put({ "" }, "l", true, true)
	else
		vim.api.nvim_err_writeln(abstract)
	end
end

M.get_abstract = function()
	local wrd = M.citation_key()
	if wrd ~= "" then
		local repl = vim.fn.py3eval('ZotCite.GetRefData("' .. wrd .. '")')
		if not repl then
			return "Citation key not found"
		end
		if repl.abstractNote then
			return repl.abstractNote
		else
			return "No abstract found associated with article"
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
		-- Remove the "references:" header and any leading spaces
		repl = repl:gsub("^references:[\n\r]*", "")
		-- Remove leading spaces from each line
		repl = repl:gsub("^[ \t]+", "")
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
local getmach = function(key)
	local citeptrn = key:gsub(" .*", "")
	local refs = vim.fn.py3eval(
		'ZotCite.GetMatch("' .. citeptrn .. '", "' .. vim.fn.escape(vim.fn.expand("%:p"), "\\") .. '", True)'
	)
	local resp = {}
	for _, v in pairs(refs) do
		local item = {
			key = v.zotkey,
			author = v.alastnm,
			year = v.year,
			ttl = v.title,
		}
		table.insert(resp, item)
	end
	if #resp == 0 then
		vim.schedule(function()
			vim.api.nvim_echo({ { "No matches found." } }, false, {})
		end)
	end
	return resp
end

local tbl_indexof = function(tbl, value)
	for i, v in ipairs(tbl) do
		if v == value then
			return i
		end
	end
	return nil
end
local sel_list = {} -- Ensure sel_list is a global variable or accessible in the required scope

-- Function to get matching citations
local FindCitationKey = function(str, cb)
	local mtchs = getmach(str)
	if #mtchs == 0 then
		return
	end
	local opts = {}
	sel_list = {} -- Clear previous selection list
	for _, v in pairs(mtchs) do
		table.insert(opts, v.author .. " (" .. v.year .. ") " .. v.ttl)
		table.insert(sel_list, v.key)
	end
	vim.schedule(function()
		vim.ui.select(opts, { prompt = "Select a citation:" }, function(choice)
			if choice then
				-- Find the index of the selected choice using the custom tbl_indexof function
				local selected_index = tbl_indexof(opts, choice)
				if selected_index then
					M.citation_key = function()
						return sel_list[selected_index]
					end
					M.yaml_ref()
					M.title_with_prefix()
					M.abstract_with_prefix()
				end
			end
		end)
	end)
end
-- Create the FindCitation user command
vim.api.nvim_create_user_command("FindCitation", function()
	-- Prompt the user for input
	vim.ui.input({ prompt = "Enter citation query: " }, function(input)
		if input then
			FindCitationKey(input, function()
				-- No additional processing needed here, as selection is handled within FindCitationKey
			end)
		end
	end)
end, { nargs = 0 })

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

vim.api.nvim_create_user_command("LtexLangChangeLanguage", function(data)
	local language = data.fargs[1]
	local bufnr = vim.api.nvim_get_current_buf()
	local client = vim.lsp.get_clients({ bufnr = bufnr, name = "ltex" })
	-- local client = vim.lsp.get_active_clients({ bufnr = bufnr, name = "ltex" })
	if #client == 0 then
		vim.notify("No ltex client attached")
	else
		client = client[1]
		client.config.settings = {
			ltex = {
				language = language,
			},
		}
		client.notify("workspace/didChangeConfiguration", client.config.settings)
		vim.notify("Language changed to " .. language)
	end
end, {
	nargs = 1,
	force = true,
})

return M
