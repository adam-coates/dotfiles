local blink = require("blink.cmp")
return {
    cmd = { "harper-ls", "--stdio" },
    filetypes = { "markdown", "quarto" },
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
