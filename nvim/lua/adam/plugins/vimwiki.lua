return {
    "vimwiki/vimwiki",
    init = function()
        vim.g.vimwiki_list = {{path = '[PATH TO GDRIVE]', syntax = 'markdown', ext = '.md', listsyms = ' ○◐●✓'}}
    vim.g.vimwiki_folding = "list"
--    vim.treesitter.language.register('markdown', 'vimwiki')
    vim.g.vimwiki_global_ext = 0
    end,
}
