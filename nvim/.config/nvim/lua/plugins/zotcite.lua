require("zotcite").setup({
  zotero_sqlite_path = "/home/adam/Zotero/zotero.sqlite",
  attach_dir = "/home/adam/Nextcloud/zotero",
  open_in_zotero = true,
  key_type = "better-bibtex",
})

require("utils.zotcite_snacks").setup()
require("utils.zotero_annotations").setup()
