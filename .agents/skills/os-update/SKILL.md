---
name: os-update
description: >
  Update Omarchy on this machine and reconcile the ~/me/os stow config afterward.
  Use when the user says omarchy is "ready for an update" / "update omarchy", or asks to
  realign / re-sync stowed config with a new omarchy version, or reports that hypr/waybar
  stow symlinks broke after an update. Covers: omarchy-update, broken stow symlinks from
  `sed -i` migrations, folded directory symlinks, refresh-clobbered configs (hypridle),
  renamed omarchy commands, and restoring symlinks via the justfile stow recipes.
  This is specific to the ~/me/os GNU stow dotfiles repo. For ordinary one-off config
  edits (themes, keybindings, single tweaks) use the `omarchy` skill instead.
---

# os-update

Update Omarchy and bring the `~/me/os` stow config back into alignment with the new
defaults/migrations — without leaving broken symlinks or losing customizations.

## System layout (this machine)

- **Config repo:** `~/me/os`, GNU stow packages under `stow/`. Git-tracked = source of truth.
- **Omarchy install:** `~/.local/share/omarchy` (READ-ONLY; reading is fine). Version: `omarchy-version`.
- **Migrations:** `~/.local/share/omarchy/migrations/*.sh`; applied-markers in
  `~/.local/state/omarchy/migrations/` (empty file per applied migration; `skipped/` subdir for skips).
- **Device packages:** `hypr-rainbow-cat`, `hypr-silver-fox` hold ONLY `monitors-device.conf`,
  `input-device.conf`, `envs-device.conf`, `layout-device.conf` (`*-device.conf` = per-device;
  `*.conf`, including the shared `input.conf`, is the common `hypr` package).
  Detect device: `readlink ~/.config/hypr/monitors-device.conf` (→ `hypr-<device>`), or `hostname`.
- **Stow recipes** (`~/me/os/justfile`): `stow-symlinks` (common pkgs), `stow-device <name>`
  (device hypr overrides), `init-<device>`. Re-link manually with:
  `cd ~/me/os/stow && stow -vt ~ hypr hypr-<device>`.

## Two symlink styles — this is the crux

1. **Folded directory symlinks**: `~/.config/waybar`, `~/.config/voxtype`, `~/.config/autostart`
   are whole-directory symlinks into the stow source. Migration edits (`sed -i`, `cp`, `>>`)
   resolve THROUGH the dir link and land **directly in the stow source** → they just show up
   as normal `git diff` in `~/me/os`. No relinking needed; only review/keep.
2. **File-level symlinks**: `~/.config/hypr/*` — because `~/.config/hypr` is a REAL directory
   (shared by the common + device packages and the special `hyprland.conf` handling), each
   file is individually symlinked.

**The hazard:** GNU `sed -i` does NOT follow symlinks — it writes a temp file and renames it
over the path, **replacing the symlink with a regular file** (edit applied), leaving the stow
source stale and the link broken. This hits file-level symlinks (`hypr/*`) only.
Contrast:
- `echo >>` / `cat >>` (append) **follow** the symlink → write to the stow source (link survives).
- `cp -f default → ~/.config/x` (used by `omarchy-refresh-*`): if the link is still intact,
  follows it and **overwrites the stow SOURCE with the stock default** (clobbers customizations);
  if an earlier `sed -i` already broke the link, it just overwrites the regular `~/.config` file
  (source preserved). Either way the user's customization survives in git history + a
  `*.bak.<timestamp>` left in the same dir.

## Blocker: the update itself needs interactive sudo

`omarchy-update` runs `pacman -Syu`, `yay`, and migrations that call `sudo`; sudo here requires
a password the agent can't supply (`sudo -n true` fails). **The user must run `omarchy-update`
in their terminal.** Order matters — update FIRST (the pull brings new default files like
`default/waybar/weather.sh` and installs packages), reconcile AFTER. Do NOT pre-edit stow
sources to reference files that only exist post-update.

