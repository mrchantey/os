# Collection of commands to run, with the following format
# hello-world-init:
#		@echo "this is intended to only be run once per os install, but shouldnt fail otherwise"
#		@echo "INIT hello-world"
#		just hello-world
#
# hello-world:
#		@echo "this command is generally less intensive may be edited and run again"
#		@echo "PASS hello-world"

default:
	just --list

# only run this once per install
init:
	just init-sudo
	just init-user
	just install-rust
	just install-nix
	chmod +x startup.sh

init-sudo:
	just install-apps-init

# Run commands that must not be done as sudo
init-user:
	just stow-files-init
	just stow-symlinks-init
	just install-user-apps-init
	just pull-repos-init

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
	curl -f https://zed.dev/install.sh | sh

install-apps:
	sudo pacman -S --noconfirm --needed 	\
	aws-cli-v2														\
	cuda																	\
	deno																	\
	helix																	\
	steam																	\
	stow																	\
	zig
	@echo "PASS install-apps"

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

install-ollama:
	curl -fsSL https://ollama.com/install.sh | sh
	# tool call
	ollama pull functiongemma:270m-it-fp16
	# chat
	ollama pull huihui_ai/qwen3-abliterated:14b

# https://nixos.org/download/

# do NOT use pacman it will setup invalid build groups difficult to clean up
install-nix:
	sh <(curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install) --daemon

# nix-shell -p nix-info --run "nix-info -m"

install-rust:
	# uninstall omarchy rust, it has no rustup
	sudo pacman -Rns --noconfirm rust	|| true
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
	--version=0.2.100
	@echo "PASS install-rust"

install-user-apps-init:
	@echo "INIT install-user-apps"
	just install-user-apps

install-user-apps:
	yay -S --noconfirm --needed		\
	google-chrome									\
	visual-studio-code-bin				\
	xone-dkms											\
	xone-dongle-firmware
	@echo "PASS install-user-apps"

# opencode-bin									\
# required to run after fresh install or omarchy update

# this may break hyprland, if so run Menu > System > Rel
stow-symlinks-init:
	rm -rf 													\
	~/.config/alacritty							\
	~/.bashrc												\
	~/.cargo												\
	~/.config/hypr 									\
	~/.config/mimeapps.list 				\
	~/.config/starship.toml 				\
	~/.config/waybar 								\
	~/.config/omarchy/branding			\
	~/.config/uwsm/default					\
	~/.config/zed											\
	~/.XCompose
	@echo "INIT stow-symlinks"
	just stow-symlinks

stow-symlinks:
	cd stow && stow -vt ~ \
	alacritty 						\
	bashrc 								\
	cargo 								\
	hypr 									\
	mimeapps 							\
	omarchy 							\
	starship 							\
	uwsm 									\
	waybar 								\
	xcompose								\
	zed
	touch ~/.config/hypr/hyprland.conf
	@echo "PASS stow-symlinks"

# perform cp for assets which cannot be stowed

# because we dont own the
stow-files-init:
	mkdir -p ~/.config/omarchy/themes/everforest/backgrounds
	curl -fsSL -o ~/.config/omarchy/themes/everforest/backgrounds/firewatch.png \
	https://mrchantey-os.s3.us-west-2.amazonaws.com/backgrounds/firewatch.png
	@echo "INIT stow-files"
	just stow-files

stow-files:
	@echo "PASS stow-files"

pull-repos-init:
	gh auth login
	@echo "INIT pull-repos"
	just pull-repos

repositories := "mrchantey/beet mrchantey/beet-draft mrchantey/beetmash mrchantey/notes bevyengine/bevy"

pull-repos:
	mkdir -p ~/me
	for repo in {{ repositories }}; do \
		just pull-repo $repo; \
	done
	mkdir -p ~/me/scratch
	touch ~/me/scratch/scratch.md
	cd ~/me && git clone https://github.com/basecamp/omarchy --depth=1
	@echo "PASS pull-repos"

pull-repo repo:
	mkdir -p ~/me
	cd ~/me && git clone https://github.com/{{ repo }} || true

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
	@for repo in {{ repositories }}; do \
		just pre-reset-repo $repo || exit 1; \
	done
	@just pre-reset-repo mrchantey/os || exit 1;
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


startup:
	./startup.sh
