echo "starting up"
sleep 0.1
# the built-in Realtek mic powers on with +30dB "Internal Mic Boost" stacked on
# +30dB "Capture" gain, saturating the ADC — this clips hard (OSD pegs red) and
# wrecks voxtype accuracy. amixer can't fix this: WirePlumber owns the mic gain and
# re-applies its default (full-scale) when it initializes the card at login, clobbering
# any amixer call that races ahead of it. Set the gain THROUGH WirePlumber instead — it
# persists the value (~/.local/state/wireplumber) and restores it every boot. 0.13 maps
# to Capture +6.75dB / boost off, calibrated against real speech (peaks ~-18dBFS).
# Poll until the mic source exists, since WirePlumber may still be starting at this point.
for _ in $(seq 1 50); do
	wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 0.13 >/dev/null 2>&1 && break
	sleep 0.2
done
sleep 0.1
hyprctl dispatch workspace 1
sleep 0.1
zed ~/me/beet
sleep 0.1
hyprctl dispatch workspace 7
sleep 0.1
omarchy-launch-webapp "https://music.youtube.com"
sleep 0.1
# not going back to 1?
hyprctl dispatch workspace 1
sleep 0.1
echo "done"
