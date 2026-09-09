# Silver Fox handover: XPS 15 9500 to Precision 7560

A runbook for the agent on the new machine. Inventory in this file was captured from the live XPS on 2026-09-09, before the drive was pulled.

## The plan

The Dell XPS 15 9500 was gutted. Its 1TB NVMe SSD and 2x16GB DDR4-2933 SODIMMs moved into a Dell Precision 7560, and the old chassis was binned.

The Precision has **its own drive**, which gets a **fresh Omarchy install** from a USB stick. The transplanted XPS drive goes in as a **secondary drive**. Nothing is being migrated by booting the old install. Config comes back from `github.com/mrchantey/os` via `just`, and the old drive is only a source for the handful of things git does not hold.

Once that recovery is verified, the old drive gets wiped and reused as plain storage.

**Do not wipe the old drive until Phase 3 is complete and verified.** It is the only remaining copy of several things listed below.

## Phase 1: BIOS, then fresh install

Two settings must change before the USB installer will work. Both are Dell defaults that break Linux installs:

- **SATA/NVMe Operation to AHCI/NVMe.** Dell ships this as "RAID On", under which the installer sees no disks at all and looks broken.
- **Secure Boot disabled.**

Then install Omarchy from the USB stick onto **the Precision's own drive**. If both drives are fitted at this point, be very careful about the install target. Safest is to install with only the Precision's own drive fitted, and add the old drive afterwards.

Set the hostname to **`silver-fox`**. The name is being kept deliberately, and `stow/hypr-silver-fox` plus `just init-silver-fox` depend on it.

## Phase 2: Rebuild from the repo

```bash
git clone https://github.com/mrchantey/os ~/me/os
cd ~/me/os
just init
just init-silver-fox
```

Read `CLAUDE.md` in that repo first. `just init` runs `install-mise-tools` before `init-user` on purpose, because it is what installs `uv`, which `setup-tts` then needs.

Note that `just init-*` fails if run from inside a running Hyprland session.

`just pull-repos` re-clones the tracked repositories. See "Gaps found" below, several repos in `~/me` are not on its lists.

## Phase 3: Recover what git does not hold

Fit the old drive if it is not already in. Identify it before touching anything:

```bash
lsblk -o NAME,SIZE,MODEL,SERIAL
```

The old drive is **KIOXIA KXG60ZNV1T02, serial `X93ZZ00TK84L`, 953.9G**. Match the serial, not the device node. Depending on which M.2 slot it lands in it may come up as `nvme0n1` or `nvme1n1`, and the node numbering is not stable across the two drives.

Unlock and mount it read-only. The passphrase is the same one that was typed at every boot on the old machine:

```bash
sudo cryptsetup open --readonly /dev/nvmeXn1p2 old
sudo mkdir -p /mnt/old
sudo mount -o ro,subvol=@home /dev/mapper/old /mnt/old
```

Read-only is deliberate. There is no reason to write to this drive, and it removes any chance of damaging the only copy.

### What actually needs copying

Most of the home directory is disposable. `Documents`, `Music`, `Videos`, `Projects` and `Work` were all empty. There are no SSH private keys and no GPG keyring. Every git repo was clean and pushed except one. What is left:

**1. The `.env` files. This is the important one.** They are gitignored, so `just pull-repos` will not bring them back, and they hold live credentials that exist nowhere else:

| File | Holds |
| --- | --- |
| `me/os/.env` | AWS access key, secret, region. Needed by `just push-assets`, `pull-assets`, `deploy-infra`. |
| `me/beet/.env` | Anthropic, OpenAI and Gemini API keys, Cloudflare account/token/zone, R2 access keys, AWS keys, Bedrock bearer token, `BEET_SSH_HOST_KEY`. |
| `me/hackathon/.env` | ATProto PDS URL, two account handles with passwords and DIDs, Cloudflare credentials, AWS keys. |
| `me/beet_esp/.env` | WiFi SSID, WiFi password, static IP, remote URL. |

