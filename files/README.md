# files/

Config that is tracked here but **copied** into place rather than stowed,
because the owning app rewrites the file in a way that destroys a symlink.

Deployed by `just stow-files`; pulled back with `just pull-files` after you
change something through a GUI.

## omarchy/shell.json

The Omarchy shell (Quickshell) config: bar layout, widget settings, idle/lock
timings. Replaces the old `waybar/config.jsonc` + `hypridle.conf` pair.

It cannot be stowed because `omarchy-shell-config` writes it with
`mktemp` + `mv`, which replaces a symlink with a regular file. Anything that
edits the bar goes through that path — `omarchy bar move ...`, the bar settings
panel, enabling or disabling a plugin — so a stowed copy would silently detach
from this repo on the first tweak.

Workflow: edit here and `just stow-files`, or tweak in the GUI and
`just pull-files` to capture it.
