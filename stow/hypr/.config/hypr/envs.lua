-- Environment overrides on top of default/hypr/envs.lua.
-- Shared across all devices. https://wiki.hypr.land/Configuring/Environment-variables/

-- Never-Lost Rainbow cursors, converted from the Windows .ani set in
-- ~/me/os/neverlost and installed by `just install-cursor-theme`.
--
-- The `cursor-off` flag is written by `cursor-toggle`; reading it here (rather
-- than only calling hyprctl setcursor in the toggle) is what makes the choice
-- survive a reload or a relogin. Both branches assign every variable, because
-- `hyprctl reload` can overwrite an env var but never unsets one -- leaving the
-- off branch blank would strand the theme on newly launched apps.
--
-- Keep these values in step with scripts/cursor-toggle.sh, which applies the
-- same pair at runtime via setcursor and gsettings.
local state = os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")
local off = io.open(state .. "/cursor-off", "r")

-- 32 is the artwork's native pixel size, so it renders without resampling -- and
-- being hard to lose is the whole point of the set. Omarchy defaults both sizes
-- to 24 (default/hypr/envs.lua); re-setting them here wins because this module
-- loads after it. Off falls back to the system default theme at that same 24.
local theme, size = "Never-Lost-Rainbow", "32"
if off then
  off:close()
  theme, size = "Adwaita", "24"
end

-- HYPRCURSOR_THEME is deliberately unset: there is no hyprcursor build of this
-- theme, and Hyprland falls back to the XCursor one.
hl.env("XCURSOR_THEME", theme)
hl.env("XCURSOR_SIZE", size)
hl.env("HYPRCURSOR_SIZE", size)
