-- Zotcite's picker is hardcoded to Telescope. Every picker in it (:Zseek, :Znote,
-- :Zannotations, citation insertion, ...) goes through seek.refs, so replacing
-- that one function moves all of them to Snacks.

local M = {}

local author_fields = {
  "author", "artist", "performer", "director", "composer", "sponsor", "contributor",
  "interviewee", "cartographer", "inventor", "podcaster", "presenter", "programmer",
  "recipient", "editor", "seriesEditor", "translator",
}

local publication_fields = {
  "publicationTitle", "bookTitle", "proceedingsTitle", "conferenceName", "programTitle",
  "blogTitle", "code", "dictionaryTitle", "encyclopediaTitle", "forumTitle",
  "websiteTitle", "seriesTitle",
}

local function first_field(ref, fields)
  for _, field in ipairs(fields) do
    if ref[field] then
      return ref[field]
    end
  end
end

-- The shape zotcite's callbacks expect as `selection.value`.
local function to_value(ref, sort_key)
  return {
    display = ref.alastnm .. " " .. ref.year .. " " .. ref.title,
    etype = ref.etype,
    sort_key = ref[sort_key] or "0000-00-00 0000",
    publicationTitle = first_field(ref, publication_fields),
    author = first_field(ref, author_fields),
    alastnm = ref.alastnm,
    year = ref.year,
    title = ref.title,
    abstract = ref.abstractNote,
    key = ref.zotkey,
    cite = ref.citekey,
  }
end

local function preview_lines(value)
  local names = {}
  for i, name in ipairs(value.author or {}) do
    if i > 5 then
      names[#names + 1] = "et al."
      break
    end
    names[#names + 1] = (name[1] or "") .. ", " .. (name[2] or "")
  end

  local lines = { "**" .. (value.title or "????") .. "**", "" }
  lines[#lines + 1] = table.concat(names, "; ") .. " (" .. (value.year or "????") .. ")"
  if value.publicationTitle then
    lines[#lines + 1] = "*" .. value.publicationTitle .. "*"
  end
  lines[#lines + 1] = ""
  vim.list_extend(lines, vim.split(value.abstract or "No abstract available.", "\n"))
  return lines
end

local function refs(key, cb)
  local config = require("zotcite.config").get_config()
  local pattern = (key or ""):gsub(" .*", "")
  local matches = require("zotcite.zotero").get_match(pattern, vim.api.nvim_buf_get_name(0))
  if #matches == 0 then
    vim.notify("No matches found.", vim.log.levels.INFO)
    return
  end

  local items = {}
  for _, ref in pairs(matches) do
    local value = to_value(ref, config.sort_key)
    items[#items + 1] = { text = value.display, value = value }
  end
  table.sort(items, function(a, b)
    return a.value.sort_key > b.value.sort_key
  end)

  Snacks.picker.pick({
    title = "Zotero references",
    items = items,
    format = function(item)
      return {
        { item.value.alastnm .. " ", "Identifier" },
        { item.value.year .. " ", "Number" },
        { item.value.title, "Title" },
      }
    end,
    preview = function(ctx)
      ctx.preview:reset()
      ctx.preview:set_lines(preview_lines(ctx.item.value))
      ctx.preview:highlight({ ft = "markdown" })
    end,
    confirm = function(picker, item)
      picker:close()
      if item then
        -- Wait for the picker to finish closing: it leaves insert mode, which
        -- would otherwise cancel zotcite putting you back in after a citation.
        vim.schedule(function()
          cb({ value = item.value })
        end)
      end
    end,
  })
end

function M.setup()
  require("zotcite.seek").refs = refs
end

return M
