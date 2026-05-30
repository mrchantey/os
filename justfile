default:
	just --list

restart-voxtype:
	systemctl --user restart voxtype.service

# device-agnostic base; run this once per install (or a device recipe below)
init:
	just init-sudo
	just init-user
	just install-rust
	chmod +x scripts/*/startup.sh

# blackboy (desktop): base + device hypr overrides + gaming/GPU stack
init-blackboy:
	just init
	just stow-device blackboy
	just install-extras

# silver-fox (Dell XPS 15 9500): base + device hypr overrides + gaming/GPU stack
init-silver-fox:
	just init
	just stow-device silver-fox
	just install-extras

# stow the per-device hypr overrides; idempotent
stow-device device:
	rm -f 												\
	~/.config/hypr/monitors.conf 	\
	~/.config/hypr/input.conf 		\
	~/.config/hypr/envs.conf 			\
	~/.config/hypr/layout.conf
	cd stow && stow -vt ~ hypr-{{device}}
	@echo "PASS stow-device {{device}}"

init-sudo:
	just install-apps-init

# Run commands that must not be done as sudo
init-user:
	just stow-files-init
	just stow-symlinks-init
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
install-apps:
	sudo pacman -S --noconfirm --needed 	\
	aws-cli-v2														\
	caligula															\
	deno																	\
	gtk4-layer-shell											\
	helix																	\
	libnotify															\
	opentofu															\
	python-pip														\
	podman																\
	python-pipx														\
	rsync																	\
	stow																	\
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
	wasm-opt
	cargo binstall --no-confirm \
	wasm-bindgen-cli 						\
	--version=0.2.106
	@echo "PASS install-rust"

install-user-apps-init:
	@echo "INIT install-user-apps"
	just install-user-apps
	just setup-voxtype

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
	# blackboy, 1 behind the iGPU on silver-fox). a 1s tone forces model init; grep -m1
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

# gaming / GPU stack — wanted on both blackboy and silver-fox
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
	cd stow && stow -vt ~ \
	agents								\
	alacritty 						\
	autostart							\
	bashrc 								\
	cargo 								\
	claude								\
	fcitx5								\
	ghostty								\
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
	mkdir -p ~/.config/omarchy/themes/everforest/backgrounds
	curl -fsSL -o ~/.config/omarchy/themes/everforest/backgrounds/firewatch.png \
	https://mrchantey-os.s3.us-west-2.amazonaws.com/backgrounds/firewatch.png
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
