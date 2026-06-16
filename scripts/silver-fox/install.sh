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
KBD_TIMEOUT=10m
KBD_START_TRIGGER=+keyboard
RULE=/etc/udev/rules.d/99-kbd-backlight.rules

if [[ -e "${LED}/stop_timeout" ]]; then
	# persist: a udev rule re-applies both attrs whenever the LED device appears at boot
	tee "${RULE}" >/dev/null <<EOF
ACTION=="add", SUBSYSTEM=="leds", KERNEL=="dell::kbd_backlight", ATTR{stop_timeout}="${KBD_TIMEOUT}", ATTR{start_triggers}="${KBD_START_TRIGGER}"
EOF
	udevadm control --reload
	udevadm trigger -s leds
	# apply now to the running system too. these are best-effort: the udev rule
	# above is the source of truth (re-applied at every boot), and the Dell
	# firmware sometimes rejects (EINVAL) re-asserting an already-active value,
	# so a failed live write must not abort the rest of device setup.
	echo "${KBD_TIMEOUT}" > "${LED}/stop_timeout" || echo "kbd_backlight: live stop_timeout write rejected (udev rule still persists it)"
	echo "${KBD_START_TRIGGER}" > "${LED}/start_triggers" || echo "kbd_backlight: live start_triggers write rejected (udev rule still persists it)"
	echo "kbd_backlight: stop_timeout = $(cat "${LED}/stop_timeout"), start_triggers = $(cat "${LED}/start_triggers")"
else
	echo "kbd_backlight: ${LED} not present, skipping (not a Dell laptop?)"
fi

### suspend mode: force S3 deep sleep instead of s2idle (modern standby).
# this machine reliably hard-resets on resume from sleep (Dell bootloader
# reappears, journal logs an unclean shutdown on the next boot). the crash hits
# at the GPU/ACPI power-state handover on resume (NVRM "Failed to handle ACPI
# D-Notifier event" right before death) and s2idle's never-fully-powered-down
# path is the suspected aggravator. the firmware exposes real S3 (deep appears
# in /sys/power/mem_sleep), so selecting it gives a full power-down/re-init on
# suspend, which is both the candidate fix and generally easier on sleep-time
# battery drain than modern standby.
#
# persisted via tmpfiles.d (written every boot by systemd-tmpfiles-setup, well
# before any suspend) rather than a kernel cmdline param, so it survives
# kernel/omarchy updates with no bootloader or UKI regeneration.
SLEEP_TMPFILES=/etc/tmpfiles.d/silver-fox-deep-sleep.conf

if grep -qw deep /sys/power/mem_sleep 2>/dev/null; then
	tee "${SLEEP_TMPFILES}" >/dev/null <<'EOF'
# force S3 deep sleep over s2idle — fixes hard-reset on resume (silver-fox)
#Type Path                 Mode UID GID Age Argument
w     /sys/power/mem_sleep  -    -   -   -   deep
EOF
	# apply to the running system now too
	echo deep > /sys/power/mem_sleep
	echo "mem_sleep: $(cat /sys/power/mem_sleep) (brackets = active)"
else
	echo "mem_sleep: 'deep'/S3 not offered by firmware, skipping (not silver-fox?)"
fi

echo "PASS install-silver-fox"