`omarchy-update` is also interactive by design (gum confirm). If asked to drive it, explain the
sudo limitation rather than trying `-y` in the background (the password prompt and migration gum
prompts will still block).

## Pre-update analysis (optional but valued)

Before the user runs it, you can preview impact:
```bash
cd ~/.local/share/omarchy && git fetch --tags
# new migrations the pull will add:
git diff --name-status HEAD origin/master -- migrations/ | awk '$1=="A"{print $2}'
# read the ones touching stowed config:
git show origin/master:migrations/<ts>.sh   # grep for hypr|waybar|bindings|monitors|.config
```
Flag which stowed files each migration edits, and which use plain `sed -i` (→ will break
file-level symlinks) vs `>>`/`cp`/refresh.

## Reconciliation workflow (after the user runs the update)

1. **State check:**
   ```bash
   omarchy-version
   ls ~/.local/state/omarchy/migrations/skipped/      # any skipped (e.g. sudo timeout)?
   cd ~/me/os && git status -s                          # folded-dir edits show here automatically
   ```
2. **Find broken symlinks** — any stowed `~/.config/hypr/*` that is now a regular file:
   ```bash
   for f in bindings autostart hypridle hyprlock hyprsunset looknfeel windows xdph hyprland \
            monitors input envs layout; do
     p=~/.config/hypr/$f.conf
     [[ -L $p ]] && echo "LINK    $f" || { [[ -f $p ]] && echo "REGULAR $f (broken)" || echo "MISSING $f"; }
   done
   ```
3. **Diff each broken file vs its stow source** (`stow/hypr/...` or `stow/hypr-<device>/...`):
   - **Identical** → migration rewrote it but no net change for this user → just relink (step 5).
   - **Differs** → real change. Decide source-of-truth per case (see "Merge cases").
4. **Merge cases** — write the reconciled content into the **stow SOURCE**, not `~/.config`:
   - **Refresh-clobbered** (e.g. `hypridle.conf` via `omarchy-refresh-hypridle`): the live file is
     the stock default; the user's customization is in the stow source and/or git/`.bak`. Merge:
     adopt the new omarchy commands/structure, **preserve the user's tuning** (e.g. hypridle's
     long idle timeouts, the dpms screen-off listener).
   - **Renamed commands**: verify referenced commands still exist (`which omarchy-lock-screen` →
     gone, now `omarchy-system-lock`/`omarchy-system-wake`). Update the stow source even where the
     migration's grep-guard didn't match the user's custom file (the user's file may still call the
     dead name).
5. **Restore symlinks:**
   ```bash
   rm -f ~/.config/hypr/{<broken files>}.conf
   cd ~/me/os/stow && stow -vt ~ hypr hypr-<device>
   ```
   (Re-stowing no-ops already-correct links and recreates the removed ones. Don't run the `-init`
   justfile recipes — they `rm -rf` lots of things.)
6. **Verify & apply:**
   ```bash
   # all should be LINK again (repeat step 2 check)
   hyprctl reload
   omarchy-restart-hypridle && pgrep -ax hypridle      # pgrep right after restart can race; recheck
   omarchy-restart-waybar
   ```
   To validate a hypridle config parses: `timeout 2 hypridle -c <conf>` shows registered rules —
   but it spawns a SECOND instance, so kill it (the `timeout` does) and confirm only one remains.
   For new waybar modules (e.g. weather) confirm the referenced script exists
   (`ls ~/.local/share/omarchy/default/waybar/weather.sh`).
7. **Review, don't commit:** show the full `git diff` in `~/me/os` and summarize. Do NOT commit
   unless the user asks.

## Don'ts

- Never edit `~/.local/share/omarchy/` (lost on next update).
- Don't run the system update non-interactively / with `-y` in the background (sudo will hang).
- Don't pre-create migration skip-markers for migrations that also do package/system work.
- Don't pre-align stow sources to reference files that only land during the update.
