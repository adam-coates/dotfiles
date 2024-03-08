require("adam.core")
require("adam.lazy")


-- detect os and make change as needed
local sysname = vim.loop.os_uname().sysname
if sysname == "Linux" then
    vim.g.python3_host_prog = '/home/linuxbrew/.linuxbrew/bin/python3'
elseif sysname == "Darwin" then
    --vim.g.python3_host_prog = 'already on path using brew'
else
    --vim.g.notepath = "change here for windows"
end

vim.cmd("command! Test !python3 /home/adam/.config/nvim/test.py")
