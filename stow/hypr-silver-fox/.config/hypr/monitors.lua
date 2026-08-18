-- silver-fox (Dell XPS 15 9500) — single internal 4K panel.
-- omarchy auto-scaling looks crisp; leave it to decide scale.
-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
--
-- The old envs-device.conf was comment-only (Intel iGPU drives the compositor;
-- the GTX 1650 Ti is for CUDA + per-app PRIME render offload, e.g.
--   __NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia <app>
-- and LIBVA_DRIVER_NAME must NOT be forced to nvidia). Quattro's nvidia.lua
-- detects the hybrid setup and picks the right vars itself, so nothing to set.

-- HiDPI panel: matches the Omarchy default for XWayland/GTK apps.
hl.env("GDK_SCALE", "2")

hl.monitor({ output = "eDP-1", mode = "preferred", position = "auto", scale = "auto" })

-- Fallback auto-mirror: any external plugged in mirrors the internal panel, even
-- if the hotplug watcher below isn't running. The empty-output rule is Hyprland's
-- fallback -- it applies to any monitor without its own rule, so it catches
-- whatever the cable enumerates as (this machine has no native HDMI; an HDMI cable
-- arrives via USB-C/Thunderbolt and may show up as DP-1, HDMI-A-1, etc). eDP-1
-- keeps its explicit rule above.
--
-- NOTE: this rule alone mirrors the 16:10 panel onto a 16:9 projector, which
-- stretches the image ~11%. scripts/silver-fox/mirror-watch.sh detects the
-- hotplug and upgrades it to a clean 1:1 16:9 mirror by running both displays at
-- 1920x1080 (see scripts/silver-fox/present-mirror). Comment this out if you
-- want extend-on-plug instead of mirror.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1, mirror = "eDP-1" })
