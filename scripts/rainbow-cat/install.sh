#!/usr/bin/env bash
# rainbow-cat (desktop) system-level setup that needs root.
# Idempotent and safe to run anywhere: the modprobe blacklist is harmless on
# machines without a Logitech receiver, and the rebind step no-ops when the
# receiver is absent.
#
# Run directly (`bash scripts/rainbow-cat/install.sh`) or via `just install-rainbow-cat`.
set -euo pipefail

# re-exec under sudo if we are not already root (single prompt for the whole script)
if [[ ${EUID} -ne 0 ]]; then
	exec sudo bash "$0" "$@"
fi

### G903 / Lightspeed receiver: stop hid-logitech-dj from releasing held buttons.
# the hid-logitech-dj driver turns the receiver's "link loss" notification (a
# sub-second RF blip) into a null report that releases every held mouse button
# (logi_dj_recv_forward_null_report in drivers/hid/hid-logitech-dj.c), which
# drops drags mid-flight. windows rides those blips out, so the same desk setup
# feels flawless there. blacklisting the module leaves the receiver on plain
# hid-generic, which forwards reports as-is and keeps buttons held across
# blips, matching windows. cost: no battery reporting via the receiver.
CONF=/etc/modprobe.d/no-hid-logitech-dj.conf
tee "${CONF}" >/dev/null <<'EOF'
# hid-logitech-dj force-releases all buttons on momentary wireless link loss,
# which drops G903 drags mid-flight. keep the receiver on hid-generic instead.
# see ~/me/os/scripts/rainbow-cat/install.sh
blacklist hid_logitech_dj
EOF

# apply to the running system: unload the driver, then re-enumerate the
# receiver so its interfaces rebind to hid-generic (no physical replug needed)
modprobe -r hid_logitech_hidpp hid_logitech_dj 2>/dev/null || true
found=
for dev in /sys/bus/usb/devices/*; do
	[[ -f "${dev}/idVendor" ]] || continue
	if [[ $(cat "${dev}/idVendor") == 046d && $(cat "${dev}/idProduct") == c539 ]]; then
		port=$(basename "${dev}")
		echo "${port}" >/sys/bus/usb/drivers/usb/unbind
		sleep 1
		echo "${port}" >/sys/bus/usb/drivers/usb/bind
		echo "lightspeed receiver: rebound ${port} to hid-generic"
		found=1
	fi
done
[[ -n "${found}" ]] || echo "lightspeed receiver: not plugged in, blacklist still installed"

echo "PASS install-rainbow-cat"
