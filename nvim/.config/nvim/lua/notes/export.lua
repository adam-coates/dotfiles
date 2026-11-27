-- Export a note with pandoc: PDF (through typst), Word, HTML, slides, ... Wiki
-- links, embeds, callouts, highlights and comments are turned into things pandoc
-- understands first.

local util = require("notes.util")
local vault = require("notes.vault")
local index = require("notes.index")

local M = {}

local CALLOUT = { note = "Note", tip = "Tip", warning = "Warning", important = "Important", caution = "Caution", info = "Info", abstract = "Abstract", summary = "Summary", todo = "To do", question = "Question", example = "Example", quote = "Quote", success = "Success", failure = "Failure", danger = "Danger", bug = "Bug" }

--- Obsidian markdown as plain pandoc markdown.
function M.prepare(lines, entry, depth)
	depth = depth or 0
	local out, fence, comment = {}, nil, false
	local start = 1
	if lines[1] and lines[1]:match("^%-%-%-%s*$") then
		for i = 2, #lines do
			if lines[i]:match("^%-%-%-%s*$") then
				start = i + 1
				break
			end
		end
	end
	for i = start, #lines do
		local line = lines[i]
		local ticks = line:match("^%s*([`~][`~][`~]+)")
		if fence then
			if ticks and #ticks >= #fence and line:match("^%s*[`~]+%s*$") then
				fence = nil
				if comment == "block" then
					comment = false
					goto continue
				end
			end
			if not comment then
				out[#out + 1] = line
			end
			goto continue
		elseif ticks then
			fence = ticks
			local lang = line:match("^%s*[`~]+%s*(%w+)")
			if lang == "dataview" or lang == "tasks" then
				-- The results, as text
				local blocks = require("notes.blocks")
				for _, block in ipairs(blocks.find(lines)) do
					if block.first == i then
						out[#out + 1] = ""
						vim.list_extend(out, M.result(blocks.run(block, entry)))
						out[#out + 1] = ""
					end
				end
				comment = "block"
			else
				out[#out + 1] = line
			end
			goto continue
		end
		if line:match("^%%%%%s*$") then
			comment = not comment
			goto continue
		elseif comment then
			goto continue
		end
		line = line:gsub("%%%%.-%%%%", ""):gsub("<!%-%-SR:.-%-%->", "")
		line = line:gsub("%s+%^[%w%-]+%s*$", "")
		line = line:gsub("==([^=]+)==", "[%1]{.mark}")
		-- > [!note] Title
		local quote, kind, title = line:match("^(%s*>+%s*)%[!(%w+)%][+-]?%s*(.*)$")
		if kind then
			line = quote .. "**" .. (title ~= "" and title or CALLOUT[kind:lower()] or kind) .. "**"
			out[#out + 1] = line
			out[#out + 1] = quote
			goto continue
		end
		-- ![[embeds]]
		local whole = line:match("^%s*!%[%[([^%]]+)%]%]%s*$")
		local target = whole and (whole:match("^(.-)|") or whole)
		local path, anchor = (target or ""):match("^([^#]*)#?(.*)$")
		local other = target and index.resolve(path, entry)
		if other and depth < 3 and (other ~= entry or anchor ~= "") then
			local part = require("notes.hover").section(other, anchor)
			vim.list_extend(out, M.prepare(part, other, depth + 1))
			goto continue
		end
		line = line:gsub("!%[%[([^%]]+)%]%]", function(body)
			local file, size = body:match("^(.-)|(.*)$")
			file = file or body
			local rel = index.resolve_file(file, entry)
			if rel then
				local width = size and size:match("^(%d+)")
				return ("![](%s)%s"):format(vault.abs(rel):gsub(" ", "%%20"), width and ("{width=" .. width .. "px}") or "")
			end
			return file
		end)
		line = line:gsub("%[%[([^%]]+)%]%]", function(body)
			local to, label = body:match("^(.-)\\?|(.*)$")
			return label or (to or body):gsub("#", " › ")
		end)
		line = line:gsub("(!%[[^%]]*%]%()([^)]+)(%))", function(a, src, b)
			if not src:match("^%a+:") and not src:match("^/") then
				local rel = index.resolve_file((src:gsub("%%20", " ")), entry)
				if rel then
					return a .. vault.abs(rel):gsub(" ", "%%20") .. b
				end
			end
			return a .. src .. b
		end)
		line = line:gsub("`= ([^`]+)`", function(expr)
			return (require("notes.query.dql").inline(expr, entry)) or ""
		end)
		out[#out + 1] = line
		::continue::
	end
	return out
end

--- Query results as markdown.
function M.result(result)
	local X = require("notes.query.expr")
	if result.error then
		return { "*" .. result.error .. "*" }
	end
	local out = {}
	if result.type == "table" then
		local heads = vim.tbl_map(function(h)
			return h.name
		end, result.headers)
		out[1] = "| " .. table.concat(heads, " | ") .. " |"
		out[2] = "|" .. ("---|"):rep(#heads)
		for _, row in ipairs(result.rows) do
			out[#out + 1] = "| " .. table.concat(vim.tbl_map(function(v)
				return (util.plain(X.tostring(v)):gsub("|", "\\|"))
			end, row.cells), " | ") .. " |"
		end
	elseif result.type == "list" then
		for _, row in ipairs(result.rows) do
			out[#out + 1] = "- " .. table.concat(vim.tbl_map(X.tostring, row.cells), ": ")
		end
	else
		for _, group in ipairs(result.groups) do
			if group.name then
				vim.list_extend(out, { "", "**" .. group.name .. "**", "" })
			end
			for _, row in ipairs(group.tasks) do
				out[#out + 1] = ("- [%s] %s%s"):format(require("notes.tasks").is_done(row.task.status) and "x" or " ", util.plain(row.task.text), row.task.due and (" (" .. row.task.due .. ")") or "")
			end
		end
	end
	return out
end

local FORMATS = {
	{ name = "PDF", ext = "pdf", args = { "--pdf-engine=typst", "-V", "papersize=a4", "-V", "margin.x=2.2cm", "-V", "margin.y=2.2cm" } },
	{ name = "Word", ext = "docx" },
	{ name = "HTML (one file)", ext = "html", args = { "--embed-resources", "--standalone", "--mathml" } },
	{ name = "Slides (reveal.js)", ext = "html", suffix = " slides", args = { "-t", "revealjs", "--standalone", "-V", "revealjs-url=https://cdn.jsdelivr.net/npm/reveal.js@5.2.1" } },
	{ name = "LaTeX", ext = "tex", args = { "--standalone" } },
	{ name = "Typst", ext = "typ", args = { "--standalone" } },
	{ name = "EPUB", ext = "epub" },
	{ name = "Plain markdown", ext = "md", args = { "-t", "gfm" } },
}
M.formats = FORMATS

function M.run(format, callback)
	local entry = index.buffer()
	if not entry then
		return util.notify("Not in a note", "warn")
	end
	if vim.fn.executable("pandoc") == 0 then
		return util.notify("pandoc isn't installed", "error")
	end
	vim.cmd("silent! update")
	local lines = M.prepare(vim.api.nvim_buf_get_lines(0, 0, -1, false), entry)
	-- A level-one heading that repeats the title isn't needed twice.
	local title = entry.name
	for n, line in ipairs(lines) do
		if line:match("%S") then
			local h1 = line:match("^#%s+(.-)%s*$")
			if h1 then
				title = util.plain(h1)
				table.remove(lines, n)
			end
			break
		end
	end
	local out = vim.fs.joinpath(vault.folder("export"), entry.name .. (format.suffix or "") .. "." .. format.ext)
	vim.fn.mkdir(vim.fs.dirname(out), "p")
	local cmd = {
		"pandoc", "-f", "markdown+lists_without_preceding_blankline+hard_line_breaks+task_lists+pipe_tables+tex_math_dollars+wikilinks_title_after_pipe+mark-yaml_metadata_block",
		"-o", out, "--metadata", "title=" .. title, "--resource-path", vault.root() .. ":" .. vim.fs.dirname(entry.path),
	}
	local bib = entry.fm.bibliography
	if type(bib) == "string" then
		vim.list_extend(cmd, { "--citeproc", "--bibliography", vim.startswith(bib, "/") and bib or vault.abs(bib) })
	end
	vim.list_extend(cmd, format.args or {})
	util.notify("Exporting " .. format.name .. "…")
	vim.system(cmd, { text = true, stdin = table.concat(lines, "\n") .. "\n" }, vim.schedule_wrap(function(res)
		if callback then
			return callback(res, out)
		end
		if res.code ~= 0 then
			return util.notify(vim.trim(res.stderr), "error")
		end
		util.notify("Exported to " .. vault.rel(out))
		vim.ui.open(out)
	end))
end

function M.pick()
	vim.ui.select(FORMATS, {
		prompt = "Export as",
		format_item = function(f)
			return f.name
		end,
	}, function(format)
		if format then
			M.run(format)
		end
	end)
end

return M
