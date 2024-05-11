return {
	"itchyny/calendar.vim",
	event = "VeryLazy",
	init = function()
		vim.g.calendar_google_calendar = "1"
		vim.g.calendar_google_task = "1"
		vim.cmd("source ~/.cache/calendar.vim/credentails.vim")
	end,
}
