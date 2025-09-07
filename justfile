default:
	just --list

init:
	just remove-bloatware
	just prepare-stow-symlinks
	just stow-symlinks
	just pull-repos

remove-bloatware:
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
	@echo "Bloatware removed"

# run this once on new install
prepare-stow-symlinks:
  rm -rf 													\
  ~/.config/hypr/input.conf 			\
  ~/.config/hypr/bindings.conf 		\
  ~/.config/hypr/monitors.conf 		\
  ~/.config/mimeapps.list 				\
  ~/.config/zed 									\
  ~/.bashrc
  @echo "symlink stow prepared"

# initialize stow, the settings may freak out for a sec
# just save a file like hyprland.conf again and should be fine
stow-symlinks:
  cd stow && stow -vt ~ \
  bashrc 								\
  hypr 									\
  mimeapps 							\
  zed
  @echo "symlinks stowed"
  touch ~/.config/hypr/hyprland.conf

# perform cp for assets which cannot be stowed
# because we dont own the
stow-files:
	mkdir -p ~/.config/omarchy/themes/everforest/backgrounds
	curl -fsSL -o ~/.config/omarchy/themes/everforest/backgrounds/firewatch.png \
	https://mrchantey-os.s3.us-west-2.amazonaws.com/backgrounds/firewatch.png
	@echo "files stowed"

pull-repos:
	mkdir ~/me || true
	cd ~/me && git clone https://github.com/mrchantey/beet 				|| true
	cd ~/me && git clone https://github.com/mrchantey/beet-draft	|| true
	cd ~/me && git clone https://github.com/mrchantey/beetmash		|| true
	cd ~/me && git clone https://github.com/mrchantey/notes				|| true
	cd ~/me && git clone https://github.com/bevyengine/bevy				|| true
	@echo "Repos pulled"


init-infra:
	cd infra && npm install
	@echo "Infra initialized"

deploy-infra:
	cd infra && npx sst deploy --stage prod
	@echo "Infra deployed"

remove-infra:
	cd infra && npx sst remove --stage prod
	@echo "Infra removed"

# upload a file to the s3 bucket
upload-file src dst:
	aws s3 cp {{src}} s3://mrchantey-os/{{dst}} --region us-west-2