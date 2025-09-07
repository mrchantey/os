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

init:
	just init-user
	sudo just init-sudo

init-sudo:
	just install-apps-init

# Run commands that must not be done as sudo
init-user:
	just stow-files-init
	just stow-symlinks-init
	just pull-repos-init
	just install-user-apps-init

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

install-apps:
	pacman -S --noconfirm --needed 	\
	aws-cli-v2											\
	stow														\
	zed
	just install-rust
	@echo "PASS install-apps"

install-rust:
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
	cargo-lambda 								\
	cargo-watch 								\
	leptosfmt										\
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
	google-chrome
	@echo "PASS install-user-apps"

# this may break hyprland, if so run Menu > System > Relaunch
stow-symlinks-init:
  rm -rf 													\
  ~/.bashrc												\
  ~/.cargo												\
  ~/.config/hypr 									\
  ~/.config/mimeapps.list 				\
  ~/.config/starship.toml 				\
  ~/.config/zed
  @echo "INIT stow-symlinks"
  just stow-symlinks

stow-symlinks:
  cd stow && stow -vt ~ \
  bashrc 								\
  cargo 								\
  hypr 									\
  mimeapps 							\
  starship 							\
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


pull-repos:
	mkdir ~/me || true
	cd ~/me && git clone https://github.com/mrchantey/beet 				|| true
	cd ~/me && git clone https://github.com/mrchantey/beet-draft	|| true
	cd ~/me && git clone https://github.com/mrchantey/beetmash		|| true
	cd ~/me && git clone https://github.com/mrchantey/notes				|| true
	cd ~/me && git clone https://github.com/bevyengine/bevy				|| true
	@echo "PASS pull-repos"


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
	aws s3 cp {{src}} s3://mrchantey-os/{{dst}} --region us-west-2
	@echo "PASS - upload-file"
