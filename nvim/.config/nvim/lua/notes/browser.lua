-- Open pages as an app window where Omarchy can, otherwise in the browser.
local M = {}

function M.open(url)
	if vim.env.NOTES_NO_BROWSER then
		return
	end
	if vim.fn.executable("omarchy-launch-webapp") == 1 then
		vim.system({ "omarchy-launch-webapp", url }, { detach = true })
	else
		vim.ui.open(url)
	end
end

return M
