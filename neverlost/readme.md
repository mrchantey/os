# Never-Lost Rainbow cursors

Animated 32x32 pixel-art cursors by Kelinmiriel, CC BY. Full set and attribution details: [rw-designer.com](http://www.rw-designer.com/cursor-set/never-lost-rainbow) and `never-lost-rainbow/readme.txt`.

The original is a Windows set of 25 `.ani` files. Only the 13 the Linux theme actually uses are kept here; the 12 unused alternates and the Windows `cursorschemes.reg` that selected them were dropped. Re-download from the link above if you want to swap one in.

## Install

```
just install-cursor-theme
```

Builds `~/.local/share/icons/Never-Lost-Rainbow` from the `.ani` files, points Hyprland, XWayland, and GTK at it, and puts `cursor-toggle` on PATH. Re-runnable; it rebuilds the theme from scratch each time and forces the cursor on.

## Toggling

```
cursor-toggle          # flip
cursor-toggle on|off   # force a state
```

Off falls back to the system default (`/usr/share/icons/default`, which inherits Adwaita) at Omarchy's cursor size of 24.

The state is a flag file, `~/.local/state/cursor-off`, on the same pattern as `presentation-mode`. `scripts/cursor-toggle.sh` applies the change to the running session, and `stow/hypr/.config/hypr/envs.lua` reads the same flag at config load, so the choice survives a reload or a relogin rather than lasting only the session. Apps already running when you toggle keep their old cursor until they restart.

## How the conversion works

Windows animated cursors and X11's Xcursor format are both multi-frame formats, so the artwork, hotspots, and 24-frame animation carry over unchanged; `win2xcur` handles that step. What does not carry over is how a cursor gets *selected*: Windows assigns by role (`Arrow`, `IBeam`, `SizeNS`), X11 by name, across roughly 90 names in circulation. `scripts/install-cursor-theme.py` holds that mapping along with the pixel-art upscaling, and is the file to edit to change which cursor plays which role.

Two things differ from the original Windows scheme:

- It only assigned 9 of the 25 cursors, leaving help, working-in-background, unavailable, and precision on the stock Aero art. Those files don't exist on Linux, so the set's own equivalents (`02`, `03a`, `05`, `08`) are used instead. Without them those roles would fall through to Adwaita.
- It pointed `SizeNS` at `06b (text)`, a thin vertical double-arrow, skipping `09b (v resize)` entirely. `09b` is used instead, matching the chunky `10b`/`11b`/`12b`/`13b` resize family the scheme uses for every other direction.

The source art is 32x32 pixel art, so the theme bakes in nearest-neighbour copies at 32/48/64/96 rather than letting clients resample it into mush. `XCURSOR_SIZE` is 32 while the cursor is on, up from Omarchy's default of 24, so the native size renders 1:1.

Not built: a native [hyprcursor](https://github.com/hyprwm/hyprcursor) theme. Hyprland falls back to XCursor cleanly, `hyprcursor-util --extract` needs `xcur2png` which isn't installed, and the baked-in sizes cover the same ground.
