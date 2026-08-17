# XPS 15 9500 (silver-fox) — Crash Troubleshooting

## The machine
- **Model:** Dell XPS 15 9500
- **Service Tag:** FTDFN53
- **BIOS:** 1.36.1 (ED.1.1.6)
- **OS:** Omarchy (Arch-based, Hyprland/Wayland)
- **GPU:** Intel iGPU (i915) drives the internal panel (eDP-1). NVIDIA GTX 1650 Ti (`nvidia-open-dkms` 595.71.05, proprietary) drives no displays, compute/offload only.
- **Battery:** DELL 70N2F95, SMP, Li-poly. Static health good: ~97% of design, health "Good". But `serial_number: 1` and `cycle_count: 0` are stuck static values (see suspicions below).
- **Charger:** Correct Dell-class USB-C PD adapter, negotiates 20V/6.5A (~130W) when healthy.
- **History:** Bought second-hand ~2 weeks ago. Battery was replaced recently by the previous owner/seller right before sale.

## The symptom
Recurring **hard power cut** under load, no kernel trace. The machine dies instantly (journal stops mid-line, next boot reports the journal "corrupted or uncleanly shut down"), then the Dell bootloader appears and it restarts. No kernel panic, no pstore dump, no NVIDIA Xid. A clean instant power loss with zero kernel trace is a power/platform reset, not a software crash.

Triggers seen: unlock/resume from sleep, and launching a GPU-accelerated app (Zed). Common thread is a **load transient** (CPU/GPU burst) that the power system cannot absorb.

A more severe variant: after a crash the machine can **boot-loop at the Dell logo** (POST, before the kernel loads), then go fully dead / power button unresponsive for ~3 minutes, then recover after unplugging peripherals and waiting. This is firmware/EC level.

## Leading hypothesis: charge-input / EC / PD-path fault
The failure lives in the **charge-input path (USB-C daughterboard / PD controller / DC-in / EC)**, not the battery output path.

Two linked faults reinforce each other:
1. **A load transient causes a hard power cut.** The XPS 9500 relies on battery assist for bursts that exceed the adapter's instantaneous output. When the power system cannot buffer a spike, a rail sags into a protective reset.
2. **A crash can latch the EC into a "no input power" state.** After the latch the EC reports AC offline and refuses to draw from the charger even though it is physically attached and the PD port has negotiated a contract. The machine then silently runs down the battery until it is flat, at which point the POST boot-loop/brick variant appears.

The `UCSI_GET_PDOS failed (-5)` error fires on **every boot** and is independent of the latch. It is the strongest standing evidence that the USB-C PD layer itself is flaky.

## Session log: 2026-07-04 (most recent, richest signal)

Two crashes in one morning, then the EC latch was reproduced and cleared live.

**Crash 1, ~10:01:** Machine had run all night on AC, charged to 100% by 01:40, AC online the whole time. At 10:01:10 the journal simply stops after routine housekeeping. Hard power cut **while idle, on AC, at full charge.** This kills the earlier "amplified by low battery" qualifier: the crash mechanism does not need a low battery.

**The EC latched between boots.** The 10:04 boot came up reporting `AC Adapter [AC] (off-line)` from the first second and fired the on-battery udev hooks, even though the charger was attached.

**Crash 2, 10:06:57:** That boot ran 2m23s. The final journal line, at the exact second of death, is `Started zed.` A mouse click launched Zed (GPU-accelerated, a sharp load transient) and the machine died instantly. Same instant-power-cut signature.

**Latch confirmed and characterised (live, during the bad boot):**
- Charger attached, PD port negotiated a (degraded) 18V/4.5A ~81W PPS contract, yet ACPI reported **AC offline** and **zero watts drawn from the charger.**
- The machine was running **entirely on battery.** Measured drain: ~4 mAh in 5s ≈ 2.9A ≈ 33W. Voltage falling (11.45V), coulomb counter dropping. Battery went 93% → 61% in about half an hour.
- **Unplug/replug did NOT clear the latch.** Unplugged, the battery sourced ~2.1A cleanly (so the pack and its main connector carry load fine). Replugged, it returned to the same floating/no-input state. The only fake reading was the "1 mA" battery current shown while plugged in.

**Flea-power reset cleared it.** Sequence that worked: clean `poweroff`, unplug charger + peripherals, hold power button ~60s, replug, boot. Note the machine powered on the instant the button was pressed (residual flea charge in the caps), so it was probably the full poweroff-with-charger-unplugged that cleared the EC, not a true 60s drain. After the reset:
- `AC: online = 1`, logged `AC Adapter [AC] (on-line)` from first second.
- `BAT0: Charging` at ~3.5A / ~42W, voltage climbing (11.45 → 11.91V).
- `UCSI_GET_PDOS failed (-5)` **still fires** (persistent, independent of the latch).

Takeaways from the session:
- The battery **can source current** under load, so the pack and its output/connector are electrically fine. This down-weights "bad battery connector" as the *primary* cause.
- The fault is on the **charge-input side.** DC-in / USB-C daughterboard / PD controller / EC.
- A hard crash can trigger the EC latch, which then makes everything worse by draining a flat battery.
- **Reliable recovery procedure:** charger unplugged, then hold power button. A plain replug or a normal reboot does NOT clear the latch.

