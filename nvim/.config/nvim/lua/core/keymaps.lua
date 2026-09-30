vim.g.mapleader = " "
vim.g.maplocalleader = ","

local keymap = vim.keymap -- for conciseness

keymap.set("n", "<leader>s", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]], { desc = "Replace current word" })

-- window management
keymap.set("n", "<leader>sv", "<C-w>v", { desc = "Split window vertically" })
keymap.set("n", "<leader>sh", "<C-w>s", { desc = "Split window horizontally" })
keymap.set("n", "<leader>se", "<C-w>=", { desc = "Make splits equal size" })
keymap.set("n", "<leader>sx", "<cmd>close<CR>", { desc = "Close current split" })

-- scroll in middle
keymap.set("n", "<C-d>", "<C-d>zz")
keymap.set("n", "<C-u>", "<C-u>zz")

keymap.set("x", "p", '"_dP')

-- move selected lines up or down
keymap.set("v", "J", ":m '>+1<CR>gv=gv")
keymap.set("v", "K", ":m '<-2<CR>gv=gv")

-- Better movement
vim.keymap.set("n", "j", "gj", { noremap = true, silent = true })
vim.keymap.set("n", "k", "gk", { noremap = true, silent = true })
vim.keymap.set("v", "j", "gj", { noremap = true, silent = true })
vim.keymap.set("v", "k", "gk", { noremap = true, silent = true })

-- Joplin note creation via Data API (Web Clipper)
keymap.set("n", "<leader>on", function()
	local title = vim.fn.input("Note title: ")
	if title == "" then
		print(" Title cannot be empty!")
		return
	end
	local location = vim.fn.input("Location: ")
	local tags = vim.fn.input("Tags (comma separated): ")

	-- Open a scratch buffer for the note body.
	-- Don't set ft=markdown here — that triggers obsidian.nvim's lazy load.
	-- Instead, set syntax highlighting directly; the buffer never touches disk.
	vim.cmd("enew")
	vim.api.nvim_buf_set_name(0, "joplin://" .. title)
	vim.bo.buftype = "acwrite"
	vim.cmd("setlocal syntax=markdown")

	-- Fill in the Joplin template
	local date = os.date("%Y-%m-%d")
	vim.api.nvim_buf_set_lines(0, 0, -1, false, {
		"---",
		"title: " .. title,
		"tags: [" .. tags .. "]",
		"location: " .. location,
		"date: " .. date,
		"---",
		"",
		"# " .. title,
		"",
		"",
	})
	vim.api.nvim_win_set_cursor(0, { 10, 0 })
	vim.cmd("startinsert")

	-- Save sends to Joplin instead of disk
	vim.api.nvim_buf_create_user_command(0, "W", function()
		local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
		local body = table.concat(lines, "\n")

		-- Read API token from Joplin settings
		local settings_path = vim.fn.expand("~/.config/joplin-desktop/settings.json")
		local settings = vim.fn.json_decode(vim.fn.readfile(settings_path))
		local token = settings["api.token"]

		-- Split comma-separated tags for the Joplin API
		local tag_list = {}
		for tag in tags:gmatch("([^,]+)") do
			tag = tag:match("^%s*(.-)%s*$") -- trim
			if tag ~= "" then
				tag_list[#tag_list + 1] = tag
			end
		end

		local payload = vim.fn.json_encode({
			title = title,
			body = body,
			parent_id = "e29d0819f7d14dbd8fa34fbe22525bc8", -- 00 - Inbox
		})

		local result = vim.fn.system({
			"curl", "-s", "-X", "POST",
			"http://localhost:41184/notes?token=" .. token,
			"-H", "Content-Type: application/json",
			"-d", payload,
		})

		local ok, response = pcall(vim.fn.json_decode, result)
		if ok and response.id then
			-- Apply tags via the Joplin API
			for _, tag_name in ipairs(tag_list) do
				-- Find or create the tag
				local search = vim.fn.system({
					"curl", "-s",
					"http://localhost:41184/search?query=" .. vim.uri_encode(tag_name) .. "&type=tag&token=" .. token,
				})
				local sok, sres = pcall(vim.fn.json_decode, search)
				local tag_id
				if sok and sres.items and #sres.items > 0 then
					tag_id = sres.items[1].id
				else
					-- Create the tag
					local create = vim.fn.system({
						"curl", "-s", "-X", "POST",
						"http://localhost:41184/tags?token=" .. token,
						"-H", "Content-Type: application/json",
						"-d", vim.fn.json_encode({ title = tag_name }),
					})
					local cok, cres = pcall(vim.fn.json_decode, create)
					if cok and cres.id then
						tag_id = cres.id
					end
				end
				-- Assign tag to note
				if tag_id then
					vim.fn.system({
						"curl", "-s", "-X", "POST",
						"http://localhost:41184/tags/" .. tag_id .. "/notes?token=" .. token,
						"-H", "Content-Type: application/json",
						"-d", vim.fn.json_encode({ id = response.id }),
					})
				end
			end

			vim.notify("Saved to Joplin: " .. title, vim.log.levels.INFO)
			vim.bo.modified = false
		else
			vim.notify("Joplin save failed: " .. result, vim.log.levels.ERROR)
		end
	end, {})

	-- Map :w to :W in this buffer so saving is natural
	vim.keymap.set("n", "<leader>w", "<cmd>W<cr>", { buffer = true, desc = "Save to Joplin" })
	vim.api.nvim_create_autocmd("BufWriteCmd", {
		buffer = 0,
		callback = function()
			vim.cmd("W")
		end,
	})
end, { desc = "Create Joplin note in Inbox" })
