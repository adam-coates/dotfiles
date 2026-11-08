-- Ctrl-h/j/k/l move between Neovim windows and, at the edge, into the next
-- herdr or tmux pane. herdr passes these keys to Neovim
-- (~/.config/herdr/scripts/navigate.sh); in tmux the vim-tmux-navigator tmux
-- plugin does the same.

local M = {}

local TMUX_FLAG = { h = "-L", j = "-D", k = "-U", l = "-R" }
local HERDR_DIR = { h = "left", j = "down", k = "up", l = "right" }

function M.move(key)
	-- winnr() of the neighbour is the current window when there is none.
	if vim.fn.winnr(key) ~= vim.fn.winnr() then
		vim.cmd.wincmd(key)
	elseif vim.env.HERDR_ENV == "1" then
		vim.system({ "herdr", "pane", "focus", "--pane", vim.env.HERDR_PANE_ID, "--direction", HERDR_DIR[key] })
	elseif vim.env.TMUX then
		vim.system({ "tmux", "select-pane", "-t", vim.env.TMUX_PANE, TMUX_FLAG[key] })
	end
end

function M.setup()
	for key, dir in pairs(HERDR_DIR) do
		vim.keymap.set("n", "<C-" .. key .. ">", function()
			M.move(key)
		end, { desc = "Window or pane " .. dir })
	end
end

return M
