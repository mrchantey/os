echo "starting up"
sleep 0.1
# the built-in Realtek mic powers on with +30dB "Internal Mic Boost" stacked on
# +30dB "Capture" gain, saturating the ADC — this clips hard (OSD pegs red) and
# wrecks voxtype accuracy. Disable the boost and drop capture to +6.75dB,
# calibrated against real speech (peaks ~-18dBFS, no clipping).
amixer -c 0 sset 'Internal Mic Boost' 0 >/dev/null 2>&1 || true
amixer -c 0 sset 'Capture' 7dB          >/dev/null 2>&1 || true
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
