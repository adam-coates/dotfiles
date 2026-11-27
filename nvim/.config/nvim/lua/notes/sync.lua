-- Git for the vault: commit, pull and push with one key, and optionally on a timer
-- (settings.sync). Like Obsidian Git. Nothing is committed or pushed unless you ask
-- for it or turn the timer on.

local settings = require("settings")
local util = require("notes.util")
local vault = require("notes.vault")

local M = { state = { repo = nil, changes = 0, ahead = 0, behind = 0, busy = false } }

-- No password prompts, and give up quickly when offline.
local ENV = { GIT_TERMINAL_PROMPT = "0", GIT_SSH_COMMAND = "ssh -oBatchMode=yes -oConnectTimeout=8" }

local function git(args, callback)
	local cmd = vim.list_extend({ "git", "-C", vault.root() }, args)
	vim.system(cmd, { text = true, env = ENV, timeout = 60000 }, vim.schedule_wrap(callback))
end

--- Save the notes that have unsaved changes (only notes: code stays as it is).
local function save_notes()
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].modified and vim.bo[buf].buftype == "" and vault.is_note(vim.api.nvim_buf_get_name(buf)) then
			vim.api.nvim_buf_call(buf, function()
				vim.cmd("silent! lockmarks update")
			end)
		end
	end
end

--- Refresh the numbers in the statusline.
function M.status(callback)
	git({ "status", "--porcelain=v2", "--branch" }, function(res)
		local s = M.state
		s.repo = res.code == 0
		s.changes, s.ahead, s.behind, s.upstream = 0, 0, 0, false
		for line in (res.stdout or ""):gmatch("[^\n]+") do
			local ahead, behind = line:match("^# branch%.ab %+(%d+) %-(%d+)")
			if ahead then
				s.ahead, s.behind, s.upstream = tonumber(ahead), tonumber(behind), true
			elseif line:sub(1, 1) ~= "#" then
				s.changes = s.changes + 1
			end
		end
		vim.cmd.redrawstatus()
		if callback then
			callback(s)
		end
	end)
end

function M.init()
	git({ "init", "-b", "main" }, function(res)
		if res.code ~= 0 then
			return util.notify(res.stderr, "error")
		end
		local ignore = vault.abs(".gitignore")
		if not vim.uv.fs_stat(ignore) then
			util.write(ignore, ".obsidian/workspace*\n.trash/\n.DS_Store\n")
		end
		util.notify("Vault is a git repository now")
		M.status()
	end)
end

-- Run steps one after the other; stop at the first that fails.
local function chain(steps, finish)
	local i = 0
	local function step()
		i = i + 1
		if not steps[i] then
			return finish(true)
		end
		steps[i](function(ok, message)
			if ok then
				step()
			else
				finish(false, message)
			end
		end)
	end
	step()
end

local function failed(res)
	return vim.trim(res.stderr ~= "" and res.stderr or res.stdout or "git failed")
end

--- Commit everything. `done` gets whether it worked.
function M.commit(message, done)
	save_notes()
	git({ "add", "-A" }, function(add)
		if add.code ~= 0 then
			return done(false, failed(add))
		end
		git({ "diff", "--cached", "--quiet" }, function(diff)
			if diff.code == 0 then
				return done(true, "nothing to commit")
			end
			git({ "commit", "-q", "-m", message or os.date(settings.sync.message) }, function(res)
				done(res.code == 0, failed(res))
			end)
		end)
	end)
end

