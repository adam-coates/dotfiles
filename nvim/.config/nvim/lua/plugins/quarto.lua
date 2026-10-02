return {
	{
		"quarto-dev/quarto-nvim",
		ft = { "quarto", "markdown" },
		dependencies = {
			"jmbuhr/otter.nvim",
			"nvim-treesitter/nvim-treesitter",
		},
		opts = {
			lspFeatures = {
				enabled = true,
				chunks = "curly",
				languages = { "r", "python", "julia", "bash", "html" },
				diagnostics = {
					enabled = true,
					triggers = { "BufWritePost" },
				},
				completion = {
					enabled = true,
				},
			},
			codeRunner = {
				enabled = true,
				default_method = "slime",
			},
		},
		config = function(_, opts)
			require("quarto").setup(opts)

			-- Basic keybindings
			local quarto = require("quarto")
			local runner = require("quarto.runner")

			vim.keymap.set("n", "<leader>qp", quarto.quartoPreview, { desc = "Quarto Preview" })
			vim.keymap.set("n", "<leader>qq", quarto.quartoClosePreview, { desc = "Quarto Close Preview" })
			vim.keymap.set("n", "<leader>qa", "<cmd>QuartoActivate<cr>", { desc = "Quarto Activate" })

			-- Code running
			vim.keymap.set("n", "<localleader>rc", function()
				_G.update_slime_config()
				require("quarto.runner").run_cell()
			end, { desc = "Run cell" })

			vim.keymap.set("n", "<localleader>ra", function()
				_G.update_slime_config()
				require("quarto.runner").run_above()
			end, { desc = "Run cell and above" })

			vim.keymap.set("n", "<localleader>rb", function()
				_G.update_slime_config()
				require("quarto.runner").run_below()
			end, { desc = "Run cell and below" })

			vim.keymap.set("n", "<localleader>rA", function()
				_G.update_slime_config()
				require("quarto.runner").run_all()
			end, { desc = "Run all cells" })

			vim.keymap.set("n", "<localleader>rl", function()
				_G.update_slime_config()
				require("quarto.runner").run_line()
			end, { desc = "Run line" })

			vim.keymap.set("v", "<localleader>r", function()
				_G.update_slime_config()
				require("quarto.runner").run_range()
			end, { desc = "Run visual range" })
		end,
	},
	{
		"jmbuhr/otter.nvim",
		ft = { "quarto", "markdown" },
		dependencies = {
			"nvim-treesitter/nvim-treesitter",
		},
		opts = {
			buffers = {
				set_filetype = true,
			},
		},
	},
	{
		"jpalardy/vim-slime",
		ft = { "quarto", "markdown", "python", "r" },
		init = function()
			vim.b["quarto_is_python_chunk"] = false
			Quarto_is_in_python_chunk = function()
				require("otter.tools.functions").is_otter_language_context("python")
			end

			vim.cmd([[
			let g:slime_dispatch_ipython_pause = 100
			function SlimeOverride_EscapeText_quarto(text)
				call v:lua.Quarto_is_in_python_chunk()
				if exists('g:slime_python_ipython') && len(split(a:text,"\n")) > 1 && b:quarto_is_python_chunk && !(exists('b:quarto_is_r_mode') && b:quarto_is_r_mode)
					return ["%cpaste -q\n", g:slime_dispatch_ipython_pause, a:text, "--", "\n"]
				else
					if exists('b:quarto_is_r_mode') && b:quarto_is_r_mode && b:quarto_is_python_chunk
						return [a:text, "\n"]
					else
						return [a:text]
					endif
				endif
			endfunction

			" Handle multi-line Python sent to IPython via %cpaste
			function SlimeOverride_EscapeText_python(text)
				if exists('g:slime_python_ipython') && len(split(a:text,"\n")) > 1
					return ["%cpaste -q\n", g:slime_dispatch_ipython_pause, a:text, "--", "\n"]
				else
					return [a:text]
				endif
			endfunction
		]])

			-- Auto-detect multiplexer
			local in_herdr = vim.fn.getenv("HERDR_ENV") == "1"

			if in_herdr then
				vim.g.slime_target = "herdr"
				vim.g.slime_default_config = { pane_id = "" }
			else
				vim.g.slime_target = "tmux"
				vim.g.slime_default_config = { socket_name = "default", target_pane = "{right-of}" }
			end

			vim.g.slime_no_mappings = true
			vim.g.slime_python_ipython = 1
			vim.g.slime_dont_ask_default = 1
		end,
		config = function()
			vim.g.slime_input_pid = false
			vim.g.slime_suggest_default = true
			vim.g.slime_menu_config = false

			-- Store pane configurations for different REPLs
			_G.repl_panes = {
				python = nil,
				r = nil,
				bash = nil,
			}

			-- Helper function to get current language context
			_G.get_current_language = function()
				local ok, otter = pcall(require, "otter.tools.functions")
				if ok then
					if otter.is_otter_language_context("python") then
						return "python"
					elseif otter.is_otter_language_context("r") then
						return "r"
					end
				end
				-- Fallback to filetype
				local ft = vim.bo.filetype
				if ft == "python" then
					return "python"
				elseif ft == "r" then
					return "r"
				end
				return "bash"
			end

			local in_herdr = vim.fn.getenv("HERDR_ENV") == "1"

			-- Function to update slime config based on current language
			_G.update_slime_config = function()
				local lang = _G.get_current_language()
				local pane = _G.repl_panes[lang]

				if in_herdr then
					local pane_id = pane or ""
					vim.b.slime_config = { pane_id = pane_id }
					vim.cmd(string.format([[let b:slime_config = {"pane_id": "%s"}]], pane_id))
				else
					if pane then
						vim.b.slime_config = { socket_name = "default", target_pane = pane }
						vim.cmd(string.format(
							[[let b:slime_config = {"socket_name": "default", "target_pane": "%s"}]], pane
						))
					else
						vim.b.slime_config = { socket_name = "default", target_pane = "{right-of}" }
						vim.cmd([[let b:slime_config = {"socket_name": "default", "target_pane": "{right-of}"}]])
					end
				end
			end

			-- Initialize slime config for all relevant buffers
			vim.api.nvim_create_autocmd("FileType", {
				pattern = { "quarto", "markdown", "python", "r" },
				callback = function()
					if in_herdr then
						vim.b.slime_config = { pane_id = "" }
						vim.cmd([[let b:slime_config = {"pane_id": ""}]])
					else
						vim.b.slime_config = { socket_name = "default", target_pane = "{right-of}" }
						vim.cmd([[let b:slime_config = {"socket_name": "default", "target_pane": "{right-of}"}]])
					end

					if vim.bo.filetype == "python" then
						vim.b.slime_cell_delimiter = "# %%"
					end
				end,
			})

			-- Override slime's config function
			vim.cmd([[
			function! SlimeOverride_ConfigureTarget()
				call luaeval('_G.update_slime_config()')
				return b:slime_config
			endfunction
		]])

			local function get_env(var)
				local val = vim.fn.getenv(var)
				if val == vim.v.null then return "" end
				return val
			end

			local function start_repl(repl_type, repl_cmd)
				if in_herdr then
					-- Get panes before split
					local before_json = vim.fn.system("herdr pane list")
					local before = vim.fn.json_decode(before_json)
					local before_ids = {}
					for _, p in ipairs(before.result.panes) do
						before_ids[p.pane_id] = true
					end

					-- Split and run the REPL
					local split_cmd = { "herdr", "pane", "split", "--direction", "right" }
					if repl_type == "python" then
						local ld = get_env("LD_LIBRARY_PATH")
						local path = get_env("PATH")
						if ld ~= "" then
							vim.list_extend(split_cmd, { "--env", "LD_LIBRARY_PATH=" .. ld })
						end
						if path ~= "" then
							vim.list_extend(split_cmd, { "--env", "PATH=" .. path })
						end
					end
					vim.fn.system(split_cmd)

					vim.defer_fn(function()
						local after_json = vim.fn.system("herdr pane list")
						local after = vim.fn.json_decode(after_json)
						local new_pane = nil
						for _, p in ipairs(after.result.panes) do
							if not before_ids[p.pane_id] then
								new_pane = p.pane_id
								break
							end
						end

						if new_pane then
							-- Run the REPL command in the new pane
							vim.fn.system({ "herdr", "pane", "run", new_pane, repl_cmd })
							_G.repl_panes[repl_type] = new_pane
							print(string.format("%s REPL started in pane %s", repl_type, new_pane))
							_G.update_slime_config()
						else
							print(string.format("Warning: Could not detect new pane for %s", repl_type))
						end
					end, 300)
				else
					-- tmux path
					local panes_before = vim.fn.systemlist("tmux list-panes -F '#{pane_id}'")

					local cmd = { "tmux", "split-window", "-h" }

					if repl_type == "python" then
						local ld = get_env("LD_LIBRARY_PATH")
						local path = get_env("PATH")
						if ld ~= "" then
							vim.list_extend(cmd, { "-e", "LD_LIBRARY_PATH=" .. ld })
						end
						if path ~= "" then
							vim.list_extend(cmd, { "-e", "PATH=" .. path })
						end
					end

					table.insert(cmd, repl_cmd)
					vim.fn.system(cmd)

					vim.defer_fn(function()
						local panes_after = vim.fn.systemlist("tmux list-panes -F '#{pane_id}'")

						local new_pane = nil
						for _, pane in ipairs(panes_after) do
							local found = false
							for _, old_pane in ipairs(panes_before) do
								if pane == old_pane then
									found = true
									break
								end
							end
							if not found then
								new_pane = pane
								break
							end
						end

						if new_pane then
							_G.repl_panes[repl_type] = new_pane
							print(string.format("%s REPL started in pane %s", repl_type, new_pane))
							_G.update_slime_config()
						else
							print(string.format("Warning: Could not detect new pane for %s", repl_type))
						end
					end, 300)
				end
			end

			-- Keymaps to start REPLs
			vim.keymap.set("n", "<leader>cip", function()
				start_repl("python", "ipython")
			end, { desc = "Start IPython REPL" })

			vim.keymap.set("n", "<leader>cir", function()
				start_repl("r", "R")
			end, { desc = "Start R REPL" })

			vim.keymap.set("n", "<leader>cib", function()
				start_repl("bash", "bash")
			end, { desc = "Start Bash REPL" })

			-- Show current REPL panes and test language detection
			vim.keymap.set("n", "<leader>cl", function()
				print("REPL Panes:")
				for lang, pane in pairs(_G.repl_panes) do
					if pane then
						print(string.format("  %s: %s", lang, pane))
					end
				end
				print("Current language: " .. _G.get_current_language())
				_G.update_slime_config()
			end, { desc = "List REPL panes and update config" })

			-- Manual slime config if needed
			vim.keymap.set("n", "<leader>cm", function()
				vim.fn.call("slime#config", {})
			end, { desc = "Slime config/set terminal" })

			-- Slime send keymaps with forced config update
			vim.keymap.set("n", "<c-c><c-c>", function()
				_G.update_slime_config()
				vim.fn["slime#send_cell"]()
			end, { desc = "Send cell to REPL" })

			vim.keymap.set("x", "<c-c><c-c>", function()
				_G.update_slime_config()
				vim.cmd("'<,'>SlimeRegionSend")
			end, { desc = "Send selection to REPL" })
		end,
	},
}
