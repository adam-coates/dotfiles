return {
	"mason-org/mason.nvim",
	version = "1.11.0",
	build = ":MasonUpdate",
	opts = {
		registries = {
			"github:mason-org/mason-registry",
			"github:visimp/mason-registry", -- for ltex_plus
		},
		ui = {
			icons = {
				package_installed = "✓",
				package_pending = "➜",
				package_uninstalled = "✗",
			},
		},
	},
}
