-- Send code from Neovim to a REPL in a herdr or tmux pane, through vim-slime.
-- Each language gets its own REPL pane. In herdr, panes started here are labelled
-- "nvim-repl:<lang>", so a later Neovim in the same tab finds them again.

local M = {}

local REPL_CMDS = { python = "ipython", r = "R", bash = "bash" }
-- Python and R REPLs opened by hand are recognised by their process. Bash can't
-- be, since every idle shell pane would match.
local REPL_PROCESSES = { python = "ipython", r = "R" }
local FILETYPES = { "quarto", "markdown", "python", "r", "sh", "bash", "zsh" }

local panes = {}

-- "herdr", "tmux", or nil outside both. herdr wins when nested in tmux.
local function backend()
	if vim.env.HERDR_ENV == "1" then
		return "herdr"
	elseif vim.env.TMUX then
		return "tmux"
	end
end

-- The socket of the tmux server Neovim runs in ($TMUX is "socket,pid,session").
local function tmux_socket()
	return vim.split(vim.env.TMUX or "", ",")[1]
end

local function default_config()
	if backend() == "tmux" then
		return { socket_name = tmux_socket(), target_pane = "{right-of}" }
	end
	return { pane_id = "" }
end

local function tmux(args)
	local res = vim.system(vim.list_extend({ "tmux" }, args), { text = true }):wait()
	return res.code == 0 and vim.trim(res.stdout) or nil
end

local function herdr(args)
	local res = vim.system(vim.list_extend({ "herdr" }, args), { text = true }):wait()
	if res.code ~= 0 then
		return nil
	end
	local ok, decoded = pcall(vim.json.decode, res.stdout)
	return ok and type(decoded) == "table" and decoded.result or nil
end

--- The language of the code under the cursor: the quarto chunk, else the filetype.
function M.language()
	local ok, otter = pcall(require, "otter.tools.functions")
	if ok then
		for _, lang in ipairs({ "python", "r", "bash" }) do
			if otter.is_otter_language_context(lang) then
				return lang
			end
		end
	end
	local ft = vim.bo.filetype
	if ft == "python" or ft == "r" then
		return ft
	end
	return "bash"
end

