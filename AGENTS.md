- Start every chat with 'evnin partner'


# Editing OS Config

This is my omarchy config, located at `~/me/os`.
Omarchy 4 ("quattro") installs to `/usr/share/omarchy` (read-only, never edit; `~/.local/share/omarchy` is a back-compat symlink to it), and to `~/.config`, some of which is overridden via stow.
Generated state (current theme, toggles, workspace layouts) lives in `~/.local/state/omarchy`, which is where `current/theme/...` moved to from `~/.config/omarchy/current`.

When asked to make changes use these files as reference to understand the system.

## Hyprland is configured in Lua

Quattro replaced the `*.conf` + `source =` chain with native Lua. `~/.config/hypr/hyprland.lua` is the entry point; everything else is a module resolved off `package.path` (`~/.config/?.lua`, then `$OMARCHY_PATH/?.lua`). Omarchy's defaults are loaded first via `require("default.hypr.omarchy")`, so our modules override them.

Reference for the API: type stubs at `/usr/share/hypr/stubs/hl.meta.lua` (wired up for the LSP by `hypr/.luarc.json`), and Omarchy's own defaults in `/usr/share/omarchy/default/hypr/`.

Two gotchas that differ from the old `.conf` files:

- **Re-binding a key does not replace the old bind, both fire.** Call `hl.unbind("SUPER + F")` before `o.bind(...)`. Every unbind in `bindings.lua` names the default it displaces.
- **Keysyms must match xkbcommon exactly.** `Page_Up`/`Page_Down`, not `PAGEUP`/`PAGEDOWN`; `comma`, not `COMMA`. The old parser was forgiving, the Lua binder is not. Validate with `hyprctl reload && hyprctl configerrors`, which reports these.

Only `hyprsunset.conf` and `xdph.conf` are still `.conf`: they are read by separate processes, not Hyprland, so `hyprctl` neither applies nor validates them.

## Per-device config

Most config is common, stowed by the `hypr` package and shared `just` recipes.
Naming convention: `*.lua` is shared (common `hypr` package); `*-device.lua` and `monitors.lua` are per-device and live in a stow package named after the machine (`stow/hypr-rainbow-cat`, `stow/hypr-silver-fox`), stowed by `stow-device <name>` and selected via `init-<name>`. The per-device files are `monitors.lua`, `input-device.lua`, `layout-device.lua`.

Device modules are loaded with `require_optional` so a machine whose device package isn't stowed still boots.

Input is split: shared settings (keyboard, scroll speed, trackball) live in the common `hypr/input.lua`, and each device's `input-device.lua` holds only its overrides (left_handed, touchpad gestures). `input.lua` is required before `input-device.lua` so per-device settings win. When editing monitors or window-layout settings, edit the right device package; shared input or anything else goes in the common `hypr` package.

`layout-device.lua` holds the master-layout `master` block (required after the shared `looknfeel.lua` so it overrides it): rainbow-cat opens a centered master column for its ultrawide; silver-fox opens windows full-screen.

`monitors.lua` also owns `GDK_SCALE` and workspace-to-monitor pinning (`hl.workspace_rule`). There is no `envs-device.lua`: Omarchy detects the NVIDIA GPU and sets `NVD_BACKEND` / `LIBVA_DRIVER_NAME` / `__GLX_VENDOR_LIBRARY_NAME` itself (see `default/hypr/nvidia.lua`).

## The bar, launcher, and idle are one Quickshell process

Quattro replaced waybar (bar), walker + elephant (launcher), mako (notifications), swayosd (OSD), and hypridle + hyprlock (idle/lock) with a single long-running Quickshell process, `omarchy-shell`. All of those packages are uninstalled and their stow packages are deleted.

It is configured by `~/.config/omarchy/shell.json`, which hot-reloads on save. Our copy is tracked at `files/omarchy/shell.json` and **copied** into place by `just stow-files`, not stowed: `omarchy-shell-config` writes the file with `mktemp` + `mv`, which would replace a symlink with a regular file the first time anything edits the bar. Use `just pull-files` to capture GUI-made changes back into the repo.

Idle timings (`idle.screensaver`, `idle.lock`, in seconds) live there too, replacing `hypridle.conf`. There is no display-off setting: `omarchy-system-lock` turns the display off itself.

To customize a built-in widget, never edit `/usr/share/omarchy/shell/plugins/`; clone it with `omarchy plugin clone omarchy.<widget>`, which switches the bar to `<username>.<widget>` under `~/.config/omarchy/plugins/`.

### Devices

`silver-fox`
	- Dell XPS 15 9500 laptop
	- NVIDIA GTX 1650 Ti, 4GB of GDDR6 VRAM

`rainbow-cat`
	- desktop, NVIDIA (primary GPU)
	- Samsung C49RG9x ultrawide (5120x1440@120, scaled 1.25) + C24F390 1080p to its right