Copy each to the matching path under the new `~/me`. Do not commit them, they are gitignored for a reason.

**2. `me/hackathon/`, 337M, not a git repo.** No remote, no other copy. Either take the whole directory or confirm with the user that it is disposable.

**3. `me/worktrees/`, 17G, not a git repo.** Almost certainly regenerable git worktrees rather than original work. Check before assuming, but do not blindly copy 17G.

**4. `me/notes/` had uncommitted deletions** (`backyard.md` and two files under `computers/assets/`). The deletions were never committed, so those files still exist in the pushed repo. Ask whether the deletion was intended, then either commit it on the new machine or leave it.

**5. `Pictures/`, 1.6M**, seven screenshots. `Downloads/`, 48M, five items. Small enough to just copy and triage later.

**6. `~/.config/gh/hosts.yml`** is the GitHub CLI token. Not worth copying, just run `gh auth login` on the new machine.

Once everything is across, verify it, then unmount:

```bash
sudo umount /mnt/old
sudo cryptsetup close old
```

## Phase 4: Wipe and repurpose the old drive

Only after Phase 3 is verified.

**Confirm the serial one more time.** This is the single most dangerous step in this document. Getting the device node wrong here destroys the fresh install:

```bash
lsblk -o NAME,SIZE,MODEL,SERIAL,MOUNTPOINT
```

Confirm the target reads serial `X93ZZ00TK84L` and has nothing mounted from it. Show this output to the user and get explicit confirmation of the device node before running anything below.

Then, fastest to most thorough:

```bash
# instant: destroys the LUKS keyslots, the data becomes unrecoverable immediately
sudo cryptsetup luksErase /dev/nvmeXn1p2

# or a full drive reset, better for reuse since it also restores SSD write performance
sudo nvme format /dev/nvmeXn1 -s 2      # crypto erase; fall back to -s 1 if unsupported
```

Then lay down fresh storage:

```bash
sudo parted /dev/nvmeXn1 mklabel gpt
sudo parted -a optimal /dev/nvmeXn1 mkpart primary 0% 100%
sudo mkfs.btrfs -L storage /dev/nvmeXn1p1
```

Add an `/etc/fstab` entry by UUID, not by device node, since the numbering is not stable.

`rm -rf /` is not a wipe and was never the answer. It cannot run without `--no-preserve-root`, it destroys a running system halfway through, and it leaves the data recoverable.

## Gaps found in the repo tooling

Surface these to the user, do not fix them unprompted.

`just pull-repos` clones from two lists in the justfile. These repos exist in `~/me` and are on **neither** list, so a fresh machine will not get them. All are clean and pushed to GitHub, so nothing is lost, but they will not reappear on their own:

`archive`, `beet_esp`, `bevyhub`, `forky`, `personal`

`beet-draft` is on `write_repositories` but was not present locally.

`just pre-reset` exists and checks that the `write_repositories` are clean. Worth running, though it is less critical here than in a normal reset, since the old drive is being kept rather than destroyed up front.

## Hardware notes for the new machine

The Precision 7560 is the 2021 Tiger Lake-H model. DDR4-3200, so the XPS's DDR4-2933 sticks run fine at 2933. Four SODIMM slots, but only two are reachable under the base cover, the other two are under the keyboard. If the Precision shipped with ECC memory and a Xeon, ECC and non-ECC cannot be mixed, so it is a full swap rather than a top-up.

GPU is a T1200 or an RTX A2000/A3000/A4000/A5000, all covered by `nvidia-open-dkms`. iGPU is Tiger Lake, `i915`. Nothing special needed, a fresh install handles it.

The Precision has a **trackpoint**, which the XPS did not. `stow/hypr-silver-fox/.config/hypr/monitors.lua`, `input-device.lua` and `layout-device.lua` are all still tuned to the XPS panel and touchpad.

**The user is handling those three files themselves.** Run `hyprctl monitors all` and `hyprctl devices`, report the connector name, native resolution, refresh rate and any unrecognised input devices, then wait to be asked. Do not edit them unprompted.
