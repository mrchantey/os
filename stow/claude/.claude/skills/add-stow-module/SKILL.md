---
name: add-stow-module
description: >
  Use when adding a new app's config to the ~/me/os stow system. Triggers:
  "add X to stow", "stow X config", "track X dotfiles in os repo", or when
  the user wants to start version-controlling files under ~/.config/<app>,
  ~/.<app>, or similar. Covers preserving existing state, local .gitignore
  setup, and wiring the new module into the justfile.
---

# Add a Stow Module

This repo (`~/me/os`) manages dotfiles via [GNU Stow](https://www.gnu.org/software/stow/). Each subdir of `stow/` is one "module" whose tree mirrors `~`. `just stow-symlinks` links them all into the home directory.

Use this skill any time you're bringing a new app under that system.

## The Pattern

Module layout:

```
stow/<name>/<path-relative-to-home>/<files...>
```

Examples:
- `stow/bashrc/.bashrc`              → `~/.bashrc`
- `stow/zed/.config/zed/...`         → `~/.config/zed/...`
- `stow/claude/.claude/settings.json` → `~/.claude/settings.json`

## Steps (do them in this order)

### 1. Preserve existing state — DO NOT clobber

The target dir under `~` often already exists with state that must not be lost (sessions, credentials, cargo registry, OBS recordings, etc.). Before doing anything:

- **Read what's currently there**: `ls -la ~/<target>` and identify which files are *config* (small, hand-authored, belong in git) vs *state/cache* (large, app-managed, must stay local).
- **Never `rm -rf` the whole target dir** if it has app-managed state. Look at `justfile` `stow-symlinks-init`:
  - The first `rm -rf` block is for dirs that are fully owned by stow (alacritty, zed, …).
  - The second `rm -f` block is fine-grained — used for hypr and claude, where we must preserve siblings.
  Put your new module in whichever block matches.
- **Move, don't copy**, the config file(s) into the repo so the originals are gone before stow runs (stow refuses to overwrite regular files):
  ```sh
  mkdir -p stow/<name>/<path>
  mv ~/<path>/<file> stow/<name>/<path>/<file>
  ```
  If you need a backup first: `cp ~/<path>/<file>{,.bak}` before the move. (`.bak` is gitignored repo-wide.)

### 2. Add a local `.gitignore` inside the module

**Always put the ignore rules next to the files**, not in the root `.gitignore`. Two styles depending on the dir:

- **Whitelist** (preferred when the target dir has lots of app-managed state — cargo, claude):
  ```gitignore
  # Most of this dir is app-managed; only track config we author.
  *
  !.gitignore
  !<config-file>
  !<config-subdir>/
  !<config-subdir>/**
  ```
  Safer because new app-generated junk stays ignored by default.

- **Blacklist** (when most of the dir is config and only a few things are noise — zed, obs):
  ```gitignore
  settings_backup.json
  logs
  .cache
  ```

Verify after writing:
```sh
git check-ignore -v stow/<name>/<path>/<some-state-file>  # should be ignored
git check-ignore -v stow/<name>/<path>/<config-file>      # exit 1 = NOT ignored ✓
```

Do **not** add the module to the repo-root `.gitignore`. Keep ignore rules local to the module — easier to discover, moves with the module, won't drift.

### 3. Wire into `justfile`

Two edits in `justfile`:

a) **`stow-symlinks-init`** — add removal of the *previous* file/dir at the target so stow can lay down its symlink:
   - If the entire `~/<target>` belongs to stow → add it to the broad `rm -rf` block.
   - If `~/<target>` has other state that must survive → add only the specific file(s) to the fine-grained `rm -f` block. Comment is already there explaining why.

b) **`stow-symlinks`** — add the module name (alphabetical, with the trailing `\` for line continuation) to the `stow -vt ~ ...` list.

### 4. Test

```sh
# from repo root
just stow-symlinks
ls -la ~/<path>/<file>   # should now be a symlink into ~/me/os/stow/<name>/...
readlink ~/<path>/<file>
```

Then exercise the app to confirm it still reads the file.

### 5. Commit

`git add stow/<name>/ justfile` and commit. Don't commit secret-bearing files (credentials, tokens, *.pem). If unsure, run `git diff --cached` first.

## Gotchas

- **Stow folding**: if a stow source dir contains only stowable files and the target dir doesn't exist, stow symlinks the *whole directory*. If the target already exists, stow walks in and symlinks individual files instead. This is why preserving the target dir's existence (step 1) matters when state must coexist.
- **Symlinks already inside the target** (e.g. `~/.claude/skills/omarchy` → omarchy install): stow handles these fine, but `rm -rf` would destroy them. Another reason to prefer fine-grained removal.
- **Don't reintroduce root-`.gitignore` entries** when migrating an existing module. The pattern this repo uses now is *local* `.gitignore` per stow module.
- **`**/*.bak.**`** is gitignored repo-wide (omarchy update naming). Single-extension `.bak` files are NOT ignored — useful for taking a manual snapshot before moving a file.

## Reference modules

- Whitelist style with preserved state: `stow/claude/`, `stow/cargo/`
- Blacklist style: `stow/zed/`, `stow/obs/`
- Simple full-dir stow: `stow/alacritty/`, `stow/ghostty/`
