# silver-fox teardown: move the OS onto the 1TB KIOXIA

One drive for OS and home, same as rainbow-cat, no storage scripts. Both NVMes are LUKS and everything on them is reproducible from the repos. The slot does not matter: both drives are Gen3 and already link at full speed.

## 1. Before rebooting (this OS gets destroyed)

1. Push every repo under `~/me`. `just init` clones them all back.

    ```sh
    for d in ~/me/*/; do echo "== $d"; git -C "$d" status -sb; done
    ```

2. `~/me/scratch` is not a repo. Copy it off if you want it.
3. Anything else in `$HOME` you care about leaves the machine now.
4. Have the Omarchy USB. Decide the LUKS passphrase.

## 2. Install

1. Reboot. F12 at the Dell logo, boot the USB.
2. Disk picker: choose **KIOXIA 1024GB (953.9G)**. NOT the SK hynix 256GB.
3. Hostname `silver-fox`, user `pete`. Finish, reboot, pull the USB.

## 3. First boot

If the old install on the SK hynix comes up instead, reboot, F12, pick the other entry. Confirm `/` is on the 953.9G KIOXIA:

```sh
lsblk -o NAME,SIZE,MODEL,MOUNTPOINTS
```

Only then blank the SK hynix. This resolves it by serial, so a wrong guess fails instead of wiping the new OS:

```sh
sudo wipefs -a /dev/$(lsblk -dno NAME,SERIAL | awk '$2=="CY12N087910403351"{print $1}')
```

## 4. Rebuild

```sh
mkdir ~/me && cd ~/me && git clone https://github.com/mrchantey/os.git && cd os && sudo pacman -S --noconfirm just
gh auth login
just init-silver-fox
```

Then the README "Additional Steps", and log back into Claude, Zed, Chrome, Element, Thunderbird, Steam. Delete this file when done.
