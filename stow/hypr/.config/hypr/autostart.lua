-- Extra autostart processes.
--
-- Dropped in the quattro port: `udiskie --no-tray` for USB auto-mounting.
-- Omarchy's default autostart now launches it itself, with automount enabled
-- (see $OMARCHY_PATH/default/hypr/autostart.lua), so a second copy just raced.

-- Run the per-device startup script (scripts/silver-fox or scripts/rainbow-cat)
o.exec_on_start("~/me/os/scripts/$(hostname)/startup.sh")

-- o.launch_on_start("my-service")
