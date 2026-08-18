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

## Dev tooling goes through mise

Quattro made mise (pacman package, `/usr/bin/mise`) the backbone for language runtimes and CLI tools. Two distinct mechanisms, don't mix them up:

- **Runtimes** are plain global mise installs: `omarchy-install-dev-env <node|deno|zig|go|python|bun|java|ruby|elixir|dotnet|clojure|scala>`, which is the same entry point as Menu > Install > Development. It boils down to `mise use -g <tool>@latest`.
- **CLI tools** are `omarchy-mise-install <package> [command] [bin]`, which writes a four-line wrapper into `~/.local/bin/<command>`. Every invocation runs `mise use -g <package>` then `mise x`, so the tool installs on first use and self-updates thereafter. `MISE_MINIMUM_RELEASE_AGE=0` is exported inside the wrapper to bypass mise's release cooldown. Omarchy ships a fleet of these in `install/user/mise.sh`: claude, codex, gemini, crush, copilot, opencode, gh, playwright, pi, omp, grok, ghui, hunk. Never install those a second way, `omarchy-mise-install` starts by `rm -f`-ing the target path, so a competing pacman/AUR/npm install just becomes shadowed dead weight.

**Gotcha: those wrappers write to stdout.** `mise use -g` prints `mise <config> tools: <pkg>@<version>` on stdout every run, not just on an install, so every `omarchy-mise-install` tool prepends a junk line to its own output. Harmless for a TUI, not harmless when the output is piped or parsed: `gh api ... | jq` gets a bad first line. If a tool's stdout is a data channel, do not use `omarchy-mise-install` for it. `scripts/claude-agent-acp.sh` is the worked example, a hand-rolled copy of the wrapper with the `mise use` line redirected to stderr, because Zed speaks JSON-RPC to it over stdio. Don't reach for `MISE_QUIET=1` as a global fix, it also silences install progress, so a first run that downloads 100MB looks like a hang.

Not everything is mise. Rust is rustup (we take pacman's `rustup` rather than omarchy's rustup.rs curl installer, same toolchain manager either way), PHP is pacman, OCaml is opam, and uv comes from astral's install script, which `omarchy-install-dev-env python` runs alongside the mise interpreter.

Python is worth understanding rather than copying. Arch's `/usr/bin/python` rolls minor versions and takes every venv built against it along, which is the actual reason python hurts on this distro; mise's interpreter is what insulates you from that, so install it even though nothing here calls `python` directly. Two things to know about the uv half. Pass `UV_NO_MODIFY_PATH=1`, or astral's installer appends a `. ~/.local/bin/env` line to our *stowed* `.bashrc` on every run, editing a tracked file to add a `~/.local/bin` that `.bashrc` already puts on PATH itself. And because a curl-installed uv is in neither pacman nor mise, nothing in `omarchy update` moves it, so `stow/omarchy/.config/omarchy/hooks/post-update.d/uv-self-update` runs `uv self update` from omarchy's own post-update hook. Never add a second uv from pacman: `~/.local/bin` is *prepended* by `.bashrc` but *appended* by `env-bootstrap`, so terminals would get one uv and GUI apps the other, which is the same split that Vite+ caused for node.

Our additions live in `just install-mise-tools`: the node/deno/zig/python runtimes, plus `wrangler`, `cf` and the Zed ACP adapter as wrappers. Anything that needs a global CLI belongs there, not in an `npm install -g`. It runs before `init-user` in `just init` because `setup-tts` builds the kokoro venv with uv and would otherwise hit `uv: command not found`.

PATH is assembled by `/usr/share/omarchy/default/bash/env-bootstrap`, which appends `~/.local/share/mise/shims` then `~/.local/bin`; `default/bash/init` adds `mise activate bash` for interactive shells, and a `PATH` line in `/etc/security/pam_env.conf` covers `ssh host cmd`, which runs no shell setup at all. Because that all happens outside `.bashrc`, anything prepended in `stow/bashrc/.bashrc` wins over mise for terminals only, and GUI-launched apps keep getting the mise version. That split is exactly what removing Vite+ fixed, so think twice before putting another runtime ahead of the shims there.

Updates flow through `omarchy update`, which calls `omarchy-update-mise` (`MISE_MINIMUM_RELEASE_AGE=0 mise up`). The `mup` alias is the same thing by hand.

## Cursor theme

The pointer is Never-Lost Rainbow, converted from the Windows `.ani` set in `neverlost/` (see its readme for what the conversion changes). `just install-cursor-theme` runs `scripts/install-cursor-theme.py`, which builds the XCursor theme into `~/.local/share/icons/Never-Lost-Rainbow`. That script also owns the Windows-role-to-X11-name mapping, so it is the file to edit to change which cursor plays which role.

`cursor-toggle` (on PATH, from `scripts/cursor-toggle.sh`) turns it on and off, falling back to the system default theme. State is the flag file `~/.local/state/cursor-off`, on the same pattern as `presentation-mode`.

`XCURSOR_THEME` and `XCURSOR_SIZE` are set in the shared `hypr/envs.lua`, which is required from `hyprland.lua` after Omarchy's defaults so it overrides their size of 24. It reads the same flag the toggle writes, which is what makes the choice survive a reload. Both branches assign every variable, because `hyprctl reload` can overwrite an env var but never unsets one. GTK apps read the theme from gsettings instead, which the toggle sets.

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
