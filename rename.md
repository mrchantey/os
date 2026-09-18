# Repo rename: os -> arch-config

Done on rainbow-cat 2026-09-18. GitHub is already `mrchantey/arch-config` (the old name redirects). Run this once on silver-fox, then delete this file.

```sh
# 1. pull, fix the remote, move the checkout
cd ~/me/os && git pull && git remote set-url origin https://github.com/mrchantey/arch-config.git
cd ~ && mv ~/me/os ~/me/arch-config

# 2. rewrite every symlink in ~ that targets me/os (stow links plus ~/.local/bin)
find ~ -maxdepth 6 \( -path "$HOME/me" -o -path "$HOME/.cache" -o -path "$HOME/.local/share/mise" -o -path "$HOME/.local/share/kokoro-fastapi" \) -prune -o -type l -lname '*me/os/*' -print0 \
  | while IFS= read -r -d '' l; do t=$(readlink "$l"); ln -sfn "${t//me\/os\//me\/arch-config\/}" "$l"; done

# 3. generated systemd units, desktop db, hyprland
sed -i 's#/me/os/#/me/arch-config/#g' ~/.config/systemd/user/voxtype.service.d/battery-isolation.conf ~/.config/systemd/user/kokoro-tts.service
systemctl --user daemon-reload
update-desktop-database ~/.local/share/applications
hyprctl reload && hyprctl configerrors

# 4. verify: both should print nothing
find ~ -maxdepth 6 -type l -lname '*me/os*' -not -path "$HOME/me/*"
cd ~/me/arch-config/stow && stow -nvt ~ hypr hypr-silver-fox bashrc zed 2>&1 | grep -v simulation
```

Optional, keeps `claude --resume` history for this project: `mv ~/.claude/projects/-home-pete-me-os ~/.claude/projects/-home-pete-me-arch-config` (not while a session is open there).
