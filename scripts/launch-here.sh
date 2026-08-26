#!/bin/bash
# Keep a single-instance app's window on the CURRENT Hyprland workspace.
#
#   launch-here <class-regex> <new-window-flag> <command> [args...]
#
# Single-instance apps (Chrome, Zed, Nautilus, Element) hand a second invocation
# to the already-running process over an IPC socket instead of starting a new
# one. That process then places the payload -- a URL, a file, a folder -- in
# whichever of its windows was activated last, which is routinely on a workspace
# you cannot see. Hyprland cannot fix this: no window is created, so there is no
# event for a window rule to match on. It has to be handled at the launch site.
#
# So: focus a matching window on the active workspace first, making it the one
# the app considers last-activated, then hand the payload over. With no matching
# window here, fall back to <new-window-flag> so a fresh window opens on this
# workspace rather than joining a window elsewhere.
#
# <class-regex> matches against .class then .initialClass, the same two fields
# omarchy-hyprland-focus-app checks. Anchor it: `^google-chrome$` deliberately
# excludes Chrome PWA windows, whose class is `chrome-<appid>-Default`.
#
# Callers:
#   stow/mimeapps/.local/share/applications/google-chrome.desktop  (link clicks)

set -euo pipefail

if [[ $# -lt 3 ]]; then
  echo "usage: launch-here <class-regex> <new-window-flag> <command> [args...]" >&2
  exit 2
fi

class_re=$1
new_flag=$2
shift 2

# Only steer when there is a payload to place. A bare flag invocation (--help,
# --version, --incognito from omarchy-launch-browser) is somebody else's intent,
# and an app with nothing to open has nothing to misplace.
has_payload=false
for arg in "${@:2}"; do
  [[ $arg == -* ]] || has_payload=true
done

if [[ $has_payload == false || -z ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
  exec uwsm-app -- "$@"
fi

ws=$(hyprctl activeworkspace -j | jq -r '.id')

# Most recently focused match on this workspace. focusHistoryID counts up from
# 0 = currently focused, so the lowest is the freshest.
target=$(hyprctl clients -j | jq -r --argjson ws "$ws" --arg re "$class_re" '
  def matches($v): ($v // "") | test($re);
  [ .[]
    | select(.workspace.id == $ws)
    | select(matches(.class) or matches(.initialClass))
  ]
  | sort_by(.focusHistoryID) | .[0].address // empty
')

if [[ -z $target ]]; then
  cmd=$1; shift
  exec uwsm-app -- "$cmd" "$new_flag" "$@"
fi

active() { hyprctl activewindow -j | jq -r '.address // empty'; }

if [[ $(active) != "$target" ]]; then
  # Quattro's dispatcher speaks Lua; the bare-word form is the pre-Lua fallback,
  # kept for the same reason omarchy-hyprland-focus-app keeps it.
  hyprctl dispatch "hl.dsp.focus({ window = \"address:$target\" })" >/dev/null 2>&1 ||
    hyprctl dispatch focuswindow "address:$target" >/dev/null
  # The app learns it was activated over the Wayland protocol, asynchronously,
  # so let the activation land before racing it with the payload.
  for _ in {1..30}; do
    [[ $(active) == "$target" ]] && break
    sleep 0.01
  done
  sleep 0.05
fi

exec uwsm-app -- "$@"
