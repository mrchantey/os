echo "starting up"
sleep 0.1
# the Logitech BRIO powers on at full-scale capture gain (wpctl 1.0 = hardware
# +54dB), which clips hard and wrecks voxtype accuracy. WirePlumber owns the gain
# and re-applies its default when it initializes the card at login, so set it
# THROUGH WirePlumber — it persists the value (~/.local/state/wireplumber) and
# restores it every boot. The BRIO's gain is cubic: total dB = 54 + 60*log10(vol),
# clamped at the +18dB hardware floor below ~0.25. 0.35 maps to hardware +26.5dB,
# calibrated against real speech (emphatic peaks ~-12dBFS, ample headroom).
# Poll until the mic source exists, since WirePlumber may still be starting here.
for _ in $(seq 1 50); do
	wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 0.35 >/dev/null 2>&1 && break
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
