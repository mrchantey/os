#!/usr/bin/env bash
# silver-fox (Dell XPS 15 9500) system-level setup that needs root.
# Idempotent and safe to run anywhere: it no-ops on hardware without the
# Dell keyboard-backlight LED, so a stray call on another device does nothing.
#
# Run directly (`bash scripts/silver-fox/install.sh`) or via `just install-silver-fox`.
set -euo pipefail

# re-exec under sudo if we are not already root (single prompt for the whole script)
if [[ ${EUID} -ne 0 ]]; then
	exec sudo bash "$0" "$@"
fi

### keyboard backlight: stop the Dell driver from auto-dimming the keys.
# the dell-laptop driver dims the backlight after `stop_timeout` of no
# keyboard/touchpad input (ships at 10s). raise it so the keys stay lit while
# working. the firmware rejects long units (1d fails on this machine, 1h is
# accepted), so we use a minute-scale value.
#
# `start_triggers` controls what re-lights the keys once they've dimmed off.
# the driver restores the backlight to its prior brightness (full, since this
# machine sits at max), and this works the same on AC or battery. we force the
# `keyboard` trigger on so a keypress always wakes the backlight, rather than
# relying on the driver default surviving across kernel/firmware updates.
LED=/sys/class/leds/dell::kbd_backlight
KBD_TIMEOUT=1m
KBD_START_TRIGGER=+keyboard
RULE=/etc/udev/rules.d/99-kbd-backlight.rules

if [[ -e "${LED}/stop_timeout" ]]; then
	# persist: a udev rule re-applies both attrs whenever the LED device appears at boot
	tee "${RULE}" >/dev/null <<EOF
ACTION=="add", SUBSYSTEM=="leds", KERNEL=="dell::kbd_backlight", ATTR{stop_timeout}="${KBD_TIMEOUT}", ATTR{start_triggers}="${KBD_START_TRIGGER}"
EOF
	udevadm control --reload
	udevadm trigger -s leds
	# apply now to the running system too
	echo "${KBD_TIMEOUT}" > "${LED}/stop_timeout"
	echo "${KBD_START_TRIGGER}" > "${LED}/start_triggers"
	echo "kbd_backlight: stop_timeout = $(cat "${LED}/stop_timeout"), start_triggers = $(cat "${LED}/start_triggers")"
else
	echo "kbd_backlight: ${LED} not present, skipping (not a Dell laptop?)"
fi

echo "PASS install-silver-fox"
