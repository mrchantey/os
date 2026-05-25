- Start every chat with 'evnin partner'


# Editing OS Config

This is my omarchy config, located at `~/me/os`.
The source for omarchy is located at `~/me/omarchy`.
Omarchy also installs files to `~/.local`, ie `~/.local/share/hyprland`, and also to `~/.config`, some of which are overrided via stow.

When asked to make changes use these files as reference to understand the system.

## Per-device config

Most config is common, stowed by the `hypr` package and shared `just` recipes.
Only the three device-specific hypr files — `monitors.conf`, `input.conf`,
`envs.conf` — live in per-device stow packages named after the machine
(`stow/hypr-blackboy`, `stow/hypr-prettyboy`), stowed by `stow-device <name>`
and selected via `init-<name>`. When editing monitors/input/GPU-env settings,
edit the right device package; everything else goes in the common `hypr` package.