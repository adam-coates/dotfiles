return {
	"jalvesaq/zotcite",
	dependencies = {
		"jalvesaq/cmp-zotcite",
	},
	config = function()
		require("zotcite").setup({
			open_in_zotero = true,
		})
	end,
}
