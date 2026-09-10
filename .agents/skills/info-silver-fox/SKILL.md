---
name: info-silver-fox
description: >
  The standing record of `silver-fox`, the Dell Precision 7560 laptop that this
  ~/me/os config runs on: measured hardware inventory, the per-device config
  decisions and why they were made, what is installed versus still pending, and
  the machine-specific traps. Read this before changing anything under
  stow/hypr-silver-fox/ or scripts/silver-fox/, before answering "what hardware
  is this", and before assuming a silver-fox fact that predates 2026-09-10 --
  the name was inherited from a Dell XPS 15 9500 that is dead and gone, so a lot
  of older notes describe different hardware. Update this skill whenever the
  machine's hardware or device config changes.
---

# silver-fox — Dell Precision 7560

Rebuilt from a fresh Omarchy install on **2026-09-10**, replacing a Dell XPS 15
9500 of the same name that died of a motherboard power fault. The hostname is
unchanged deliberately: `stow/hypr-silver-fox` and `just init-silver-fox` both
key off it.

**Everything below was measured on the machine, not read off a spec sheet.**

## Hardware

| | |
| --- | --- |
| Model | Dell Precision 7560, SKU 0A69, rev A01 |
| BIOS | 1.48.0 (2026-05-31) |
| CPU | i7-11850H, 8c/16t, Tiger Lake-H |
| RAM | 64GB (62GiB usable) |
| dGPU | NVIDIA RTX A2000 Mobile, GA107GLM `10de:25b8`, 4GB GDDR6 |
| iGPU | Intel TigerLake-H UHD `8086:9a60` |
| Panel | BOE 0x08CF on eDP-1, **1920x1080**, 340x190mm, ~143 DPI, 16:9 |
| Audio | Realtek on HDA Intel PCH (card 0) |
| Pointing | touchpad only, **no pointing stick** |

The panel is the FHD SKU. Its only modes are 1920x1080@60 and @48 — there is no
4K here, and no 16:10. That single fact invalidates most XPS-era display config.

### The two GPUs drive different ports

From `/sys/class/drm`:

- **NVIDIA (card1)**: `HDMI-A-1`, `DP-1`, `DP-2`, `DP-3` — the physical HDMI and mDP ports
- **Intel (card2)**: `eDP-1`, `DP-4`, `DP-5` — the internal panel and the USB-C DP-alt ports

This is a genuine departure from the XPS, whose dGPU drove no displays at all.
Plugging into HDMI or mDP wakes the dGPU and keeps it awake, which costs battery
and defeats the on-battery dGPU-suspend behaviour that voxtype and the TTS server
both key off. **Prefer USB-C for a projector when on battery.**

The compositor runs on the Intel iGPU. The NVIDIA card is for CUDA and per-app
PRIME offload:

```bash
__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia <app>
```

Never force `LIBVA_DRIVER_NAME=nvidia`. Quattro's `default/hypr/nvidia.lua`
detects the hybrid setup and sets the render env itself, so there is no
`envs-device.lua` and there should not be one.

## Disks

Two NVMes are fitted. **The running system is on the SMALLER, HIGHER-numbered
one** — exactly the trap to watch for:

| Node | Device | Size | Role |
| --- | --- | --- | --- |
| `nvme1n1` | SK hynix BC711, serial `CY12N087910403351` | 238.5G | **live system**, LUKS + btrfs |
| `nvme0n1` | KIOXIA KXG60ZNV1T02, serial `X93ZZ00TK84L` | 953.9G | transplanted from the XPS, still LUKS, **untouched** |

The KIOXIA is slated to be wiped and reused as blank storage. That has not been
started. Node numbering is not stable across boots — see `old-drive.md` for the
identification table and the wipe procedure, and read it before touching either
disk.

## Per-device config, and why

`stow/hypr-silver-fox/` holds three modules, stowed by `just stow-device silver-fox`.

