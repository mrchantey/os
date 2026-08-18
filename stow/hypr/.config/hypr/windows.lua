-- Tile everything by default, then opt specific windows back into floating.
-- See https://wiki.hypr.land/Configuring/Basics/Window-Rules/
--
-- Background on rule precedence (this is why the opt-ins look the way they do):
-- `float`/`tile` are static effects where the LAST matching rule wins. But
-- Hyprland assigns tags before it can match on them, so every tag match is
-- effectively evaluated after every class/title match, regardless of file order.
-- Omarchy floats most apps via the `floating-window` tag, so a plain class rule
-- can never beat that. This module is required after Omarchy's defaults, so
-- within each pass our rules win.

-- ── Default: force every window to tile ──────────────────────────────────────
o.window(".*", { tile = true }) -- beats class/title floats (steam, calculator, localsend, screensaver, webcam overlay)
o.window({ tag = "floating-window" }, { tile = true }) -- beats the tag float (image viewer, mpv, password managers, file pickers)
o.window({ tag = "pip" }, { tile = true }) -- beats picture-in-picture

-- ── Opt-ins: windows allowed to float ────────────────────────────────────────
-- To let a window float, re-enable `float = true` AFTER the tile rules above, in
-- the SAME pass Omarchy used to float it:
--   * Floated by class (steam, omacalc, localsend, screensaver):
--       o.window("<class>", { float = true })
--   * Floated by the floating-window tag (file pickers, imv, mpv, 1Password,
--     Bitwarden): you MUST include the tag in the match or the tile rule wins:
--       o.window({ tag = "floating-window", class = "<class>" }, { float = true })
-- Centering/sizing come free from Omarchy's existing `floating-window` tag
-- rules, which only take effect once the window is floating again.

-- File picker / open-save dialogs:
o.window({
  tag = "floating-window",
  title = "^(Open.*Files?|Open [F|f]older.*|Save.*Files?|Save.*As|Save|All Files|.*wants to [open|save].*|[C|c]hoose.*)",
}, { float = true })

-- ── Misc ─────────────────────────────────────────────────────────────────────
-- Scroll faster in the terminal
o.window("(Alacritty|kitty)", { scroll_touchpad = 1.5 })
o.window("com.mitchellh.ghostty", { scroll_touchpad = 0.2 })
