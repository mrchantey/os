#!/bin/bash
# Presentation mode toggle — a clean, chromeless desktop for demos.
#
# This is the *visual* presentation mode (distinct from `present`, the
# step-through demo driver). It strips the desktop chrome so pre-set
# workspaces (ghostty, zed, browser, ...) read edge-to-edge on a projector:
#   - hides the blue active-window border
#   - zeroes gaps and rounding
#   - hides waybar
#
# It applies globally, so switching between your pre-set workspaces keeps the
# clean look. Toggle with SUPER ALT SHIFT P.
#
# Enter uses runtime `hyprctl keyword` overrides; exit restores every
# config-defined value with a single `hyprctl reload`.

STATE="${XDG_STATE_HOME:-$HOME/.local/state}/presentation-mode"

notify() {
  command -v notify-send >/dev/null 2>&1 && notify-send -u low -t 2000 "Presentation mode" "$1" || true
}

if [[ -f "$STATE" ]]; then
  # --- exit ---
  rm -f "$STATE"
  hyprctl reload >/dev/null 2>&1   # restore border/gaps/rounding from config
  pgrep -x waybar >/dev/null || setsid uwsm-app -- waybar >/dev/null 2>&1 &
  notify "off"
else
  # --- enter ---
  mkdir -p "$(dirname "$STATE")"
  touch "$STATE"
  hyprctl --batch "keyword general:border_size 0; keyword general:gaps_in 0; keyword general:gaps_out 0; keyword decoration:rounding 0" >/dev/null 2>&1
  pkill -x waybar
  notify "on"
fi
