-- Omarchy theme integration for a plain lazy.nvim config (no LazyVim).
--
-- Omarchy stages the active theme under ~/.local/state/omarchy/current/theme and
-- writes a Neovim plugin spec there as neovim.lua. That spec is written for
-- LazyVim: the colorscheme plugin, plus a second `LazyVim/LazyVim` entry whose
-- opts.colorscheme names the scheme to apply. Symlinking it straight into
-- lua/plugins makes lazy install LazyVim itself, which then half-boots inside a
-- config that never asked for it. So we read the file instead: keep the theme
-- plugin, drop the LazyVim entry, and apply its colorscheme ourselves.

local M = {}

M.state = vim.env.HOME .. "/.local/state/omarchy/current/theme"
M.spec_file = M.state .. "/neovim.lua"
M.transparency = vim.fn.stdpath("config") .. "/lua/plugins/after/transparency.lua"

-- The name lazy.nvim will give a spec, so we can find the plugin again later.
local function plugin_name(spec)
  if spec.name then
    return spec.name
  end
  local ok, Plugin = pcall(require, "lazy.core.plugin")
  if ok and Plugin.Spec and Plugin.Spec.get_name then
    return Plugin.Spec.get_name(spec[1])
  end
  return (spec[1]:match("[^/]+$"):gsub("%.git$", ""))
end

