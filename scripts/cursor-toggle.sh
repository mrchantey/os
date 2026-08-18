#!/bin/bash

# Toggle the Never-Lost Rainbow cursor on and off.
#   cursor-toggle          flip it
#   cursor-toggle on|off   force a state (idempotent; what `just install-cursor-theme` calls)
#
# Off falls back to the system default (/usr/share/icons/default -> Adwaita) at
# Omarchy's default size of 24. See neverlost/readme.md.
#
# Presence of the flag file = rainbow cursor OFF, matching the `bar-off` naming
# Omarchy uses for its own toggles. hypr/envs.lua reads the same flag, so the
# choice survives a reload or a relogin instead of only lasting the session.

set -u

STATE="${XDG_STATE_HOME:-$HOME/.local/state}/cursor-off"

THEME="Never-Lost-Rainbow"
THEME_SIZE=32
FALLBACK="Adwaita"
FALLBACK_SIZE=24

case "${1:-toggle}" in
  on) want=on ;;
  off) want=off ;;
  toggle) [[ -f "$STATE" ]] && want=on || want=off ;;
  *) echo "usage: cursor-toggle [on|off]" >&2; exit 2 ;;
esac

if [[ $want == on ]]; then
  rm -f "$STATE"
  theme=$THEME size=$THEME_SIZE
else
  mkdir -p "$(dirname "$STATE")"
  touch "$STATE"
  theme=$FALLBACK size=$FALLBACK_SIZE
fi

# Re-run hypr/envs.lua against the flag we just wrote, so apps launched from here
# on inherit the matching XCURSOR_THEME. No-op outside a Hyprland session.
hyprctl reload >/dev/null 2>&1 || true

# setcursor covers the compositor and, through it, XWayland; GTK apps read
# gsettings instead. Already-running apps that read XCURSOR_THEME at startup keep
# the old cursor until they restart.
hyprctl setcursor "$theme" "$size" >/dev/null 2>&1 || true
if command -v gsettings >/dev/null 2>&1; then
  gsettings set org.gnome.desktop.interface cursor-theme "$theme" || true
  gsettings set org.gnome.desktop.interface cursor-size "$size" || true
fi

command -v notify-send >/dev/null 2>&1 &&
  notify-send -u low -t 2000 "Rainbow cursor" "$want" || true

echo "rainbow cursor $want ($theme, size $size)"
