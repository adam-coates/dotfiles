gh = function(x)
	return "https://github.com/" .. x
end

require("utils.markdown_preview").setup_build()

vim.pack.add({

  { src = gh("nvim-mini/mini.icons") },
  { src = gh("folke/snacks.nvim") },
  { src = gh("nvim-treesitter/nvim-treesitter") },
  { src = gh("mks-h/treesitter-autoinstall.nvim") },
  { src = gh("saghen/blink.cmp"), version = vim.version.range("1.*") },
  { src = gh("L3MON4D3/LuaSnip"), version = vim.version.range("2.*") },
  { src = gh("rafamadriz/friendly-snippets") },
  { src = gh("jalvesaq/zotcite") },
  { src = gh("mason-org/mason.nvim") },
  { src = gh("WhoIsSethDaniel/mason-tool-installer.nvim") },
  { src = gh("neovim/nvim-lspconfig") },
  { src = gh("folke/lazydev.nvim") },
  { src = gh("stevearc/conform.nvim") },
  { src = gh("jmbuhr/otter.nvim") },
  { src = gh("quarto-dev/quarto-nvim") },
  { src = gh("jpalardy/vim-slime") },
  { src = gh("lewis6991/gitsigns.nvim"), version = vim.version.range("2.*") },
  { src = gh("folke/which-key.nvim") },
  { src = gh("HakonHarnes/img-clip.nvim") },
  { src = gh("adam-coates/markdown-preview.nvim") }, -- fork: admonitions, theming, newer mermaid/KaTeX
  { src = gh("adam-coates/printer.nvim") },
  { src = gh("MeanderingProgrammer/render-markdown.nvim") },
  { src = gh("windwp/nvim-ts-autotag") },
  { src = gh("mfussenegger/nvim-dap") },
  { src = gh("nvim-neotest/nvim-nio") },
  { src = gh("rcarriga/nvim-dap-ui") },
  { src = gh("mfussenegger/nvim-dap-python") },
  { src = gh("theHamsta/nvim-dap-virtual-text") },

})
require("mini.icons").setup()
MiniIcons.mock_nvim_web_devicons() -- plugins asking for devicons get mini.icons
require("plugins.ui")
require("plugins.treesitter")
require("plugins.completion")
require("plugins.lsp")
require("plugins.formatting")
require("plugins.zotcite")
require("plugins.quarto")
require("plugins.editor")
require("plugins.printer")
require("plugins.markdown")
require("plugins.debug")
require("utils.markdown_preview").setup()
require("utils.omarchy.theme").load()
