return {
    "jalvesaq/zotcite",
    branch = "no_pynvim",
    dependencies = {
        "nvim-treesitter/nvim-treesitter",
        "nvim-telescope/telescope.nvim",
    },
    config = function()
        require("zotcite").setup({
            zotero_sqlite_path = "/home/adam/Zotero/zotero.sqlite",
            key_type = "better-bibtex", -- or "template" or "zotero"
            attach_dir = "/home/adam/Nextcloud/zotero",
            open_in_zotero = true,
        })
    end,
}
