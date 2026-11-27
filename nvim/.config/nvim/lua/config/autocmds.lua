local settings = require("settings")
local vault = require("notes.vault")

local function group(name)
	return vim.api.nvim_create_augroup("config_" .. name, { clear = true })
end
local autocmd = vim.api.nvim_create_autocmd

-- Save notes when you pause, as Obsidian does.
if settings.autosave then
	local timers = {}
	local function savable(buf)
		return vim.api.nvim_buf_is_valid(buf)
			and vim.bo[buf].modified
			and vim.bo[buf].buftype == ""
			and not vim.bo[buf].readonly
			and vim.bo[buf].modifiable
			and vault.is_note(vim.api.nvim_buf_get_name(buf))
	end
	local function save(buf)
		if savable(buf) then
			vim.api.nvim_buf_call(buf, function()
				vim.cmd("silent! lockmarks update")
			end)
		end
	end
	autocmd({ "InsertLeave", "TextChanged" }, {
		group = group("autosave"),
		pattern = "*.md",
		callback = function(ev)
			local buf = ev.buf
			timers[buf] = timers[buf] or assert(vim.uv.new_timer())
			timers[buf]:start(1200, 0, vim.schedule_wrap(function()
				-- Not in the middle of a command, a completion or a snippet.
				if vim.api.nvim_get_mode().mode:match("^n") and not vim.snippet.active() then
					save(buf)
				end
			end))
		end,
	})
	autocmd({ "FocusLost", "BufLeave", "VimLeavePre" }, {
		group = group("autosave_now"),
		pattern = "*",
		callback = function(ev)
			if ev.event == "BufLeave" then
				save(ev.buf)
			else
				for _, buf in ipairs(vim.api.nvim_list_bufs()) do
					if vim.api.nvim_buf_is_loaded(buf) then
						save(buf)
					end
				end
			end
		end,
	})
end

-- Prose settings.
autocmd("FileType", {
	group = group("prose"),
	pattern = { "markdown", "quarto", "text", "gitcommit" },
	callback = function(ev)
		if vim.bo[ev.buf].buftype ~= "" then
			return
		end
		vim.opt_local.spell = settings.spell
		vim.opt_local.spelllang = settings.spelllang
		vim.opt_local.number = settings.numbers
		vim.opt_local.relativenumber = settings.numbers
		vim.opt_local.wrap = true
		vim.opt_local.linebreak = true
		vim.opt_local.conceallevel = 2
		vim.opt_local.concealcursor = ""
		vim.opt_local.smartindent = false
		vim.opt_local.textwidth = 0
		-- What wrapped lines hang under: quotes, list markers, checkboxes.
		vim.opt_local.formatlistpat = [[^\s*\%(>\s*\)*\%(\d\+[.)]\s\+\|[-*+]\s\+\)\?\%(\[.\]\s\+\)\?]]
		vim.opt_local.foldmethod = "expr"
		vim.opt_local.foldexpr = "v:lua.vim.treesitter.foldexpr()"
		vim.opt_local.foldtext = ""
		vim.opt_local.foldlevel = 99
		vim.opt_local.iskeyword:append("-")
		vim.opt_local.suffixesadd:append(".md")
		vim.keymap.set("n", "K", function()
			require("notes.hover").hover()
		end, { buffer = ev.buf, desc = "Preview the link" })
	end,
})

-- A note can choose its own spelling language: `spelllang: de` in its properties.
autocmd("User", {
	group = group("note_language"),
	pattern = "ObsidianNoteEnter",
	callback = function(ev)
		local entry = require("notes.index").buffer(ev.buf)
		local lang = entry and (entry.fm.spelllang or entry.fm.lang)
		if type(lang) == "string" and lang:match("^[%a_,]+$") then
			for _, win in ipairs(vim.fn.win_findbuf(ev.buf)) do
				vim.wo[win].spell = true
			end
			vim.bo[ev.buf].spelllang = lang
		end
	end,
})

-- Come back to where you were.
autocmd("BufReadPost", {
	group = group("last_position"),
	callback = function(ev)
		local mark = vim.api.nvim_buf_get_mark(ev.buf, '"')
		if mark[1] > 1 and mark[1] <= vim.api.nvim_buf_line_count(ev.buf) and vim.bo[ev.buf].filetype ~= "gitcommit" then
			pcall(vim.api.nvim_win_set_cursor, 0, mark)
		end
	end,
})

-- Files changed by a sync or another app.
autocmd({ "FocusGained", "TermClose", "BufEnter" }, {
	group = group("checktime"),
	callback = function()
		if vim.bo.buftype == "" then
			vim.cmd("silent! checktime")
		end
	end,
})

autocmd("BufWritePre", {
	group = group("mkdir"),
	callback = function(ev)
		if not ev.match:match("^%w+://") then
			vim.fn.mkdir(vim.fs.dirname(vim.uv.fs_realpath(ev.match) or ev.match), "p")
		end
	end,
})

autocmd("TextYankPost", {
	group = group("yank"),
	callback = function()
		vim.hl.on_yank({ timeout = 150 })
	end,
})

autocmd("FileType", {
	group = group("quick_close"),
	pattern = { "help", "qf", "checkhealth", "man", "notify", "grug-far-help", "gitsigns-blame" },
	callback = function(ev)
		vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = ev.buf, nowait = true })
	end,
})

autocmd("VimResized", {
	group = group("resize"),
	command = "tabdo wincmd =",
})

