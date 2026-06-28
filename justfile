default:
	just --list

restart-voxtype:
	systemctl --user restart voxtype.service

# re-pick GPU vs CPU for the kokoro tts server by current power state (see scripts/tts-server.sh)
restart-tts:
	systemctl --user restart kokoro-tts.service

# device-agnostic base; run this once per install (or a device recipe below)
init:
	just init-sudo
	just init-user
	just install-rust
	just install-npm-packages
	just install-transcribe
	chmod +x scripts/*/startup.sh

# symlink the audio capture+transcribe helper onto PATH (~/.local/bin is on PATH).
# usage from any terminal: `transcribe [name]` -> name.wav + name.txt (default: out)
install-transcribe:
	chmod +x scripts/transcribe.sh
	mkdir -p ~/.local/bin
	ln -sf ~/me/os/scripts/transcribe.sh ~/.local/bin/transcribe
	@echo "PASS install-transcribe"

# rainbow-cat (desktop): base + device hypr overrides + gaming/GPU stack
init-rainbow-cat:
	just init
	just stow-device rainbow-cat
	just install-extras
	just install-rainbow-cat

# rainbow-cat system-level tweaks that need root (e.g. Lightspeed receiver drag fix)
install-rainbow-cat:
	bash scripts/rainbow-cat/install.sh

# silver-fox (Dell XPS 15 9500): base + device hypr overrides + gaming/GPU stack
init-silver-fox:
	just init
	just stow-device silver-fox
	just install-extras
	just install-silver-fox

# silver-fox system-level tweaks that need root (e.g. keyboard backlight timeout)
install-silver-fox:
	bash scripts/silver-fox/install.sh

# apply the default (dark) theme. Firewatch is pinned for both themes via the
# per-theme user backgrounds dir set up in stow-files-init, so omarchy-theme-bg-next
# auto-selects it here. Runs AFTER stow-symlinks-init so the waybar restart shim
# (stow/localbin) is active and the theme switch doesn't stack two waybars.
setup-theme:
	# Waybar runs as a uwsm scope (app-Hyprland-waybar-*.scope). The Arch waybar
	# package also ships waybar.service with Restart=on-failure; if anything ever
	# starts it, omarchy's `pkill -9` + relaunch on theme change trips the restart
	# AND spawns the scope -> two stacked bars. Mask it so it can never activate.
	systemctl --user mask waybar.service
	omarchy theme set "Everforest"
	# set Firewatch explicitly: `theme set` runs bg-next, which CYCLES past the
	# current wallpaper if Everforest is already active (idempotent re-runs). The
	# runtime toggle always switches themes so it lands on Firewatch via sort
	# order, but here we pin it directly.
	omarchy theme bg set ~/.config/omarchy/backgrounds/everforest/firewatch.png

# stow the per-device hypr overrides; idempotent
stow-device device:
	rm -f 														\
	~/.config/hypr/monitors-device.conf 	\
	~/.config/hypr/input-device.conf 		\
	~/.config/hypr/envs-device.conf 			\
	~/.config/hypr/layout-device.conf
	cd stow && stow -vt ~ hypr-{{device}}
	@echo "PASS stow-device {{device}}"

init-sudo:
	just install-apps-init

# Run commands that must not be done as sudo
init-user:
	just stow-files-init
	just stow-symlinks-init
	just setup-theme
	just install-user-apps-init
	just pull-repos

install-apps-init:
	sudo pacman -Rns --noconfirm spotify 				|| true
	sudo pacman -Rns --noconfirm obsidian 			|| true
	sudo pacman -Rns --noconfirm signal-desktop || true
	sudo pacman -Rns --noconfirm typora 				|| true
	sudo pacman -Rns --noconfirm 1password-cli	|| true
	sudo pacman -Rns --noconfirm 1password-beta	|| true
	rm -rf ~/.local/share/applications/Basecamp.desktop
	rm -rf ~/.local/share/applications/dropbox.desktop
	rm -rf ~/.local/share/applications/Figma.desktop
	rm -rf ~/.local/share/applications/Google\ Contacts.desktop
	rm -rf ~/.local/share/applications/Google\ Messages.desktop
	rm -rf ~/.local/share/applications/Google\ Photos.desktop
	rm -rf ~/.local/share/applications/HEY.desktop
	rm -rf ~/.local/share/applications/typora.desktop
	rm -rf ~/.local/share/applications/WhatsApp.desktop
	rm -rf ~/.local/share/applications/X.desktop
	rm -rf ~/.local/share/applications/Zoom.desktop
	@echo "INIT install-apps"
	just install-apps

# note: python already installed
# libnotify, gtk4-layer-shell,wl-clipboard, wtype dependencies of voxtype
# espeak-ng (phonemizer), uv (venv runner), jq (json) for kokoro tts (see setup-tts)
install-apps:
	sudo pacman -S --noconfirm --needed 	\
	aws-cli-v2														\
	caligula															\
	deno																	\
	espeak-ng															\
	gtk4-layer-shell											\
	helix																	\
	jq																		\
	libnotify															\
	opentofu															\
	python-pip														\
	podman																\
	python-pipx														\
	rsync																	\
	stow																	\
	uv																		\
	wl-clipboard													\
	wtype																	\
	zig
	curl -f https://zed.dev/install.sh | sh
	curl -fsSL https://vite.plus | sh
	@echo "PASS install-apps"

install-rust:
	# uninstall omarchy rust, it has no rustup
	sudo pacman -Rns --noconfirm rust	|| true
	# pacman for cargo-binstall so we dont build from source
	sudo pacman -S --noconfirm --needed \
	rustup cargo-binstall
	# bevy dependencies https://github.com/bevyengine/bevy/blob/latest/docs/linux_dependencies.md#arch--manjaro
	sudo pacman -S --noconfirm --needed \
	mold libx11 pkgconf alsa-lib pipewire-alsa
	# init stable
	rustup default stable
	# init nightly
	rustup default nightly
	# cargo install cargo-binstall
	rustup target add wasm32-unknown-unknown
	cargo binstall --no-confirm \
	cargo-edit 									\
	cargo-expand 								\
	cargo-generate							\
	cargo-lambda 								\
	cargo-watch 								\
	sccache											\
	worker-build								\
	wasm-opt
	cargo binstall --no-confirm \
	wasm-bindgen-cli 						\
	--version=0.2.106
	@echo "PASS install-rust"

install-user-apps-init:
	@echo "INIT install-user-apps"
	just install-user-apps
	just setup-voxtype
	just setup-tts

# base (CPU): download whisper model and install the user systemd service
# note: config.toml is managed via stow (built-in hotkey disabled there)
setup-voxtype:
	voxtype setup --download --model large-v3-turbo	|| true
	voxtype setup systemd														|| true
	just setup-voxtype-isolation
	@echo "PASS setup-voxtype"

# render gpu_isolation per power-state at daemon start (see scripts/voxtype-render-config.sh):
# isolate on battery so the dGPU can suspend between clips, stay warm on AC / desktop for
# instant capture. keeps ONE shared config.toml (dictionary etc.) — the flag is injected
# into a runtime copy the daemon reads via -c, never the stowed file. machine-agnostic:
# the script self-detects, so this drop-in is identical on every device.
setup-voxtype-isolation:
	chmod +x scripts/voxtype-render-config.sh
	mkdir -p ~/.config/systemd/user/voxtype.service.d
	printf '[Service]\nExecStartPre=%%h/me/os/scripts/voxtype-render-config.sh\nExecStart=\nExecStart=/usr/bin/voxtype -c %%t/voxtype/config.toml daemon\n' > ~/.config/systemd/user/voxtype.service.d/battery-isolation.conf
	systemctl --user daemon-reload || true
	systemctl --user restart voxtype.service || true
	@echo "PASS setup-voxtype-isolation"

# device: enable GPU (Vulkan) acceleration, otherwise large models run on CPU.
# hybrid-graphics laptops (silver-fox: Intel iGPU + NVIDIA dGPU) enumerate the slow
# iGPU as Vulkan device 0, so whisper picks it and takes ~30s/clip; pin whisper to
# the NVIDIA dGPU via a systemd drop-in. GGML_VK_VISIBLE_DEVICES restricts ggml to
# only that device, which the persistent daemon honors (verified), so the long-lived
# daemon uses the dGPU directly — no gpu_isolation needed (see voxtype config.toml).
setup-voxtype-gpu:
	#!/usr/bin/env bash
	set -uo pipefail
	sudo voxtype setup gpu --enable || true
	# find the ggml Vulkan index of the NVIDIA dGPU (0 on single-GPU machines like
	# rainbow-cat, 1 behind the iGPU on silver-fox). a 1s tone forces model init; grep -m1
	# SIGPIPEs transcribe right after the device list prints, before slow inference.
	# detect with gpu_isolation stripped: isolation hides the worker's ggml log, and
	# a partial config is rejected, so we strip just that line from the real config.
	wav="$(mktemp --suffix=.wav)"; cfg="$(mktemp --suffix=.toml)"
	ffmpeg -nostdin -hide_banner -loglevel error -f lavfi -i sine=frequency=220:duration=1 -ar 16000 -ac 1 "$wav" -y >/dev/null 2>&1 || true
	grep -v 'gpu_isolation' ~/.config/voxtype/config.toml > "$cfg"
	idx="$(timeout 30 voxtype -c "$cfg" transcribe "$wav" 2>&1 | grep -m1 -oP 'ggml_vulkan: \K[0-9]+(?= = NVIDIA)')"
	rm -f "$wav" "$cfg"
	idx="${idx:-0}"
	echo "voxtype: pinning whisper to NVIDIA ggml Vulkan device ${idx}"
	mkdir -p ~/.config/systemd/user/voxtype.service.d
	printf '[Service]\nEnvironment="VOXTYPE_VULKAN_DEVICE=nvidia"\nEnvironment="GGML_VK_VISIBLE_DEVICES=%s"\n' "$idx" > ~/.config/systemd/user/voxtype.service.d/gpu.conf
	systemctl --user daemon-reload || true
	# the daemon caches its backend/device at startup; restart so the dGPU takes effect
	# now (otherwise a fresh install keeps running on the iGPU until the next login)
	systemctl --user restart voxtype.service || true
	echo "PASS setup-voxtype-gpu"

# kokoro tts (highlight-to-speak, the reverse of voxtype dictation). ONE venv with the CUDA
# torch wheel — that same wheel runs CPU inference fine, so tts-server.sh just flips USE_GPU
# by power state (GPU on AC, CPU on battery so the dGPU can suspend), exactly like voxtype.
# cloned to ~/.local/share since it's a build artifact, not dotfiles. enabled as a user
# service that starts on login. SHIFT+PAUSE / SHIFT+INSERT toggle playback (bindings.conf).
setup-tts:
	#!/usr/bin/env bash
	set -uo pipefail
	chmod +x scripts/tts.sh scripts/tts-server.sh
	dir="$HOME/.local/share/kokoro-fastapi"
	[ -d "$dir/.git" ] || git clone --depth 1 https://github.com/remsky/Kokoro-FastAPI.git "$dir"
	cd "$dir"
	export USE_ONNX=false PYTHONPATH="$PWD:$PWD/api"
	uv venv
	uv pip install -e ".[gpu]"
	uv run --no-sync python docker/scripts/download_model.py --output api/src/models/v1_0
	mkdir -p ~/.config/systemd/user
	printf '[Unit]\nDescription=Kokoro TTS (FastAPI)\nAfter=graphical-session.target\n\n[Service]\nExecStart=%%h/me/os/scripts/tts-server.sh\nRestart=on-failure\nRestartSec=2\n\n[Install]\nWantedBy=default.target\n' > ~/.config/systemd/user/kokoro-tts.service
	systemctl --user daemon-reload || true
	systemctl --user enable --now kokoro-tts.service || true
	echo "PASS setup-tts"

# gaming / GPU stack — wanted on both rainbow-cat and silver-fox
install-extras:
	sudo pacman -S --noconfirm --needed cuda steam
	yay -S --noconfirm --needed xone-dkms xone-dongle-firmware
	just install-nvidia-deps
	# NOTE: silver-fox Optimus power management (dGPU off on battery) is a separate step.
	just setup-voxtype-gpu
	@echo "PASS install-extras"

# install NVIDIA driver and related 32-bit / Vulkan / OpenCL / performance tooling for gaming
install-nvidia-deps:
	sudo pacman -S --noconfirm --needed \
	nvtop \
	nvidia-open-dkms \
	nvidia-utils \
	lib32-nvidia-utils \
	nvidia-settings \
	vulkan-icd-loader \
	lib32-vulkan-icd-loader \
	gamemode \
	lib32-gamemode
	@echo "PASS install-nvidia-deps"

# apps from aur, usually more up-to-date than stable
install-user-apps:
	yay -S --noconfirm --needed		\
	ghostty												\
	google-chrome									\
	opencode-bin									\
	visual-studio-code-bin				\
	voxtype-bin
	@echo "PASS install-user-apps"

# global npm CLIs. install into the ~/.local prefix, NOT the default global: vite-plus
# owns the npm prefix and never puts -g bins on PATH, whereas ~/.local/bin is on PATH
# and node-version-agnostic. for playwright we drive the already-installed system Google
# Chrome via `--channel=chrome`, so we deliberately SKIP `playwright install` and never
# download a redundant bundled chromium.
install-npm-packages:
	npm install -g --prefix ~/.local playwright cf wrangler
	@echo "PASS install-npm-packages"

# required to run after fresh install or omarchy update
# this may break hyprland, if so run Menu > System > Rel
stow-symlinks-init:
	rm -rf 													\
	~/.config/alacritty							\
	~/.config/autostart							\
	~/.bashrc												\
	~/.cargo												\
	~/.config/ghostty								\
	~/.config/mimeapps.list 				\
	~/.config/obs-studio						\
	~/.config/opencode							\
	~/.config/starship.toml 				\
	~/.config/voxtype								\
	~/.config/waybar 								\
	~/.config/omarchy/branding			\
	~/.config/uwsm/default					\
	~/.config/zed											\
	~/.XCompose
	# fine-grained removal for dirs whose other contents we must preserve
	# (hypr ships other files; ~/.claude holds sessions/credentials/etc.)
	# NOTE: hyprland.conf is intentionally NOT removed here -- stow-symlinks
	# relinks it atomically; deleting it makes a live Hyprland regenerate an
	# "autogenerated" stub (the on-screen warning banner) and breaks the stow.
	rm -f													\
	~/.config/hypr/bindings.conf		\
	~/.config/hypr/looknfeel.conf		\
	~/.config/hypr/autostart.conf		\
	~/.config/hypr/hypridle.conf		\
	~/.config/hypr/hyprlock.conf		\
	~/.config/hypr/hyprsunset.conf	\
	~/.config/hypr/xdph.conf				\
	~/.config/fcitx5/conf/keyboard.conf	\
	~/.claude/settings.json
	@echo "INIT stow-symlinks"
	just stow-symlinks

stow-symlinks:
	# hyprland.conf is special: a LIVE Hyprland regenerates a default *stub* the
	# instant this file goes missing, and stow refuses to overwrite that regular
	# file -- which aborts the ENTIRE hypr package (and cascades init to failure).
	# Pre-create the symlink atomically (same relative target stow would use) so
	# the file is never absent and stow treats it as already-stowed. Without this,
	# `just init-*` fails when run from inside a running Hyprland session.
	mkdir -p ~/.config/hypr
	ln -sfn ../../me/os/stow/hypr/.config/hypr/hyprland.conf ~/.config/hypr/hyprland.conf
	# ensure fcitx5's conf/ exists so stow links keyboard.conf into it rather than
	# folding (symlinking) the whole dir and hiding fcitx5's app-managed state
	mkdir -p ~/.config/fcitx5/conf
	# omarchy's installer pre-creates ~/.agents/skills as a REAL dir (and drops an
	# `omarchy` skill symlink in it), which blocks stow from folding skills/ -- so
	# new skills created under ~/.agents/skills would be untracked real dirs. Fold
	# it ourselves: replace the dir with the symlink stow would create (safe -- the
	# only contents are stow-owned skill links plus the recreatable omarchy link),
	# then re-drop omarchy's link (it now lands in the repo via the fold; gitignored).
	mkdir -p ~/.agents
	rm -rf ~/.agents/skills
	ln -sfn ../me/os/stow/agents/.agents/skills ~/.agents/skills
	ln -sfn "${OMARCHY_PATH:-$HOME/.local/share/omarchy}/default/omarchy-skill" ~/.agents/skills/omarchy
	cd stow && stow -vt ~ \
	agents								\
	alacritty 						\
	autostart							\
	bashrc 								\
	cargo 								\
	claude								\
	fcitx5								\
	ghostty								\
	gtk									\
	hypr 									\
	mimeapps 							\
	obs										\
	omarchy 							\
	opencode							\
	starship 							\
	uwsm 									\
	voxtype								\
	waybar 								\
	xcompose								\
	zed
	@echo "PASS stow-symlinks"

# perform cp for assets which cannot be stowed
stow-files-init:
	# Solarized Light is a community theme: the light counterpart to Everforest
	# that the dark/light toggle (Super+Shift+T) and setup-theme depend on.
	test -d ~/.config/omarchy/themes/solarized-light || \
	git clone https://github.com/dfrico/omarchy-solarized-light-theme.git ~/.config/omarchy/themes/solarized-light
	# Pin the Firewatch wallpaper for both the dark and light theme. It lives in
	# the per-theme USER backgrounds dir (~/.config/omarchy/backgrounds/<theme>/),
	# which omarchy-theme-bg-next sorts BEFORE a theme's own backgrounds -- so it
	# is auto-selected on every switch to either theme (see setup-theme).
	mkdir -p ~/.config/omarchy/backgrounds/everforest ~/.config/omarchy/backgrounds/solarized-light
	curl -fsSL -o ~/.config/omarchy/backgrounds/everforest/firewatch.png \
	https://mrchantey-os.s3.us-west-2.amazonaws.com/assets/firewatch.png
	cp ~/.config/omarchy/backgrounds/everforest/firewatch.png \
	~/.config/omarchy/backgrounds/solarized-light/firewatch.png
	@echo "INIT stow-files"
	just stow-files

stow-files:
	@echo "PASS stow-files"

write_repositories := "
mrchantey/beet
mrchantey/beet-draft
mrchantey/beetmash
mrchantey/os
mrchantey/notes
bevyengine/bevy
"
# when unlikely to edit, pulled with --depth=1
read_repositories := "
alexjg/samod
basecamp/omarchy
ratatui/bevy_ratatui
openclaw/openclaw
badlogic/pi-mono
"

pull-repos:
	mkdir -p ~/me
	for repo in {{ replace(write_repositories, "\n", " ") }}; do \
		just pull-repo $repo; \
	done
	for repo in {{ replace(read_repositories, "\n", " ") }}; do \
		just pull-repo $repo --depth=1; \
	done
	mkdir -p ~/me/scratch
	touch ~/me/scratch/scratch.md
	@echo "PASS pull-repos"

# pull a repository, discarding errors
pull-repo repo *args:
	mkdir -p ~/me
	cd ~/me && git clone https://github.com/{{ repo }} {{args}} || true

init-infra:
	cd infra && npm install
	@echo "PASS init-infra"

deploy-infra:
	cd infra && npx sst deploy --stage prod
	@echo "PASS - deploy-infra"

remove-infra:
	cd infra && npx sst remove --stage prod
	@echo "PASS - remove-infra"

# upload a file to the s3 bucket
upload-file src dst:
	aws s3 cp {{ src }} s3://mrchantey-os/{{ dst }} --region us-west-2
	@echo "PASS - upload-file"

pre-reset:
	@set -e
	@for repo in {{ replace(write_repositories, "\n", " ") }}; do \
		just pre-reset-repo $repo || exit 1; \
	done
	@echo "PASS pre-reset"
	@echo "You are almost ready to reset your machine: \
	- ensure assets directories have been pushed: beet, beetmash \
	"

@pre-reset-repo repo:
	cd ~/me/$(basename {{ repo }}) && \
	(git diff --exit-code || (echo "Error: $(basename {{ repo }}) has uncommitted changes" && exit 1)) && \
	(git diff --exit-code --cached || (echo "Error: $(basename {{ repo }}) has staged uncommitted changes" && exit 1)) && \
	(test -z "$(git log @{u}..)" || (echo "Error: $(basename {{ repo }}) has unpushed commits" && exit 1))

# best-effort apply these settings for windows
@windows-push:
	cp -r ./stow/zed/.config/zed/. "/mnt/c/Users/$(cmd.exe /c 'echo %USERNAME%' 2>/dev/null | tr -d '\r')/AppData/Roaming/Zed"
	@echo "PASS windows-push"


### OPTIONAL

install-ollama:
	curl -fsSL https://ollama.com/install.sh | sh
	# general use
	ollama pull qwen3.5:9b
	# abliterated
	ollama pull huihui_ai/qwen3.5-abliterated:9b
