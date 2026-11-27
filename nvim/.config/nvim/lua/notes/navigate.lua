-- Ctrl-h/j/k/l between windows and, at the edge, into the next herdr or tmux pane.
local M = {}

local HERDR = { h = "left", j = "down", k = "up", l = "right" }
local TMUX = { h = "-L", j = "-D", k = "-U", l = "-R" }

function M.move(key)
	if vim.fn.winnr(key) ~= vim.fn.winnr() then
		vim.cmd.wincmd(key)
	elseif vim.env.HERDR_ENV == "1" then
		vim.system({ "herdr", "pane", "focus", "--pane", vim.env.HERDR_PANE_ID, "--direction", HERDR[key] })
	elseif vim.env.TMUX then
		vim.system({ "tmux", "select-pane", "-t", vim.env.TMUX_PANE, TMUX[key] })
	end
end

return M
