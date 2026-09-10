-- silver-fox (Dell Precision 7560) — per-device input overrides.
-- Shared input settings live in the common hypr/input.lua, required before this.
--
-- This machine has a touchpad and NO pointing stick. Worth stating, because
-- `hyprctl devices` lists two mice for it and the second one looks like a
-- trackpoint at a glance:
--   dell0a69:00-0488:120a-touchpad
--   dell0a69:00-0488:120a-mouse
-- Same `dell0a69:00-0488:120a` HID device in both, i.e. one physical touchpad
-- that libinput also exposes through a plain pointer node. There is nothing on
-- the -mouse node to configure separately.
--
-- `input.touchpad` below reaches the touchpad node only.

hl.config({
  input = {
    touchpad = {
      natural_scroll = true,
      clickfinger_behavior = true, -- two-finger = right click
    },
  },
})
