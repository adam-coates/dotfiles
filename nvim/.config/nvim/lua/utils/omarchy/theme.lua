-- Omarchy theme integration for vim.pack.
--
-- Omarchy writes a lazy.nvim-shaped spec to ~/.local/state/omarchy/current/theme.
-- We read that file, install the theme with vim.pack, and apply it ourselves.

local M = {}

M.spec_file = vim.env.HOME .. "/.local/state/omarchy/current/theme/neovim.lua"
M.name_file = vim.env.HOME .. "/.local/state/omarchy/current/theme.name"
M.colors_file = vim.env.HOME .. "/.local/state/omarchy/current/theme/colors.toml"

-- "light" or "dark", from the mode Omarchy gives the theme. Colorschemes that
-- support both read vim.o.background, and aether doesn't set it at all.
local function mode()
  if vim.fn.filereadable(M.colors_file) == 1 then
    for _, line in ipairs(vim.fn.readfile(M.colors_file)) do
      local value = line:match('^%s*mode%s*=%s*"(%a+)"')
      if value then
        return value == "light" and "light" or "dark"
      end
    end
  end
  return "dark"
end
M.transparency = vim.fn.stdpath("config") .. "/lua/utils/omarchy/transparency.lua"

-- Keep aether's file watcher from starting: the theme-set hook handles every
-- switch, and the watcher would replace an override with the staged aether spec.
-- Aether has no option for this, but skips its setup when this flag is set.
_G.__aether_hotreload_state = { did_setup = true, fs_event_handles = {}, pending_reload_timers = {} }

-- On every ColorScheme, not once, so it applies however the theme got loaded.
vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("OmarchyTransparency", { clear = true }),
  callback = function()
    pcall(dofile, M.transparency)
  end,
})

local function read()
  local names = vim.uv.fs_stat(M.name_file) and vim.fn.readfile(M.name_file, "", 1) or {}
  local override = require("utils.omarchy.overrides")[names[1]]
  if override then
    return { plugins = { override.plugin }, colorscheme = override.colorscheme }
  end

  local out = { plugins = {} }

  local chunk = loadfile(M.spec_file)
  if not chunk then
    return out
  end
  local ok, theme = pcall(chunk)
  if not ok or type(theme) ~= "table" then
    return out
  end

  -- A theme may return a single spec or a list of them.
  if type(theme[1]) == "string" then
    theme = { theme }
  end

  for _, spec in ipairs(theme) do
    if type(spec) == "table" and type(spec[1]) == "string" then
      if spec[1] == "LazyVim/LazyVim" then
        -- Anything besides `colorscheme` is meant for the theme's setup().
        out.setup_opts = vim.deepcopy(spec.opts or {})
        out.colorscheme = out.setup_opts.colorscheme
        out.setup_opts.colorscheme = nil
      elseif spec.enabled ~= false then
        out.plugins[#out.plugins + 1] = spec
      end
    end
  end

  return out
end

local function pack_spec(spec)
  local pack = {
    src = spec[1]:find("://", 1, true) and spec[1] or ("https://github.com/" .. spec[1]),
    name = spec.name or spec[1]:match("[^/]+$"):gsub("%.git$", ""),
    version = spec.branch or spec.tag or spec.commit,
  }

  -- Themes disagree on where aether lives (omacom/ vs bjarneo/). vim.pack deletes
  -- and re-clones when src changes, so keep whichever copy is already installed.
  for _, plugin in ipairs(vim.pack.get()) do
    if plugin.spec.name == pack.name then
      pack.src = plugin.spec.src
    end
  end

  return pack
end

-- Drop the theme's Lua modules so its palette is rebuilt from the new opts.
-- Two themes often share one plugin (everything aether-based).
local function forget_modules(path)
  local lua_dir = path .. "/lua"
  for file, kind in vim.fs.dir(lua_dir, { depth = 10 }) do
    if kind == "file" and file:match("%.lua$") then
      local mod = file:gsub("%.lua$", ""):gsub("/init$", ""):gsub("/", ".")
      package.loaded[mod] = nil
    end
  end
end

local function find_setup(name, path)
  local base = name:gsub("%.nvim$", ""):gsub("%-nvim$", ""):gsub("%-neovim$", "")
  for _, mod_name in ipairs({ base, name }) do
    local file = path .. "/lua/" .. mod_name:gsub("%.", "/")
    if vim.uv.fs_stat(file .. ".lua") or vim.uv.fs_stat(file .. "/init.lua") then
      local ok, mod = pcall(require, mod_name)
      if ok and type(mod) == "table" and type(mod.setup) == "function" then
        return mod
      end
    end
  end
end

local function configure(spec, theme)
  local pack = pack_spec(spec)
  vim.pack.add({ pack }, { confirm = false, load = true })
  local path = vim.pack.get({ pack.name })[1].path
  forget_modules(path)

  if spec.init then
    spec.init()
  end

  local opts = vim.tbl_deep_extend("force", theme.setup_opts or {}, spec.opts or {})
  if spec.config then
    spec.config(nil, opts)
  elseif not vim.tbl_isempty(opts) then
    local mod = find_setup(pack.name, path)
    if mod then
      pcall(mod.setup, opts)
    end
  end
end

local function apply()
  vim.o.background = mode()
  local theme = read()
  for _, spec in ipairs(theme.plugins) do
    local ok, err = pcall(configure, spec, theme)
    if not ok then
      vim.notify("omarchy: " .. tostring(err), vim.log.levels.WARN)
    end
  end

  if theme.colorscheme then
    pcall(vim.cmd.colorscheme, theme.colorscheme)
  end
end

function M.load()
  apply()
end

--- Called by the Omarchy theme-set hook and by :OmarchyThemeReload.
function M.reload()
  vim.schedule(function()
    -- A colorscheme only overwrites the groups it defines.
    vim.cmd("highlight clear")
    if vim.fn.exists("syntax_on") == 1 then
      vim.cmd("syntax reset")
    end
    apply()
    vim.cmd("redraw!")
  end)

  -- --remote-expr wants a value back.
  return ""
end

vim.api.nvim_create_user_command("OmarchyThemeReload", function()
  M.reload()
end, { desc = "Re-apply the current Omarchy theme", force = true })

-- The Omarchy theme-set hook calls require'omarchy.theme'.reload() in every
-- running Neovim, including the old config, so keep answering to that name.
package.loaded["omarchy.theme"] = M

return M
