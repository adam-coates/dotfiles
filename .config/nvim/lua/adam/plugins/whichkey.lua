return {
	"folke/which-key.nvim",
	event = "VeryLazy",
	init = function()
		vim.o.timeout = true
		vim.o.timeoutlen = 300
	end,
	config = function()
		local wk = require("which-key")
		vim.g["quarto_is_r_mode"] = nil
		vim.g["reticulate_running"] = false
		local nmap = function(key, effect)
			vim.keymap.set("n", key, effect, { silent = true, noremap = true })
		end

		local vmap = function(key, effect)
			vim.keymap.set("v", key, effect, { silent = true, noremap = true })
		end

		local imap = function(key, effect)
			vim.keymap.set("i", key, effect, { silent = true, noremap = true })
		end

		local cmap = function(key, effect)
			vim.keymap.set("c", key, effect, { silent = true, noremap = true })
		end
		local function send_cell()
			if vim.b["quarto_is_r_mode"] == nil then
				vim.fn["slime#send_cell"]()
				return
			end
			if vim.b["quarto_is_r_mode"] == true then
				vim.g.slime_python_ipython = 0
				local is_python = require("otter.tools.functions").is_otter_language_context("python")
				if is_python and not vim.b["reticulate_running"] then
					vim.fn["slime#send"]("reticulate::repl_python()" .. "\r")
					vim.b["reticulate_running"] = true
				end
				if not is_python and vim.b["reticulate_running"] then
					vim.fn["slime#send"]("exit" .. "\r")
					vim.b["reticulate_running"] = false
				end
				vim.fn["slime#send_cell"]()
			end
		end
		local slime_send_region_cmd = ":<C-u>call slime#send_op(visualmode(), 1)<CR>"
		slime_send_region_cmd = vim.api.nvim_replace_termcodes(slime_send_region_cmd, true, false, true)
		local function send_region()
			-- if filetyps is not quarto, just send_region
			if vim.bo.filetype ~= "quarto" or vim.b["quarto_is_r_mode"] == nil then
				vim.cmd("normal" .. slime_send_region_cmd)
				return
			end
			if vim.b["quarto_is_r_mode"] == true then
				vim.g.slime_python_ipython = 0
				local is_python = require("otter.tools.functions").is_otter_language_context("python")
				if is_python and not vim.b["reticulate_running"] then
					vim.fn["slime#send"]("reticulate::repl_python()" .. "\r")
					vim.b["reticulate_running"] = true
				end
				if not is_python and vim.b["reticulate_running"] then
					vim.fn["slime#send"]("exit" .. "\r")
					vim.b["reticulate_running"] = false
				end
				vim.cmd("normal" .. slime_send_region_cmd)
			end
		end
		nmap("<c-cr>", send_cell)
		nmap("<s-cr>", send_cell)
		imap("<c-cr>", send_cell)
		imap("<s-cr>", send_cell)
		local is_code_chunk = function()
			local current, _ = require("otter.keeper").get_current_language_context()
			if current then
				return true
			else
				return false
			end
		end

		-- Insert code chunk of given language
		-- Splits current chunk if already within a chunk
		-- @param lang string
		local insert_code_chunk = function(lang)
			vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<esc>", true, false, true), "n", true)
			local keys
			if is_code_chunk() then
				keys = [[o```<cr><cr>```{]] .. lang .. [[}<esc>o]]
			else
				keys = [[o```{]] .. lang .. [[}<cr>```<esc>O]]
			end
			keys = vim.api.nvim_replace_termcodes(keys, true, false, true)
			vim.api.nvim_feedkeys(keys, "n", false)
		end

		local insert_r_chunk = function()
			insert_code_chunk("r")
		end

		local insert_py_chunk = function()
			insert_code_chunk("python")
		end

		local insert_lua_chunk = function()
			insert_code_chunk("lua")
		end

		local insert_julia_chunk = function()
			insert_code_chunk("julia")
		end

		local insert_bash_chunk = function()
			insert_code_chunk("bash")
		end

		local insert_ojs_chunk = function()
			insert_code_chunk("ojs")
		end
		wk.register({
			["<m-i>"] = { insert_r_chunk, "r code chunk" },
			["<cm-i>"] = { insert_py_chunk, "python code chunk" },
			["<m-I>"] = { insert_py_chunk, "python code chunk" },
			["<leader>"] = {
				p = {
					name = "PANDOC",
					w = { "<cmd>TermExec cmd='pandoc %:p -o %:p:r.docx'<CR>", "word" },
					m = { "<cmd>TermExec cmd='pandoc %:p -o %:p:r.md'<CR>", "markdown" },
					h = { "<cmd>TermExec cmd='pandoc %:p -o %:p:r.html'<CR>", "html" },
					l = { "<cmd>TermExec cmd='pandoc %:p -o %:p:r.tex'<CR>", "latex" },
					p = {
						name = "PDF",

						p = { "<cmd>TermExec cmd='pandoc %:p -o %:p:r.pdf'<CR>", "pdf default engine" },
						x = {
							"<cmd>TermExec cmd='pandoc --pdf-engine=xelatex %:p -o %:p:r.pdf'<CR>",
							"pdf xelatex engine",
						},
						h = {
							"<cmd>TermExec cmd='pandoc --pdf-engine=wkhtmltopdf %:p -o %:p:r.pdf'<CR>",
							"pdf xelatex engine",
						},
						z = {
							"<cmd>TermExec cmd='pandoc %:p -o %:p:r.pdf -F ~/.local/share/nvim/lazy/zotcite/python3/zotref.py --citeproc --csl /mnt/g/apa.csl'<CR>",
							"Convert to pdf (zotref.py/apa.csl)",
						},
						a = { "<cmd>TermExec cmd='bash ./test.sh %:p'<CR>", "test" },
					},
				},
				k = {
					name = "Gkeep2MD",
					k = {
						"<cmd>TermExec cmd='python3 /home/linuxbrew/.linuxbrew/lib/python3.11/site-packages/keep-it-markdown-0.5.3/kim.py'<CR>",
						"kim",
					},
				},
				m = {
					name = "MdTOC",
					t = { "<cmd>TermExec cmd='markdown-toc -i %:p'<CR>", "Create TOC" },
				},
				e = { name = "File Explorer" },
				f = { name = "Find Files" },
				t = { name = "Tab" },
				w = { name = "Vimwiki" },
				c = { name = "Code actions" },
				r = { name = "Smart Rename/ RestartLSP" },
				z = { name = "Folding" },
				["<m-p>"] = { ":split term://ipython<cr>", "new [p]ython terminal" },
				["<m-r>"] = {
					function()
						vim.b["quarto_is_r_mode"] = true
						vim.cmd("split term://R")
					end,
					"new [R] terminal",
				},
				["<m-s>"] = { ":split term://$SHELL<cr>", "[n]ew terminal with shell" },
			},
		})
		wk.register({
			["<cr>"] = { send_region, "run code region" },
		}, { mode = "v" })
	end,
}
