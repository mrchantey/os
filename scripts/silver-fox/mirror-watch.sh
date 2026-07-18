#!/bin/bash
# Watch Hyprland monitor hotplug events and drive clean 16:9 1080p presentation
# mirroring (see present-mirror): external connected -> clean mirror, external
# removed -> restore the internal panel. Launched once from this directory's
# startup.sh; uses the same socket2 event stream as omarchy's own monitor watcher.
#
# The present-mirror on/off handlers are idempotent, so the paired legacy + v2
# events Hyprland emits for a single hotplug are harmless.

HERE="$(dirname "$(readlink -f "$0")")"
SOCKET="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"

command -v socat >/dev/null 2>&1 || exit 0
[[ -S "$SOCKET" ]] || exit 0

socat -U - "UNIX-CONNECT:$SOCKET" | while read -r line; do
  case "$line" in
    monitoradded\>\>*|monitoraddedv2\>\>*)
      sleep 0.4  # let Hyprland register the new output and its modes first
      "$HERE/present-mirror" on
      ;;
    monitorremoved\>\>*|monitorremovedv2\>\>*)
      "$HERE/present-mirror" off
      ;;
  esac
done
