-- The active Omarchy theme, read from ~/.local/state/omarchy/current/theme.
-- lazy.nvim re-runs this file with `loadfile` on every reload, so switching
-- themes with `omarchy theme set` is picked up here. See lua/omarchy/theme.lua.
return require("omarchy.theme").spec()
