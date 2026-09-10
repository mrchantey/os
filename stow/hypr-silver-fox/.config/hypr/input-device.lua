-- silver-fox (Dell Precision 7560) — per-device input overrides.
-- Shared input settings live in the common hypr/input.lua, required before this.
--
-- This machine has TWO built-in pointers, both on the same i2c HID device, which
-- `hyprctl devices` shows as:
--   dell0a69:00-0488:120a-touchpad   the touchpad
--   dell0a69:00-0488:120a-mouse      the trackpoint (the XPS had none)
-- `input.touchpad` below reaches only the touchpad; the trackpoint is a plain
-- pointer and takes its settings from `input` or from an hl.device block.

hl.config({
  input = {
    touchpad = {
      natural_scroll = true,
      clickfinger_behavior = true, -- two-finger = right click
    },
  },
})

-- Trackpoint. Left at libinput defaults until it has been used in anger -- the
-- right sensitivity is a feel judgement, not something to guess from the specs.
-- Uncomment and tune if it is too slow or too twitchy; as with the trackball in
-- input.lua, `flat` makes sensitivity a constant factor (1 + sensitivity) with no
-- acceleration curve.
--
-- hl.device({
--   name = "dell0a69:00-0488:120a-mouse",
--   accel_profile = "flat",
--   sensitivity = 0.3,
-- })
--
-- The three physical buttons above the touchpad are the trackpoint's. To get
-- ThinkPad-style press-middle-and-push-to-scroll, add to the block above:
--   scroll_method = "on_button_down",
--   scroll_button = 274,            -- BTN_MIDDLE
-- Note that this costs you middle-click paste on that button.
