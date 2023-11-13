return {
    "vimwiki/vimwiki",
    init = function()
        vim.g.vimwiki_list = {{path = 'C:/Users/Adam/Desktop/notes', syntax = 'markdown', ext = '.md'}}
    vim.g.vimwiki_folding = "list"
--    vim.treesitter.language.register('markdown', 'vimwiki')
    end,
}
