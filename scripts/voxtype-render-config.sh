#!/usr/bin/env bash
# Render voxtype's runtime config from the shared, stow-managed config.toml, adding
# gpu_isolation only when on battery. gpu_isolation runs each clip in a short-lived
# worker that releases the dGPU between uses so it can suspend (saves laptop battery)
# at the cost of a ~1.7s spin-up that swallows the start of short push-to-talk clips.
# On AC — or a desktop with no AC adapter — keep the model warm for instant capture.
#
# Detection keys off a type=Mains adapter being offline, NOT "a battery exists":
# wireless peripherals (mouse/keyboard) also report as type=Battery, and desktops
# have no Mains adapter at all, so both correctly resolve to "not on battery".
#
# Run as voxtype.service's ExecStartPre; the daemon reads the result via -c, so the
# choice is made each time the daemon starts (login, or `just restart-voxtype`).
set -euo pipefail

src="${HOME}/.config/voxtype/config.toml"
dst="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/voxtype/config.toml"
mkdir -p "$(dirname "$dst")"

on_battery=0
for ps in /sys/class/power_supply/*; do
	[ -r "$ps/type" ] || continue
	[ "$(cat "$ps/type")" = "Mains" ] || continue
	[ -r "$ps/online" ] || continue
	[ "$(cat "$ps/online")" = "0" ] && on_battery=1
done

if [ "$on_battery" = "1" ]; then
	awk '
		/^[[:space:]]*gpu_isolation[[:space:]]*=/ { next }
		{ print }
		/^\[whisper\]/ { print "gpu_isolation = true" }
	' "$src" >"$dst"
else
	grep -v '^[[:space:]]*gpu_isolation[[:space:]]*=' "$src" >"$dst"
fi
