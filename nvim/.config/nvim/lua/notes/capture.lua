-- Quick capture: a small window over whatever you are doing.
--
--   <C-s>  add to today's note       <C-t>  make each line a task
--   <C-n>  new note (first line is the title)
--
-- From anywhere (a Hyprland key, say):
--   ghostty -e nvim +Capture

local settings = require("settings")
local util = require("notes.util")
local vault = require("notes.vault")
local D = require("notes.date")
local T = require("notes.tasks")

local M = {}

M.log_heading = "Log"

--- Add text to today's note, with the time. Lines that are tasks go under Tasks.
function M.to_daily(lines)
	local path = require("notes.periodic").ensure("daily", D.today())
	local tasks, text = {}, {}
	for _, line in ipairs(lines) do
		if line:match("^%s*[-*+]%s+%[.%]") then
			tasks[#tasks + 1] = vim.trim(line)
		else
			text[#text + 1] = line
		end
	end
	while text[1] and text[1]:match("^%s*$") do
		table.remove(text, 1)
	end
	while text[#text] and text[#text]:match("^%s*$") do
		table.remove(text)
	end
	if #tasks > 0 then
		T.add_to_note(path, settings.task_heading, tasks)
	end
	if #text > 0 then
		local out = { "- " .. os.date("%H:%M") .. " " .. text[1]:gsub("^%s*[-*+]%s+", "") }
		for i = 2, #text do
			out[#out + 1] = text[i] == "" and "" or ("  " .. text[i])
		end
		T.add_to_note(path, M.log_heading, out)
	end
	return path
end

function M.to_note(lines)
	local title = (lines[1] or ""):gsub("^#+%s*", "")
	if vim.trim(title) == "" then
		title = os.date("%Y-%m-%d %H%M%S")
	end
	local path = vault.folder("inbox") .. "/" .. util.filename(title) .. ".md"
	local n = 2
	while vim.uv.fs_stat(path) do
		path = vault.folder("inbox") .. "/" .. util.filename(title) .. " " .. n .. ".md"
		n = n + 1
	end
	local text = require("notes.template").render("note", { title = vim.fs.basename(path):gsub("%.md$", "") })
	local body = vim.trim(table.concat(vim.list_slice(lines, 2), "\n"))
	util.write(path, (text:gsub("%s+$", "")) .. "\n\n" .. body .. "\n")
	require("notes.index").update(path)
	return path
end

function M.open(opts)
	opts = opts or {}
	local standalone = opts.standalone
	local buf, win = util.float({ "" }, {
		width = math.min(80, vim.o.columns - 6),
		height = 10,
		title = "󰄄 Capture",
		footer = "<C-s> today · <C-t> tasks · <C-n> new note · <Esc><Esc> cancel",
		modifiable = true,
	})
	vim.bo[buf].filetype = "markdown"
	vim.wo[win].wrap, vim.wo[win].linebreak = true, true
	for _, lhs in ipairs({ "q", "<Esc>" }) do
		pcall(vim.keymap.del, "n", lhs, { buffer = buf })
	end
	if opts.text then
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, opts.text)
	end

	local function finish(fn)
		return function()
			local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
			vim.cmd.stopinsert()
			vim.api.nvim_win_close(win, true)
			if vim.trim(table.concat(lines)) ~= "" and fn then
				local path = fn(lines)
				if path then
					util.notify("Saved to " .. vim.fs.basename(path):gsub("%.md$", ""))
				end
			end
			if standalone then
				vim.defer_fn(function()
					vim.cmd("qall")
				end, 50)
			end
		end
	end
	local function map(modes, lhs, fn)
		vim.keymap.set(modes, lhs, fn, { buffer = buf, nowait = true })
	end
	map({ "n", "i" }, "<C-s>", finish(M.to_daily))
	map({ "n", "i" }, "<C-n>", finish(M.to_note))
	map({ "n", "i" }, "<C-t>", finish(function(lines)
		local tasks = {}
		for _, line in ipairs(lines) do
			if line:match("%S") then
				tasks[#tasks + 1] = T.from_text(line)
			end
		end
		local path = T.capture_path()
		T.add_to_note(path, settings.task_heading, tasks)
		return path
	end))
	map("n", "<Esc>", finish(nil))
	map("n", "q", finish(nil))
	map("n", "ZZ", finish(M.to_daily))
	vim.cmd("startinsert!")
end

return M
