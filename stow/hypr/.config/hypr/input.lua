-- Shared input config across all devices.
-- Per-device overrides (left_handed, touchpad gestures, etc.) live in each
-- device package's input-device.lua, required AFTER this file so they win.
-- See https://wiki.hypr.land/Configuring/Basics/Variables/#input
--
-- Dropped in the quattro port because Omarchy now sets them by default:
-- cursor.hide_on_key_press and misc.focus_on_activate (default/hypr/looknfeel.lua).

hl.config({
  input = {
    kb_layout = "us",
    kb_options = "compose:caps", -- ,grp:alts_toggle for layout switching

    -- Keyboard repeat
    repeat_rate = 40,
    repeat_delay = 600,

    touchpad = {
      -- Scroll speed (shared); per-device gestures live in input-device.lua
      scroll_factor = 0.4,
    },
  },

  misc = {
    mouse_move_focuses_monitor = false,
  },
})

-- Kensington Orbit trackball: halve pointer movement (400 DPI feels like 200).
-- flat profile = constant factor, no acceleration (a velocity-based custom curve
-- made the pointer jump on the first move). With flat, the factor is
-- 1 + sensitivity, so -0.7 slows it well below half speed.
-- One block per connection type (USB dongle vs Bluetooth); only the block
-- matching the connected device applies, so both are harmless everywhere.
-- left_handed = true swaps the primary/secondary buttons for left-handed use.

-- USB dongle
hl.device({
  name = "kensington-orbit-wireless-tb-mouse",
  accel_profile = "flat",
  sensitivity = -0.7,
  left_handed = true,
})

-- Bluetooth
hl.device({
  name = "orbit-bt5.0-mouse",
  accel_profile = "flat",
  sensitivity = -0.7,
  left_handed = true,
})
