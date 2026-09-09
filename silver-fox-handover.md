# Silver Fox handover: XPS 15 9500 to Precision 7560

A runbook for the agent on the new machine. Inventory here was captured from the live XPS on 2026-09-09, before the drive was pulled.

## The plan

The Dell XPS 15 9500 was gutted. Its 1TB NVMe SSD and 2x16GB DDR4-2933 SODIMMs moved into a Dell Precision 7560, and the old chassis was binned.

The Precision has **its own drive**, which gets a **fresh Omarchy install** from a USB stick. Config is restored from `github.com/mrchantey/os` via `just`.

The transplanted XPS drive is **wiped and reused as blank secondary storage**. This is a deliberate decision, confirmed by the user. Nothing is being recovered off it. Do not propose mounting it, unlocking it, or rescuing anything from it. The old install, the old home directory and the credentials listed below are all being deliberately destroyed.

Because nothing is being read off the drive, **the LUKS passphrase is not needed at any point**. Every wipe method below operates without authenticating.

## Phase 1: BIOS, then fresh install

Two settings must change before the USB installer will work. Both are Dell defaults that break Linux installs:

- **SATA/NVMe Operation to AHCI/NVMe.** Dell ships this as "RAID On", under which the installer sees no disks at all and looks broken.
- **Secure Boot disabled.**

Install Omarchy onto **the Precision's own drive**. Safest is to install with only that drive fitted and add the old drive afterwards, which sidesteps any chance of targeting the wrong disk.

Set the hostname to **`silver-fox`**. The name is being kept deliberately, and `stow/hypr-silver-fox` plus `just init-silver-fox` depend on it.

## Phase 2: Rebuild from the repo

```bash
git clone https://github.com/mrchantey/os ~/me/os
cd ~/me/os
just init
just init-silver-fox
```

Read `CLAUDE.md` in that repo first. `just init` runs `install-mise-tools` before `init-user` on purpose, because it is what installs `uv`, which `setup-tts` then needs. `just init-*` fails if run from inside a running Hyprland session.

`just pull-repos` re-clones the tracked repositories. See "Gaps in the repo tooling" below, several repos are not on its lists.

## Phase 3: Wipe the old drive

**Identify the target first. This is the one genuinely dangerous step in this document.** There is no read-only mount step to catch a mistake, so identification is the only guard, and aiming any of these commands at the wrong disk destroys the fresh install.

With two NVMes fitted the old drive may enumerate as `nvme0n1` or `nvme1n1` depending on slot. Node numbering is not stable. Match on these instead, all captured from the live machine and all readable without the passphrase:

| Identifier | Value |
| --- | --- |
| Model | `KXG60ZNV1T02 NVMe KIOXIA 1024GB` |
| Serial | `X93ZZ00TK84L` |
| Size | 953.9G |
| LUKS UUID (p2) | `d1f3ce3e-a7cb-4879-ad79-859d74ace903` |
| PARTUUID (p2) | `6ef9fb89-328b-4f59-9558-b85021e04159` |
| ESP UUID (p1) | `0AD1-5CFF` |
| Layout | p1 2G vfat, p2 951.9G crypto_LUKS |

```bash
lsblk -o NAME,SIZE,FSTYPE,UUID,PARTUUID,MODEL,SERIAL,MOUNTPOINT
```

Confirm the serial reads `X93ZZ00TK84L` and that nothing is mounted from it. **Show this output to the user and get explicit confirmation of the device node before running anything below.**

Then pick one, fastest to most thorough:

```bash
# instant. Destroys the LUKS keyslots, data becomes unrecoverable immediately.
# Needs no passphrase, only a typed YES confirmation.
sudo cryptsetup luksErase /dev/nvmeXn1p2

# full drive reset. Preferred here, since it also restores SSD write performance
# before the drive is reused.
sudo nvme format /dev/nvmeXn1 -s 2      # crypto erase; fall back to -s 1 if unsupported
```

