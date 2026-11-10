-- Theme markdown-preview's browser page with the current Omarchy theme.
-- Omarchy renders two templates of ours on every theme switch (dotfiles:
-- omarchy/.config/omarchy/themed/markdown-preview*.tpl) into the current
-- theme folder: CSS variables for the page, and mermaid's theme as JSON.
-- The page loads both when it opens, so refresh the browser after a switch.

local M = {}

M.theme_dir = vim.env.HOME .. "/.local/state/omarchy/current/theme"

local function read(name)
	local path = M.theme_dir .. "/" .. name
	return vim.fn.filereadable(path) == 1 and path or nil
end

function M.update()
	-- Without the rendered file the page keeps the plugin's own light/dark look.
	vim.g.mkdp_theme_css = read("markdown-preview.css")

	local options = vim.g.mkdp_preview_options or {}
	local json = read("markdown-preview-mermaid.json")
	local ok, maid = pcall(vim.json.decode, json and table.concat(vim.fn.readfile(json), "\n") or "")
	if ok and type(maid) == "table" then
		-- The template can only render strings; mermaid wants a boolean.
		maid.themeVariables.darkMode = maid.themeVariables.darkMode ~= "light"
		vim.g.mkdp_theme = maid.themeVariables.darkMode and "dark" or "light"
		options.maid = maid
	else
		options.maid = nil
	end
	-- An empty Lua table reaches Vim as a list, which the plugin rejects, so
	-- leave the option unset and let the plugin fill in its defaults.
	vim.g.mkdp_preview_options = next(options) and options or nil
end

-- Open the preview as a chrome-less app window, the way Omarchy opens web apps.
-- omarchy-launch-webapp picks the default browser if it's Chromium-based
-- (Chrome, Brave, Edge, ...) and falls back to Chromium. Without Omarchy, or
-- with vim.g.markdown_preview_app = false, it opens in a normal browser tab.
function M.open(url)
	if vim.g.markdown_preview_app ~= false and vim.fn.executable("omarchy-launch-webapp") == 1 then
		vim.system({ "omarchy-launch-webapp", url }, { detach = true })
	else
		vim.ui.open(url)
	end
end

function M.setup()
	vim.g.mkdp_filetypes = { "markdown", "quarto" }
	vim.cmd([[
		function! MkdpOpenUrl(url) abort
			call v:lua.require'utils.markdown_preview'.open(a:url)
		endfunction
	]])
	vim.g.mkdp_browserfunc = "MkdpOpenUrl"
	M.update()
	-- Theme switches load a colorscheme, so regenerate on every ColorScheme.
	vim.api.nvim_create_autocmd("ColorScheme", {
		group = vim.api.nvim_create_augroup("UserMarkdownPreview", { clear = true }),
		callback = M.update,
	})
end

-- Run before vim.pack.add, so a fresh install also gets its node packages.
function M.setup_build()
	-- The preview server runs on node, with its packages in app/node_modules.
	vim.api.nvim_create_autocmd("PackChanged", {
		group = vim.api.nvim_create_augroup("UserMarkdownPreviewBuild", { clear = true }),
		callback = function(ev)
			local data = ev.data
			if data.spec.name == "markdown-preview.nvim" and (data.kind == "install" or data.kind == "update") then
				-- npm ci installs exactly what app/package-lock.json lists. npm also
				-- rewrites the tracked app/yarn.lock, so restore it to keep the plugin's
				-- git checkout clean for the next update.
				local app = data.path .. "/app"
				-- on_exit runs in a fast event context, where :wait() (vim.wait) is
				-- not allowed, so chain the git restore through its own callback.
				vim.system({ "npm", "ci", "--omit=dev" }, { cwd = app }, function(res)
					vim.system({ "git", "checkout", "--", "yarn.lock" }, { cwd = app }, function()
						vim.schedule(function()
							local ok = res.code == 0
							vim.notify(
								"markdown-preview: npm ci " .. (ok and "done" or "failed"),
								ok and vim.log.levels.INFO or vim.log.levels.ERROR
							)
						end)
					end)
				end)
			end
		end,
	})
end

return M
