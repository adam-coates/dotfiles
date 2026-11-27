-- Plugins, with Neovim's own plugin manager. Your previous config's plugins are all
-- here too. They are cloned on the first start (no questions asked) and pinned in
-- nvim-pack-lock.json.
--
--   :PackUpdate   review and apply updates        :PackClean   remove unused ones

local function gh(repo)
	return "https://github.com/" .. repo
end

local range = vim.version.range

-- Build steps. Registered before vim.pack.add so they also run on first install.
vim.api.nvim_create_autocmd("PackChanged", {
	group = vim.api.nvim_create_augroup("notes_pack_build", { clear = true }),
	callback = function(ev)
		local name, kind, path = ev.data.spec.name, ev.data.kind, ev.data.path
		if kind ~= "install" and kind ~= "update" then
			return
		end
		if name == "nvim-treesitter" and kind == "update" then
			vim.schedule(function()
				pcall(vim.cmd, "TSUpdate")
			end)
		elseif name == "markdown-preview.nvim" and vim.fn.executable("npm") == 1 then
			-- npm rewrites the tracked yarn.lock; put it back so updates stay clean.
			vim.system({ "npm", "ci", "--omit=dev" }, { cwd = path .. "/app" }, function(res)
				vim.system({ "git", "checkout", "--", "yarn.lock" }, { cwd = path .. "/app" })
				vim.schedule(function()
					if res.code ~= 0 then
						vim.notify("markdown-preview: npm ci failed", vim.log.levels.ERROR)
					end
				end)
			end)
		end
	end,
})

vim.pack.add({
	-- The note engine: links, backlinks, completion, daily notes, templates, ...
	{ src = gh("obsidian-nvim/obsidian.nvim"), version = range("3.*") },

	-- Interface
	{ src = gh("folke/snacks.nvim") },
	{ src = gh("folke/which-key.nvim") },
	{ src = gh("nvim-mini/mini.nvim") }, -- icons, surround, text objects

	-- Markdown
	{ src = gh("nvim-treesitter/nvim-treesitter") },
	{ src = gh("MeanderingProgrammer/render-markdown.nvim"), version = range("8.*") },
	{ src = gh("YousefHadder/markdown-plus.nvim"), version = range("2.*") },
	{ src = gh("HakonHarnes/img-clip.nvim") },
	{ src = gh("adam-coates/markdown-preview.nvim") }, -- fork: admonitions, theming, newer mermaid/KaTeX

	{ src = gh("mks-h/treesitter-autoinstall.nvim") },

	-- Completion and snippets
	{ src = gh("saghen/blink.cmp"), version = range("1.*") },
	{ src = gh("L3MON4D3/LuaSnip"), version = range("2.*") },
	{ src = gh("rafamadriz/friendly-snippets") },
	{ src = gh("moyiz/blink-emoji.nvim") },

	-- Language servers, formatting, tools
	{ src = gh("mason-org/mason.nvim") },
	{ src = gh("WhoIsSethDaniel/mason-tool-installer.nvim") },
	{ src = gh("neovim/nvim-lspconfig") },
	{ src = gh("folke/lazydev.nvim") },
	{ src = gh("stevearc/conform.nvim") },
	{ src = gh("windwp/nvim-ts-autotag") },

	-- Quarto, code cells and REPLs (from the previous config)
	{ src = gh("jmbuhr/otter.nvim") },
	{ src = gh("quarto-dev/quarto-nvim") },
	{ src = gh("jpalardy/vim-slime") },

	-- Debugging (from the previous config)
	{ src = gh("mfussenegger/nvim-dap") },
	{ src = gh("nvim-neotest/nvim-nio") },
	{ src = gh("rcarriga/nvim-dap-ui") },
	{ src = gh("mfussenegger/nvim-dap-python") },
	{ src = gh("theHamsta/nvim-dap-virtual-text") },

	-- Searching, history, references, printing
	{ src = gh("lewis6991/gitsigns.nvim"), version = range("2.*") },
	{ src = gh("MagicDuck/grug-far.nvim") },
	{ src = gh("jalvesaq/zotcite") },
	{ src = gh("adam-coates/printer.nvim") }, -- receipt printer
}, { confirm = false })

vim.api.nvim_create_user_command("PackUpdate", function()
	vim.pack.update()
end, { desc = "Update plugins" })

vim.api.nvim_create_user_command("PackClean", function()
	local unused = vim.iter(vim.pack.get())
		:filter(function(p)
			return not p.active
		end)
		:map(function(p)
			return p.spec.name
		end)
		:totable()
	if #unused == 0 then
		return vim.notify("No unused plugins")
	end
	if vim.fn.confirm("Remove " .. table.concat(unused, ", ") .. "?", "&Yes\n&No") == 1 then
		vim.pack.del(unused)
	end
end, { desc = "Remove plugins that are installed but not used" })
