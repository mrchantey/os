echo "starting up"
sleep 0.1
hyprctl dispatch workspace 1
sleep 0.1
zeditor ~/me/beet
sleep 0.1
hyprctl dispatch workspace 7
sleep 0.1
omarchy-launch-webapp "https://music.youtube.com"
sleep 0.1
hyprctl dispatch workspace 1
echo "done"
