#!/bin/bash
# Presentation mode toggle — a clean, chromeless desktop for demos.
#
# This is the *visual* presentation mode (distinct from `present`, the
# step-through demo driver). It strips the desktop chrome so pre-set
# workspaces (ghostty, zed, browser, ...) read edge-to-edge on a projector:
#   - hides the blue active-window border
#   - zeroes gaps and rounding
#   - hides the Omarchy bar
#
# It applies globally, so switching between your pre-set workspaces keeps the
# clean look. Toggle with SUPER ALT SHIFT P.
#
# Enter uses runtime `hyprctl eval` overrides; exit restores every
# config-defined value with a single `hyprctl reload`.
# (quattro removed `hyprctl keyword` -- it "can't work with non-legacy parsers"
# now that Hyprland is configured in Lua. `eval` runs a Lua snippet instead.)
#
# The bar is part of the long-running Omarchy shell (Quickshell) since quattro,
# so it is hidden by flag rather than by killing a process the way waybar was.
# Presence of the `bar-off` flag = bar hidden; the shell watches the toggles dir.
# Set the flag directly: `omarchy toggle bar on|off` toggles the *flag*, so its
# on/off reads backwards relative to bar visibility.

STATE="${XDG_STATE_HOME:-$HOME/.local/state}/presentation-mode"

notify() {
  command -v notify-send >/dev/null 2>&1 && notify-send -u low -t 2000 "Presentation mode" "$1" || true
}

if [[ -f "$STATE" ]]; then
  # --- exit ---
  rm -f "$STATE"
  hyprctl reload >/dev/null 2>&1   # restore border/gaps/rounding from config
  omarchy-toggle bar-off off       # show the bar again
  notify "off"
else
  # --- enter ---
  mkdir -p "$(dirname "$STATE")"
  touch "$STATE"
  hyprctl eval "hl.config({ general = { border_size = 0, gaps_in = 0, gaps_out = 0 }, decoration = { rounding = 0 } })" >/dev/null 2>&1
  omarchy-toggle bar-off on        # hide the bar
  notify "on"
fi
