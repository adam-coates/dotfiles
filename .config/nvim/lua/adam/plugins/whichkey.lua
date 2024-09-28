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

		wk.add({
			{
				{ "<leader><m-p>", ":split term://ipython<cr>", desc = "new [p]ython terminal" },
				{
					"<leader><m-r>",
					function()
						vim.b["quarto_is_r_mode"] = true
						vim.cmd("split term://R")
					end,
					desc = "new [R] terminal",
				},
				{ "<leader><m-s>", ":split term://$SHELL<cr>", desc = "[n]ew terminal with shell" },
				{ "<leader>c", group = "Code actions" },
				{ "<leader>e", group = "File Explorer" },
				{ "<leader>f", group = "Find Files" },
				{ "<leader>k", group = "Gkeep2MD" },
				{
					"<leader>kk",
					"<cmd>TermExec cmd='python3 /home/linuxbrew/.linuxbrew/lib/python3.11/site-packages/keep-it-markdown-0.5.3/kim.py'<CR>",
					desc = "kim",
				},
				{ "<leader>m", group = "MdTOC" },
				{ "<leader>mt", "<cmd>TermExec cmd='markdown-toc -i %:p'<CR>", desc = "Create TOC" },
				{ "<leader>p", group = "PANDOC" },
				{ "<leader>ph", "<cmd>TermExec cmd='pandoc %:p -o %:p:r.html'<CR>", desc = "html" },
				{ "<leader>pl", "<cmd>TermExec cmd='pandoc %:p -o %:p:r.tex'<CR>", desc = "latex" },
				{ "<leader>pm", "<cmd>TermExec cmd='pandoc %:p -o %:p:r.md'<CR>", desc = "markdown" },
				{ "<leader>pp", group = "PDF" },
				{ "<leader>ppa", "<cmd>TermExec cmd='bash ./test.sh %:p'<CR>", desc = "test" },
				{
					"<leader>pph",
					"<cmd>TermExec cmd='pandoc --pdf-engine=wkhtmltopdf %:p -o %:p:r.pdf'<CR>",
					desc = "pdf xelatex engine",
				},
				{ "<leader>ppp", "<cmd>TermExec cmd='pandoc %:p -o %:p:r.pdf'<CR>", desc = "pdf default engine" },
				{
					"<leader>ppx",
					"<cmd>TermExec cmd='pandoc --pdf-engine=xelatex %:p -o %:p:r.pdf'<CR>",
					desc = "pdf xelatex engine",
				},
				{
					"<leader>ppz",
					"<cmd>TermExec cmd='pandoc %:p -o %:p:r.pdf -F ~/.local/share/nvim/lazy/zotcite/python3/zotref.py --citeproc --csl /mnt/g/apa.csl'<CR>",
					desc = "Convert to pdf (zotref.py/apa.csl)",
				},
				{ "<leader>pw", "<cmd>TermExec cmd='pandoc %:p -o %:p:r.docx'<CR>", desc = "word" },
				{ "<leader>r", group = "Smart Rename/ RestartLSP" },
				{ "<leader>t", group = "Tab" },
				{ "<leader>w", group = "Vimwiki" },
				{ "<leader>z", group = "Folding" },
				{
					"<m-I>",
					function()
						insert_code_chunk("python")
					end,
					desc = "python code chunk",
				},
				{
					"<m-i>",
					function()
						insert_code_chunk("r")
					end,
					desc = "r code chunk",
				},
				{
					"<cr>",
					function()
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
					end,
					desc = "run code region",
					mode = "v",
				},
				{
					"<leader>cm",
					function()
						vim.g.slime_last_channel = vim.b.terminal_job_id
						vim.print(vim.g.slime_last_channel)
					end,
					desc = "mark terminal",
				},
				{
					"<leader>cs",
					function()
						vim.b.slime_config = { jobid = vim.g.slime_last_channel }
					end,
					desc = "set terminal",
				},
				{
					"<leader>obc",
					function()
						vim.cmd.write()
						print("Running...")
						local obsidian_command =
							'xdg-open "obsidian://advanced-uri?openmode=window&commandname=Zotero Integration: Import citation notes"'
						obsidian_command = obsidian_command:gsub(" ", "\\ ")
						local the_cmd = string.format([[TermExec cmd='%s']], obsidian_command)
						vim.cmd(the_cmd)
					end,
					desc = "Create citation note",
				},
			},
		})
	end,
}