## What has been ruled out / down-weighted
- **NVIDIA suspend/resume software fix:** already correctly applied, not the cause. `NVreg_PreserveVideoMemoryAllocations=1`, `NVreg_UseKernelSuspendNotifiers=1`, `SYSTEMD_SLEEP_FREEZE_USER_SESSIONS=false` are all set (nvidia-utils drop-in). The `nvidia-suspend/resume` systemd services are intentionally disabled because the newer kernel-suspend-notifier path replaces them.
- **"Low battery" as the trigger:** dead. Crash 1 happened idle, on AC, at 100%.
- **Loose battery connection / battery output fault:** down-weighted. The battery sourced 2-3A cleanly under load on 07-04.
- **Pure thermal:** BIOS "Thermal Critical" shutdown events all dated Nov 2021 (previous owner). Cool-on-wake crashes do not fit thermal.
- **Deep-sleep (`deep` / S3) as a cure:** not a fix. A Fri 07-03 boot died across a `PM: suspend entry (deep)` and never resumed. `mem_sleep` is set to `deep` (via `scripts/silver-fox/install.sh`, persisted in `/etc/tmpfiles.d/silver-fox-deep-sleep.conf`); kept as a cheap mitigation only.
- **Dell ePSA Advanced test:** passed (06/05/2026). Runs at low load, will not catch load-dependent power faults.

## Suspicions still open
- **Battery may be an aftermarket clone.** `serial_number: 1` and a permanently stuck `cycle_count: 0` are not what genuine Dell/SMP packs report. A clone BMS reporting static values could itself confuse the Dell EC. Inspect when open.
- **Recently swapped battery on a second-hand machine** could mean the swap was done to paper over a known fault. Seller reachability / price paid relevant if a refund becomes the better path.
- Minor omarchy hooks erroring on every power event (`omarchy-battery-remaining: command not found`, udev `omarchy-power-profile` exit 1). Cosmetic, not crash-related.

## Immediate operating guidance
- If AC ever reads offline while the charger is attached (`cat /sys/class/power_supply/AC/online` → 0), the EC is latched: **shut down, unplug charger, hold power ~30-60s, replug, boot.** A replug or normal reboot will not fix it.
- Keep it charged while diagnosing. A flat battery brings on the POST boot-loop/brick variant.
- Treat any load spike (resume, unlock, launching a GPU app) as crash-prone while in a bad power state.

## Teardown day — checklist

Goal: run the power-fault isolation tests **and** do general maintenance (clean + repaste). Do the diagnostic tests **before** repasting so a teardown step does not mask the result. Priority order is now charge-input first.

### Prep
- [ ] Anti-static wrist strap, hard non-carpet surface.
- [ ] Charge to 100% the night before.
- [ ] Tools: #0 Phillips + Torx T5, plastic spudger, 99% isopropyl, lint-free wipes, fresh paste (Arctic MX-4/MX-6 or Thermal Grizzly Kryonaut), labelled cups for screws.
- [ ] XPS 15 9500 base screws are different lengths (longer near the hinge); keep them organised by position. Some are under the rubber feet.

### Step 1 — Flea-power / EC reset (do first, no tools)
- [ ] Full shutdown, unplug charger and all peripherals.
- [ ] Hold power button 30-60s.
- [ ] Boot on AC only, confirm `AC/online` = 1 and `BAT0/status` = Charging. (This procedure is confirmed to clear the latch.)

### Step 2 — Inspect the charge-input path (top suspect)
- [ ] Inspect the **DC-in / USB-C daughterboard and its ribbon cable** for damage, discoloration, poor seating. Reseat the ribbon.
- [ ] Inspect the **battery connector** (disturbed in the swap): partial seating, bent pins, scorching. Reseat firmly. (Now secondary, since the battery sources current fine.)
- [ ] Photograph connector states before/after in case the seller/refund path is needed.

### Step 3 — AC-only isolation test
- [ ] Disconnect the battery (follow Dell's "disconnect battery before service" note).
- [ ] Run on charger only, do real work + trigger a failure (load spike / resume).
  - **Stable on AC-only →** points at the battery/BMS (clone-pack suspicion) or its interaction with the EC. Strong signal for replacement and/or the refund path.
  - **Still bricks on AC-only →** it is the board / charging circuit / VRM / PD controller.
- [ ] Reconnect the battery afterward.

### Step 4 — Charger / cable cross-check
- [ ] Try a different known-good 130W USB-C PD charger and cable. The persistent `UCSI_GET_PDOS failed (-5)` and the degraded-contract behaviour both hint at PD-path flakiness.

### Step 5 — Maintenance (only after the tests above)
- [ ] Clean fans and vents (hold fan blades still while using air duster, keep can upright).
- [ ] Repaste CPU + GPU: clean old paste with 99% isopropyl + lint-free wipes, apply fresh.
- [ ] Reseat battery and DC-in connectors on reassembly; double-check screw positions/lengths.

### After reassembly
- [ ] Confirm `cat /sys/power/mem_sleep` shows `deep` active.
- [ ] Repeated sleep/unlock and GPU-app-launch cycles on a charged battery to see if the crash recurs.
- [ ] If AC-only was stable but battery-connected still bricks: pursue battery replacement and seriously weigh the refund/return path.
