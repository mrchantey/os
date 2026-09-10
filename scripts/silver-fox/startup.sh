echo "starting up"
sleep 0.1
# NOTE: mirror-watch.sh used to be launched here, to force both displays to 1080p
# when a projector was plugged in. That existed only to stop the XPS's 16:10 4K
# panel being squished onto a 16:9 projector. The Precision panel is natively
# 16:9 1080p, so the plain mirror rule in monitors.lua is already 1:1 and both
# scripts were deleted.
#
# the built-in Realtek mic powers on with +30dB "Internal Mic Boost" stacked on
# +30dB "Capture" gain, saturating the ADC — this clips hard (OSD pegs red) and
# wrecks voxtype accuracy. amixer can't fix this: WirePlumber owns the mic gain and
# re-applies its default (full-scale) when it initializes the card at login, clobbering
# any amixer call that races ahead of it. Set the gain THROUGH WirePlumber instead — it
# persists the value (~/.local/state/wireplumber) and restores it every boot. 0.13 maps
# to Capture +6.75dB / boost off, calibrated against real speech (peaks ~-18dBFS).
# Re-verified on the Precision 7560 (2026-09-10): its Realtek codec powers on the same
# way (Capture 63/+30dB, Internal Mic Boost 3/+30dB) and 0.13 lands on the same
# +6.75dB / boost-off pair, so the XPS calibration carried over unchanged.
# Poll until the mic source exists, since WirePlumber may still be starting at this point.
for _ in $(seq 1 50); do
	wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 0.13 >/dev/null 2>&1 && break
	sleep 0.2
done
sleep 0.1
# quattro's hyprctl takes Lua, not the old bare-word dispatcher syntax.
hyprctl dispatch "hl.dsp.focus({ workspace = '1' })"
sleep 0.1
zed ~/me/beet
sleep 1
echo "done"
