require("adam.core")
require("adam.lazy")


-- detect os and make change as needed
local sysname = vim.loop.os_uname().sysname
if sysname == "Linux" then
    vim.g.notepath = "/mnt/g/"
    vim.g.python3_host_prog = '/home/linuxbrew/.linuxbrew/bin/python3'
elseif sysname == "Darwin" then
    vim.g.notepath = "~/notes/"
else
    vim.g.notepath = "Windows specific value"
end

vim.g.python3_host_prog = '/home/linuxbrew/.linuxbrew/bin/python3'
-- Detect filetype and set it to markdown for GoogleKeepNote
--vim.api.nvim_exec([[
--  augroup GoogleKeepNoteMarkdown
--    autocmd!
--    autocmd FileType GoogleKeepNote setlocal filetype=markdown
--  augroup END
--]], false)

