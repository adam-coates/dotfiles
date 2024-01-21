require("adam.core")
require("adam.lazy")
vim.g.python3_host_prog = '/home/linuxbrew/.linuxbrew/bin/python3'
-- Detect filetype and set it to markdown for GoogleKeepNote
--vim.api.nvim_exec([[
--  augroup GoogleKeepNoteMarkdown
--    autocmd!
--    autocmd FileType GoogleKeepNote setlocal filetype=markdown
--  augroup END
--]], false)

