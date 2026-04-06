# OS

My [Omarchy](https://omarchy.org/) config.

This command will:
1. pull this repo into `~/me/os`
2. ensure just is installed
3. run the init command
```sh
mkdir ~/me && cd ~/me && git clone https://github.com/mrchantey/os.git && cd os && sudo pacman -S --noconfirm just && just init
```

See [./additional-steps.md](./additional-steps.md)
