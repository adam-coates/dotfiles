local blink = require("blink.cmp")
return {
    cmd = { "astro-ls", "--stdio" },
    filetypes = { "astro" },
    init_options = {
        typescript = {
            tsdk = '/home/adam/.local/share/mise/installs/node/22.19.0/lib/node_modules/typescript/lib'
        }
    },
    capabilities = vim.tbl_deep_extend(
        "force",
        {},
        vim.lsp.protocol.make_client_capabilities(),
        blink.get_lsp_capabilities(),
        {
            fileOperations = {
                didRename = true,
                willRename = true,
            },
        }
    ),
}