`rm -rf /` is not a wipe and was never the answer. It cannot run without `--no-preserve-root`, it destroys a running system halfway through, and it leaves data recoverable.

## Phase 4: Repurpose as storage

```bash
sudo parted /dev/nvmeXn1 mklabel gpt
sudo parted -a optimal /dev/nvmeXn1 mkpart primary 0% 100%
sudo mkfs.btrfs -L storage /dev/nvmeXn1p1
```

Add an `/etc/fstab` entry **by UUID, not by device node**, since numbering is not stable across the two drives.

## Credentials destroyed with the drive

Four gitignored `.env` files went with the wipe. `.env` is in `.gitignore`, so none of these values were ever pushed and none are recoverable. They need reissuing from their providers when the relevant project is next touched. Nothing here is urgent, and rotating keys that were sitting on a retired drive is good hygiene regardless.

**`me/beet/.env`** and **`me/beet_esp/.env`** have tracked `.env.example` siblings in the repo, so their variable names come back with the clone.

**`me/os/.env`** and **`me/hackathon/.env`** have no `.env.example`. This note is the only remaining record of their contents:

| File | Variables | Reissue from |
| --- | --- | --- |
| `me/os/.env` | `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION` | AWS IAM console. Needed by `just push-assets`, `pull-assets`, `deploy-infra`. |
| `me/hackathon/.env` | `PDS_URL`, `EVENT_SLUG`, `EVENT_HASHTAG`, `PAM_HANDLE`, `PAM_EMAIL`, `PAM_PASSWORD`, `PAM_DID`, `BOB_HANDLE`, `BOB_EMAIL`, `BOB_PASSWORD`, `BOB_DID`, `CLOUDFLARE_ACCOUNT_ID`, `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ZONE_ID`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION` | ATProto account password resets, Cloudflare dashboard, AWS IAM. |

For reference, `me/beet/.env` held Anthropic, OpenAI and Gemini API keys, Cloudflare account/token/zone, R2 access keys, AWS keys, a Bedrock bearer token and `BEET_SSH_HOST_KEY`. `me/beet_esp/.env` held WiFi SSID, password, static IP and a remote URL.

Also gone, and confirmed by the user as not a concern: `me/hackathon/` (337M, was not a git repo), `me/worktrees/` (17G, regenerable git worktrees), uncommitted deletions in `me/notes/`, and `Pictures/` plus `Downloads/` (a few screenshots, a photo zip and a Dell BIOS installer).

There were no SSH private keys and no GPG keyring on the machine, so nothing of that kind was lost. `gh auth login` re-establishes GitHub access.

## Gaps in the repo tooling

Surface these to the user, do not fix them unprompted.

`just pull-repos` clones from two lists in the justfile. These repos existed in `~/me` and are on **neither** list, so a fresh machine will not get them. All were clean and pushed to GitHub, so nothing is lost, but they will not reappear on their own:

`archive`, `beet_esp`, `bevyhub`, `forky`, `personal`

`beet-draft` is on `write_repositories` but was not present locally.

## Hardware notes

The Precision 7560 is the 2021 Tiger Lake-H model. DDR4-3200, so the XPS's DDR4-2933 sticks run fine at 2933. Four SODIMM slots, but only two are reachable under the base cover, the other two are under the keyboard. If the Precision shipped with ECC memory and a Xeon, ECC and non-ECC cannot be mixed, so it is a full swap rather than a top-up.

GPU is a T1200 or an RTX A2000/A3000/A4000/A5000, all covered by `nvidia-open-dkms`. iGPU is Tiger Lake, `i915`. A fresh install handles both.

The Precision has a **trackpoint**, which the XPS did not. `stow/hypr-silver-fox/.config/hypr/monitors.lua`, `input-device.lua` and `layout-device.lua` are all still tuned to the XPS panel and touchpad.

**The user is handling those three files themselves.** Run `hyprctl monitors all` and `hyprctl devices`, report the connector name, native resolution, refresh rate and any unrecognised input devices, then wait to be asked. Do not edit them unprompted.
