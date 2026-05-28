---
name: git-sync
description: >
  Use to synchronize this machine with the ~/me/os dotfiles repo: commit and
  push local changes ("our own") and pull the latest from origin, then patch
  the live OS so it actually matches the repo. Triggers: "sync the os repo",
  "git sync", "/git-sync", "pull and push my dotfiles", "update this machine
  from the repo", "bring this box up to date". Covers committing local work,
  rebasing onto origin, and re-applying stow/services/hyprland after the pull.
---

# Git Sync

Synchronize `~/me/os` (the omarchy dotfiles repo) in both directions and then
**make the running OS match the repo**.

The repo is just config — the box only changes when something re-reads that
config. Most of the time that's automatic, but not always, so a sync is two
jobs:

1. **Git**: commit + push local work, pull origin, end on a clean linear tree.
2. **Patch**: re-apply only the things the pull changed that aren't picked up
   for free.

## The mental model (why "patch" is needed at all)

Every tracked dotfile is a **stow symlink pointing into this repo**
(`~/.config/zed/settings.json` → `~/me/os/stow/zed/...`). So when `git pull`
rewrites a file's *contents*, the change is **already live** — the symlink
points at the new bytes. No action needed for plain content edits.

You only need to patch when the pull changed something *structural*:

- a **new or removed stow module** (no symlink exists yet at its target),
- a change to the **stow lists / justfile** wiring,
- a **systemd unit / drop-in** (systemd caches units until `daemon-reload`),
- a **long-running app that reads its config once at startup** (Hyprland,
  Waybar, Walker, the voxtype daemon) — the file is new but the process is
  still running the old config.

So: do the git half, diff what landed, and apply *only* the matching patches.

## Steps

### 1. Preflight

```sh
cd ~/me/os
git status -sb        # confirm branch tracks origin/main, see what's dirty
git remote -v         # expect origin = github.com/mrchantey/os
```

### 2. Commit local work ("our own")

A sync exists to push your local edits, so commit them. **Before committing,
look at the diff** and make sure nothing secret is being staged (credentials,
tokens, `*.pem`, real keys — see `add-stow-module`):

```sh
git diff --stat
git diff            # eyeball it; abort if a secret is in there
```

Then stage and commit. Match the repo's terse convention — short lowercase
`patch` / `patch: <what>` / `feat: <what>` messages (see `git log --oneline`):

```sh
git add -A
git commit -m "patch: <one line on what changed>"
```

If the tree is already clean, skip to the pull.

### 3. Pull from origin (rebase)

The history is linear "patch" commits — keep it that way. Rebase replays your
local commits on top of origin instead of making a merge commit:

```sh
before=$(git rev-parse HEAD)      # remember where we were, for the diff below
git pull --rebase origin main
```

**On conflict: stop.** Do not auto-resolve dotfiles blindly. Report the
conflicting files, let the user resolve, then `git rebase --continue` (or
`git rebase --abort` to back out). Resume at step 4 afterward.

### 4. Push

```sh
git push
```

### 5. Patch the live OS from what was pulled

List the paths that changed across the whole sync (pulled commits + your
replayed commits), then apply only the matching actions:

```sh
git diff --name-only "$before" HEAD
```

| Changed paths | Why it needs a patch | Action |
| --- | --- | --- |
| **New/removed `stow/<mod>/`**, or `justfile` stow lists | new module has no symlink yet | `just stow-symlinks` (idempotent relink) |
| `stow/hypr-<host>/` (device files) | device overrides re-stowed | `just stow-device "$(hostname)"` then `omarchy-restart-hyprctl` |
| `stow/hypr/` (common hypr) | Hyprland holds config in memory | `omarchy-restart-hyprctl` (`hyprctl reload`) |
| `stow/waybar/` | Waybar reads config at launch | `omarchy-restart-waybar` |
| `stow/<walker>/` (walker/elephant) | Walker reads config at launch | `omarchy-restart-walker` |
| `stow/voxtype/`, `scripts/voxtype-*`, or voxtype `just` recipes | daemon caches model/config at startup | `just restart-voxtype`; if the drop-in *generation* logic changed, re-run `just setup-voxtype-isolation` (and `just setup-voxtype-gpu` if GPU pinning changed) |
| `scripts/*/startup.sh` | needs exec bit | `chmod +x scripts/*/startup.sh` |
| `justfile` **install lists** (`install-apps`, `install-user-apps`, `install-extras`, `install-rust`) | new packages aren't installed by a pull | **ask the user** before running — these are heavy/`sudo`. Then run the matching `just install-*` recipe |
| anything else (zed, alacritty, ghostty, bashrc, claude, opencode, mimeapps, starship, …) | plain content edit through a live symlink | **nothing — already live** (open a new shell for `.bashrc`) |

Guard the device step — only stow a device package that exists:

```sh
host=$(hostname)
[ -d "stow/hypr-$host" ] && just stow-device "$host"
```

### 6. Confirm

```sh
git status -sb        # clean, up to date with origin/main
```

Report what you pushed, what you pulled, and which patches you ran (or that
none were needed).

## Gotchas

- **Never `git pull` with a dirty tree** — commit (step 2) or `git stash`
  first, or the rebase refuses. Prefer committing; that's the point of a sync.
- **Don't auto-resolve conflicts** in dotfiles. A bad merge of
  `monitors.conf` or a hypr file can wedge the session. Stop and ask.
- **`just stow-symlinks` and `just stow-device` are idempotent** — safe to run
  even when nothing structural changed. When unsure whether a pull added a
  module, just run `stow-symlinks`; it only relinks.
- **`hyprland.conf` is special**: a live Hyprland regenerates a default stub
  the instant that symlink goes missing, which aborts the whole hypr stow.
  `just stow-symlinks` pre-creates it atomically — don't `rm` it by hand mid-sync.
- **Content vs structure**: a one-line edit to an existing tracked file needs
  *no* patch (symlink already points at it); a *new* file/module needs a relink.
  When in doubt, the table's "Action" column is always safe to run.
- **Don't reflexively re-run install recipes.** A pull that only touched config
  installs nothing new — only `just install-*` when the package *lists* changed,
  and confirm first (they use `sudo`/`yay`).
