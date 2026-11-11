-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- List current monitors and supported resolutions with: hyprctl monitors all
--
-- These dotfiles are shared between machines. Rules match on the output
-- (connector) name, so each one only applies where that output exists:
--   eDP-1         MacBook Air M2 built-in display (Asahi)
--   DP-* / HDMI-* desktop at home (DP) and in the office (HDMI), via the
--                 catch-all rule

local omarchy_gdk_scale = 2
local omarchy_monitor_scale = 1.6

hl.env("GDK_SCALE", tostring(omarchy_gdk_scale))

-- Desktop (DP at home, HDMI in the office) and any other external monitor.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = omarchy_monitor_scale })

-- MacBook built-in display. Lower the scale to fit more, raise it to make everything bigger.
hl.monitor({ output = "eDP-1", mode = "preferred", position = "auto", scale = 2 })

-- Configure a specific monitor.
-- hl.monitor({ output = "DP-2", mode = "2560x1440@144", position = "0x0", scale = 1 })

-- Portrait/rotated secondary monitor (transform: 1 = 90°, 3 = 270°).
-- hl.monitor({ output = "DP-2", mode = "preferred", position = "auto", scale = 1, transform = 1 })