--- Commit, pull, push.
function M.sync(opts)
	opts = opts or {}
	if M.state.busy then
		return
	end
	M.status(function(s)
		if not s.repo then
			if not opts.quiet then
				vim.ui.select({ "Yes", "No" }, { prompt = "The vault isn't a git repository. Make it one?" }, function(answer)
					if answer == "Yes" then
						M.init()
					end
				end)
			end
			return
		end
		M.state.busy = true
		local changes = s.changes
		local steps = {
			function(ok)
				M.commit(nil, ok)
			end,
		}
		if s.upstream and settings.sync.pull then
			steps[#steps + 1] = function(ok)
				git({ "pull", "--rebase", "--autostash", "-q" }, function(res)
					if res.code ~= 0 then
						-- Leave the vault as it was rather than in the middle of a rebase.
						git({ "rebase", "--abort" }, function()
							ok(false, "Pull failed, nothing was changed:\n" .. failed(res))
						end)
					else
						ok(true)
					end
				end)
			end
		end
		if s.upstream and settings.sync.push then
			steps[#steps + 1] = function(ok)
				git({ "push", "-q" }, function(res)
					ok(res.code == 0, failed(res))
				end)
			end
		end
		chain(steps, function(ok, message)
			M.state.busy = false
			vim.cmd("silent! checktime")
			require("notes.index").refresh()
			vim.api.nvim_exec_autocmds("User", { pattern = "NotesChanged", data = {} })
			M.status()
			if not ok then
				util.notify(message or "Sync failed", "error")
			elseif not opts.quiet then
				util.notify(("Synced: %d change%s committed%s"):format(changes, changes == 1 and "" or "s", s.upstream and ", pushed" or " (no remote)"))
			end
		end)
	end)
end

--- Text for the statusline.
function M.line()
	local s = M.state
	if s.busy then
		return "󰑐"
	elseif not s.repo then
		return ""
	end
	local out = {}
	if s.changes > 0 then
		out[#out + 1] = "󰏫 " .. s.changes
	end
	if s.ahead > 0 then
		out[#out + 1] = "↑" .. s.ahead
	end
	if s.behind > 0 then
		out[#out + 1] = "↓" .. s.behind
	end
	return #out > 0 and table.concat(out, " ") or "󰄬"
end

--- Commit and push right now, waiting for it: for quitting, when there is no
--- later. A push that's refused (the phone pushed first) is left for the next sync.
function M.sync_now()
	if M.state.busy then
		return
	end
	local function run(args, timeout)
		return vim.system(vim.list_extend({ "git", "-C", vault.root() }, args), { text = true, env = ENV, timeout = timeout or 5000 }):wait()
	end
	if run({ "rev-parse", "--is-inside-work-tree" }).code ~= 0 then
		return
	end
	save_notes()
	run({ "add", "-A" })
	if run({ "diff", "--cached", "--quiet" }).code ~= 0 then
		run({ "commit", "-q", "-m", os.date(settings.sync.message) })
	end
	if settings.sync.push and run({ "rev-parse", "--abbrev-ref", "@{u}" }).code == 0 then
		local ahead = vim.trim(run({ "rev-list", "--count", "@{u}..HEAD" }).stdout or "0")
		if tonumber(ahead) and tonumber(ahead) > 0 then
			vim.api.nvim_echo({ { "Pushing notes…" } }, false, {})
			run({ "push", "-q" }, 15000)
		end
	end
end

function M.setup()
	local group = vim.api.nvim_create_augroup("notes_sync", { clear = true })
	local check = util.debounce(1500, function()
		M.status()
	end)
	vim.api.nvim_create_autocmd({ "BufWritePost", "FocusGained" }, { group = group, callback = check })
	vim.api.nvim_create_autocmd("User", { group = group, pattern = { "NotesChanged", "ObsidianWorkspaceSet" }, callback = check })
	vim.defer_fn(function()
		M.status()
	end, 600)
	if settings.sync.on_start then
		vim.defer_fn(function()
			M.sync({ quiet = true })
		end, 2000)
	end
	if settings.sync.on_quit then
		vim.api.nvim_create_autocmd("VimLeavePre", { group = group, callback = M.sync_now })
	end
	local minutes = settings.sync.auto_minutes
	if minutes and minutes > 0 then
		local timer = assert(vim.uv.new_timer())
		timer:start(minutes * 60000, minutes * 60000, vim.schedule_wrap(function()
			M.sync({ quiet = true })
		end))
	end
end

return M