**`monitors.lua`** — eDP-1 pinned to `1920x1080@60` at **`scale = 1`**, with
`GDK_SCALE=1`. Omarchy's `scale = "auto"` picks **1.5** on this panel, which
leaves a 1280x720 logical desktop; scale 1 gives 1920x1080 logical, near-identical
to the effective 1920x1200 the XPS's 4K panel gave at scale 2. It is a 1080p
panel, so there is no HiDPI to serve and no fractional-scaling blur to accept.
Bump to 1.25 if text is too small; do not go back to `"auto"`.

Also holds the fallback auto-mirror rule (`output = ""`), which catches whatever
an external cable enumerates as.

**`input-device.lua`** — touchpad `natural_scroll` and `clickfinger_behavior`.
Note the two libinput nodes, `dell0a69:00-0488:120a-touchpad` and
`...-mouse`: same HID device, one physical touchpad. The `-mouse` node is not a
trackpoint and needs no configuration.

**`layout-device.lua`** — master layout, `new_status = "master"`. New windows fill
the screen. On one 1080p panel there is no room to give away, which is why this
differs from rainbow-cat's centered column.

### Deleted with the XPS

`scripts/silver-fox/present-mirror` and `mirror-watch.sh` forced both displays to
1080p on hotplug. They existed solely because the XPS's 16:10 panel was squished
~11% when mirrored to a 16:9 projector. This panel is natively 16:9 1080p, so the
plain mirror rule already produces a 1:1 image. Nothing was key-bound to them.

### `scripts/silver-fox/install.sh` is currently a no-op

Both of its root-level fixes are inert on this hardware, and both are kept anyway:

- **Keyboard backlight timeout.** No `dell::kbd_backlight` LED exists.
  `dell_laptop` *is* loaded, so this is not a missing module — the 7560's
  backlight is EC-owned. Change the timeout in the BIOS under
  System Configuration > Keyboard Backlight.
- **S3 deep sleep.** `/sys/power/mem_sleep` reads `[s2idle]` with no `deep`.
  Kept because suspend/resume is **untested** here and the fix is one BIOS
  setting away. If this machine starts hard-resetting on resume, look for
  Power Management > Sleep Mode in the BIOS, then re-run the script.

### Microphone gain — carried over intact

`scripts/silver-fox/startup.sh` sets `wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 0.13`.
The Realtek codec powers on with `Capture` at 63/+30dB stacked on
`Internal Mic Boost` at 3/+30dB, which saturates the ADC and wrecks voxtype
accuracy. Verified on this machine: 0.13 lands on +6.75dB with boost off, the
same mapping the XPS had. WirePlumber owns this — `amixer` calls get clobbered
when it initialises the card at login.

## State as of 2026-09-10

Omarchy `4.0.3-1` (`omarchy-version`), kernel `7.2.3-arch1-3`.

**Working:** all stow packages linked; mise runtimes (node, deno, zig, python) and
the wrangler/cf/claude-agent-acp wrappers; Everforest theme with the Firewatch
wallpaper; Never-Lost-Rainbow cursor; transcribe and tts helpers on PATH; Kokoro
TTS built, enabled and **running on CUDA** (the NVIDIA driver, `nvidia-open-dkms`
610.57.04, came with the fresh Omarchy install); `just pull-repos` clones cleanly
including private repos.

**Pending, needs root:** `just init-silver-fox-sudo` — one command, one password
prompt. Covers the pacman/yay app installs, voxtype, rust, the CUDA/steam extras
and the device script. Until it runs there is no ghostty, chrome, vscode,
voxtype, rustup or cuda toolkit on this machine.

## Traps

- **Do not trust pre-2026-09-10 silver-fox notes.** They describe the XPS: 4K
  16:10 panel, GTX 1650 Ti, i7-10750H, a dGPU that drove no displays. That
  machine's record was deliberately deleted in commit `3a0a0ec`; do not restore
  it, and do not carry its facts forward.
- **`hyprctl devices` shows two mice for one touchpad.** Not a trackpoint.
- **The old drive is `nvme0n1`, the live one is `nvme1n1`.** Lower number is the
  one to destroy. Match on serial every time, never on node.

## Files

- `old-drive.md` — identifying and wiping the transplanted KIOXIA, and what is lost with it
