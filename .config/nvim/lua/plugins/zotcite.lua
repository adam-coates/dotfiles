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
            tmpdir = "/tmp/zotcite-copy",
            key_type = "zotero", -- or "template" or "zotero"
            attach_dir = "/home/adam/Nextcloud/zotero",
            open_in_zotero = true,
        })
    end,
}