-- A REPL pane in this herdr tab, left from an earlier session or opened by hand.
local function find_existing(lang)
	if backend() ~= "herdr" then
		return nil
	end
	local current, list = herdr({ "pane", "current" }), herdr({ "pane", "list" })
	if not (current and list) then
		return nil
	end
	local others = {}
	for _, p in ipairs(list.panes) do
		if p.tab_id == current.pane.tab_id and p.pane_id ~= current.pane.pane_id then
			if p.label == "nvim-repl:" .. lang then
				return p.pane_id
			end
			others[#others + 1] = p.pane_id
		end
	end
	local process = REPL_PROCESSES[lang]
	if not process then
		return nil
	end
	for _, pane_id in ipairs(others) do
		local info = herdr({ "pane", "process-info", "--pane", pane_id })
		for _, proc in ipairs(info and info.process_info.foreground_processes or {}) do
			if proc.name == process then
				return pane_id
			end
		end
	end
end

--- Point slime at the REPL pane for the language under the cursor.
local function pane_exists(pane_id)
	if backend() == "tmux" then
		return tmux({ "display-message", "-p", "-t", pane_id, "#{pane_id}" }) == pane_id
	end
	return herdr({ "pane", "get", pane_id }) ~= nil
end

function M.update()
	local mux = backend()
	if not mux then
		return
	end
	local lang = M.language()
	-- Forget panes that were closed since.
	if panes[lang] and not pane_exists(panes[lang]) then
		panes[lang] = nil
	end
	panes[lang] = panes[lang] or find_existing(lang)
	if mux == "tmux" then
		vim.b.slime_config = { socket_name = tmux_socket(), target_pane = panes[lang] or "{right-of}" }
	else
		vim.b.slime_config = { pane_id = panes[lang] or "" }
	end
end

--- Open a REPL in a new pane to the right, and send this language's code there.
function M.start(lang)
	local mux = backend()
	if not mux then
		vim.notify("REPLs need herdr or tmux", vim.log.levels.WARN)
		return
	end
	-- The pane starts from the multiplexer's environment, so pass on an active venv.
	local env = {}
	if lang == "python" then
		for _, var in ipairs({ "PATH", "VIRTUAL_ENV", "LD_LIBRARY_PATH" }) do
			if vim.env[var] and vim.env[var] ~= "" then
				env[#env + 1] = var .. "=" .. vim.env[var]
			end
		end
	end

	local pane_id
	if mux == "tmux" then
		local split = { "split-window", "-h", "-P", "-F", "#{pane_id}" }
		for _, e in ipairs(env) do
			vim.list_extend(split, { "-e", e })
		end
		table.insert(split, REPL_CMDS[lang])
		pane_id = tmux(split)
	else
		local split = { "pane", "split", "--current", "--direction", "right" }
		for _, e in ipairs(env) do
			vim.list_extend(split, { "--env", e })
		end
		local res = herdr(split)
		pane_id = res and res.pane and res.pane.pane_id
		if pane_id then
			herdr({ "pane", "run", pane_id, REPL_CMDS[lang] })
			herdr({ "pane", "rename", pane_id, "nvim-repl:" .. lang })
		end
	end
	if not pane_id or pane_id == "" then
		vim.notify("Could not open a pane for the " .. lang .. " REPL", vim.log.levels.ERROR)
		return
	end
	panes[lang] = pane_id
	M.update()
	vim.notify(lang .. " REPL started in pane " .. pane_id)
end

function M.list()
	local lines = { "REPL panes:" }
	for lang, pane in pairs(panes) do
		lines[#lines + 1] = "  " .. lang .. ": " .. pane
	end
	lines[#lines + 1] = "Current language: " .. M.language()
	M.update()
	vim.notify(table.concat(lines, "\n"))
end

function M.setup()
	vim.g.slime_target = backend() or "herdr"
	vim.g.slime_default_config = default_config()
	vim.g.slime_no_mappings = true
	vim.g.slime_python_ipython = 1
	vim.g.slime_dont_ask_default = 1
	vim.g.slime_input_pid = false
	vim.g.slime_suggest_default = true
	vim.g.slime_menu_config = false
	vim.g.slime_dispatch_ipython_pause = 100

	-- Multi-line Python goes to IPython through %cpaste, so indentation survives.
	-- In quarto only for Python chunks (otter sets b:quarto_is_python_chunk).
	vim.cmd([[
		function! SlimeOverride_EscapeText_quarto(text)
			call v:lua.require'otter.tools.functions'.is_otter_language_context('python')
			if len(split(a:text, "\n")) > 1 && get(b:, 'quarto_is_python_chunk', 0)
				return ["%cpaste -q\n", g:slime_dispatch_ipython_pause, a:text, "--", "\n"]
			endif
			return [a:text]
		endfunction

		function! SlimeOverride_EscapeText_python(text)
			if len(split(a:text, "\n")) > 1
				return ["%cpaste -q\n", g:slime_dispatch_ipython_pause, a:text, "--", "\n"]
			endif
			return [a:text]
		endfunction

		function! SlimeOverride_ConfigureTarget()
			call v:lua.require'utils.repl'.update()
			return b:slime_config
		endfunction
	]])

	vim.api.nvim_create_autocmd("FileType", {
		group = vim.api.nvim_create_augroup("UserRepl", { clear = true }),
		pattern = FILETYPES,
		callback = function(ev)
			vim.b[ev.buf].slime_config = default_config()
			if vim.tbl_contains({ "python", "sh", "bash", "zsh" }, vim.bo[ev.buf].filetype) then
				vim.b[ev.buf].slime_cell_delimiter = "# %%"
			end
		end,
	})

	local map = vim.keymap.set
	map("n", "<leader>cip", function()
		M.start("python")
	end, { desc = "Start IPython REPL" })
	map("n", "<leader>cir", function()
		M.start("r")
	end, { desc = "Start R REPL" })
	map("n", "<leader>cib", function()
		M.start("bash")
	end, { desc = "Start Bash REPL" })
	map("n", "<leader>cl", M.list, { desc = "List REPL panes" })
	map("n", "<leader>cm", function()
		vim.fn["slime#config"]()
	end, { desc = "Pick REPL pane" })
	map("n", "<C-c><C-c>", function()
		M.update()
		vim.fn["slime#send_cell"]()
	end, { desc = "Send cell to REPL" })
	map("x", "<C-c><C-c>", function()
		M.update()
		vim.cmd("'<,'>SlimeRegionSend")
	end, { desc = "Send selection to REPL" })
end

return M
