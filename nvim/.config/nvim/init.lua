-- Neovim for code and notes: a full note-taking app (Obsidian and its plugins)
-- together with everything from the previous config.
--
-- Lives in ~/dotfiles/nvim, linked to ~/.config/nvim with stow.
--
-- Everything you are likely to change lives in lua/settings.lua.
-- README.md lists the features and the keymaps; <leader>? shows them in here.

vim.loader.enable()

if vim.fn.has("nvim-0.12") == 0 then
	vim.api.nvim_echo({ { "This config needs Neovim 0.12 or newer (it uses vim.pack)", "ErrorMsg" } }, true, {})
	return
end

require("config.options")
require("config.pack")
require("config.theme").load()

require("plugins.ui")
require("plugins.treesitter")
require("plugins.completion")
require("plugins.lsp")
require("plugins.formatting")
require("plugins.obsidian")
require("plugins.markdown")
require("plugins.tools")
-- From your previous config
require("plugins.quarto")
require("plugins.tables")
require("plugins.printer")
require("plugins.debug")

require("notes").setup()

require("config.keymaps")
require("config.autocmds")

-- From your previous config: reviewing Word documents' tracked changes (<leader>ow,
-- :DocxReview).
require("utils.docx").setup()
