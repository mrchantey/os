- Start every chat with 'evnin partner'


# Editing OS Config

This is my omarchy config, located at `~/me/os`.
The source for omarchy is located at `~/me/omarchy`.
Omarchy also installs files to `~/.local`, ie `~/.local/share/hyprland`, and also to `~/.config`, some of which are overrided via stow.

When asked to make changes use these files as reference to understand the system.

## Per-device config

Most config is common, stowed by the `hypr` package and shared `just` recipes.
Naming convention: `*.conf` is shared (common `hypr` package); `*-device.conf`
is per-device and lives in a per-device stow package named after the machine
(`stow/hypr-rainbow-cat`, `stow/hypr-silver-fox`), stowed by `stow-device <name>`
and selected via `init-<name>`. The per-device files are `monitors-device.conf`,
`input-device.conf`, `envs-device.conf`, `layout-device.conf`.

Input is split: shared settings (keyboard, scroll speed, cursor, trackball) live
in the common `hypr/input.conf`, and each device's `input-device.conf` holds only
its overrides (left_handed, touchpad gestures). `input.conf` is sourced before
`input-device.conf` so per-device settings win. When editing monitors/GPU-env or
window-layout settings, edit the right device package; shared input or anything
else goes in the common `hypr` package.

`layout-device.conf` holds the master-layout `master {}` block (sourced after the
shared `looknfeel.conf` so it overrides it): rainbow-cat opens a centered master
column for its ultrawide; silver-fox opens windows full-screen.


### Devices

`silver-fox`
	- Dell XPS 15 9500 laptop
	- NVIDIA GTX 1650 Ti, 4GB of GDDR6 VRAM