--- Read the staged theme.
---@return { specs: table[], name: string?, colorscheme: string? }
function M.read()
  local out = { specs = {} }

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
        -- Besides `colorscheme`, this spec can carry options meant for the
        -- theme plugin's own setup() -- everforest is set up with
        -- background = "soft" this way. Keep them; dropping them renders the
        -- theme at its plugin defaults instead of the way Omarchy intends.
        for key, value in pairs(spec.opts or {}) do
          if key == "colorscheme" then
            out.colorscheme = value
          else
            out.setup_opts = out.setup_opts or {}
            out.setup_opts[key] = value
          end
        end
      else
        out.specs[#out.specs + 1] = spec
        out.name = out.name or plugin_name(spec)
      end
    end
  end

  return out
end

-- lazy's get_main() guesses a plugin's setup module from the Lua modules in its
-- directory, and gives up when there is more than one and none matches the
-- plugin name exactly. neanias/everforest-nvim ships `everforest` and `lualine`,
-- and lazy normalises "everforest-nvim" to "everforestnvim", so it returns nil
-- and the theme is never set up -- everforest renders at its plugin default
-- instead of the `background = "soft"` Omarchy asks for. Guess from the name
-- ourselves, and confirm the module is really there before requiring it.
local function setup_module(plugin)
  local candidates = {}
  if plugin.main then
    candidates[#candidates + 1] = plugin.main
  end
  candidates[#candidates + 1] = (plugin.name:gsub("%.nvim$", ""):gsub("%-nvim$", ""))
  candidates[#candidates + 1] = plugin.name

  for _, name in ipairs(candidates) do
    local base = plugin.dir .. "/lua/" .. name:gsub("%.", "/")
    if vim.uv.fs_stat(base .. ".lua") or vim.uv.fs_stat(base .. "/init.lua") then
      local ok, mod = pcall(require, name)
      if ok and type(mod) == "table" and type(mod.setup) == "function" then
        return mod
      end
    end
  end

  -- Last resort: let lazy guess.
  local main = require("lazy.core.loader").get_main(plugin)
  if main then
    local ok, mod = pcall(require, main)
    if ok and type(mod) == "table" and type(mod.setup) == "function" then
      return mod
    end
  end
end

function M.transparent()
  if vim.fn.filereadable(M.transparency) == 1 then
    pcall(vim.cmd.source, M.transparency)
  end
end

function M.apply(colorscheme)
  if colorscheme then
    pcall(vim.cmd.colorscheme, colorscheme)
  end
  M.transparent()
end

--- The lazy.nvim spec for the current theme. Called from lua/plugins/theme.lua,
--- which lazy re-runs with `loadfile` on every reload, so this re-reads the
--- staged theme each time.
function M.spec()
  local theme = M.read()
  M.current = theme

  for _, spec in ipairs(theme.specs) do
    spec.lazy = false
    spec.priority = spec.priority or 1000

    -- A theme written by hand in ~/.config/omarchy/themes may ship its own
    -- `config` that already calls :colorscheme. Only the LazyVim-shaped ones
    -- need one synthesised.
    if theme.colorscheme and not spec.config then
      spec.config = function(plugin, opts)
        -- The theme plugin's own opts win over the ones carried on the
        -- LazyVim spec, which are only ever a handful of top-level keys.
        opts = vim.tbl_deep_extend("force", theme.setup_opts or {}, type(opts) == "table" and opts or {})
        if not vim.tbl_isempty(opts) then
          local mod = setup_module(plugin)
          if mod then
            pcall(mod.setup, opts)
          end
        end
        M.apply(theme.colorscheme)
      end
    end
  end

  return theme.specs
end

--- Re-read the staged theme and apply it to this running instance.
--- Called by the omarchy theme-set hook and by :OmarchyThemeReload.
function M.reload()
  vim.schedule(function()
    local Config = require("lazy.core.config")
    local Loader = require("lazy.core.loader")

    -- Re-import every spec module. lazy loads spec files with `loadfile`, so
    -- lua/plugins/theme.lua runs again and M.spec() picks up the new theme.
    require("lazy.core.plugin").load()

    local theme = M.current or M.read()
    local plugin = theme.name and Config.plugins[theme.name]
    if not plugin then
      vim.notify("omarchy: no plugin for the staged theme", vim.log.levels.WARN)
      return
    end

    -- A colorscheme only overwrites the groups it defines, so anything the
    -- previous one set and this one does not would otherwise survive.
    vim.cmd("highlight clear")
    if vim.fn.exists("syntax_on") == 1 then
      vim.cmd("syntax reset")
    end
    -- Light themes set this themselves once the colorscheme loads.
    vim.o.background = "dark"

    if not vim.uv.fs_stat(plugin.dir) then
      pcall(function()
        require("lazy").install({ show = false, wait = true })
      end)
      plugin = Config.plugins[theme.name] or plugin
    end

    -- Drop the theme's Lua modules so its palette is rebuilt from the new opts.
    -- Two Omarchy themes often share one plugin (everything aether-based, both
    -- catppuccin flavours), and without this the cached palette wins.
    pcall(function()
      require("lazy.core.util").walkmods(plugin.dir .. "/lua", function(modname)
        package.loaded[modname] = nil
        package.preload[modname] = nil
      end)
    end)

    -- Loader.reload() deactivates the plugin first, and deactivating requires
    -- the plugin's "main" module -- a name lazy guesses from the Lua modules in
    -- the plugin directory. A colorscheme often ships nothing under lua/ but a
    -- lualine theme (sainnhe/gruvbox-material is all Vimscript apart from
    -- lua/lualine/themes/), so lazy guesses "lualine", the require fails, and it
    -- reports the failure. A colorscheme has no state to deactivate, so do the
    -- two parts that matter -- drop the handlers and the resolved-property cache
    -- -- and let reload() skip deactivation entirely.
    require("lazy.core.handler").disable(plugin)
    plugin._.loaded = nil
    plugin._.cache = nil

    -- reload() re-runs init and config, which is what re-applies setup() with
    -- the new opts when the plugin was already loaded. Our specs set
    -- lazy = false, so it still loads despite the cleared loaded flag.
    Loader.reload(plugin)

    -- Themes carrying their own `config` applied the colorscheme in reload().
    M.apply(theme.colorscheme)

    -- Kick plugins that register highlights in response to ColorScheme or
    -- VimEnter (gitsigns, nvim-tree, telescope, render-markdown, lualine…).
    -- vim.cmd.colorscheme already fires ColorScheme, but transparency
    -- overwrites some groups afterward; a second event lets plugins settle.
    vim.api.nvim_exec_autocmds("ColorScheme", { modeline = false })
    vim.api.nvim_exec_autocmds("VimEnter", { modeline = false })
    vim.cmd("redraw!")
  end)

  -- --remote-expr wants a value back.
  return ""
end

pcall(vim.api.nvim_create_user_command, "OmarchyThemeReload", function()
  M.reload()
end, { desc = "Re-apply the current Omarchy theme" })

return M
