-- silver-fox (Dell XPS 15 9500) — per-device input overrides.
-- Shared input settings live in the common hypr/input.lua, required before this.

hl.config({
  input = {
    touchpad = {
      natural_scroll = true,
      clickfinger_behavior = true, -- two-finger = right click
    },
  },
})
