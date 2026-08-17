# XPS 15 9500 (silver-fox) — Crash Troubleshooting

## The machine
- **Model:** Dell XPS 15 9500
- **Service Tag:** FTDFN53
- **BIOS:** 1.36.1 (ED.1.1.6), dated 2025-04-28. Outdated: Dell's latest 9500 BIOS is 1.40.014 (Jan 2026), several releases behind. Dell BIOS packages bundle EC firmware, and the EC is the misbehaving component, so updating is now a first-line action (Step 0 in the checklist).
- **OS:** Omarchy (Arch-based, Hyprland/Wayland)
- **GPU:** Intel iGPU (i915) drives the internal panel (eDP-1). NVIDIA GTX 1650 Ti (`nvidia-open-dkms` 595.71.05, proprietary) drives no displays, compute/offload only.
- **Battery:** DELL 70N2F95, SMP, Li-poly. Static health good: ~97% of design, health "Good". But `serial_number: 1` and `cycle_count: 0` are stuck static values (see suspicions below).
- **Charger:** Correct Dell-class USB-C PD adapter, negotiates 20V/6.5A (~130W) when healthy.
- **History:** Bought second-hand ~June 2026. Battery was replaced recently by the previous owner/seller right before sale. The machine was effectively out of service 07-19 to 08-17 (crash, then the flat-battery/no-charge state defeated every revival attempt; see session logs).

## The symptom
Recurring **hard power cut** under load, no kernel trace. The machine dies instantly (journal stops mid-line, next boot reports the journal "corrupted or uncleanly shut down"), then the Dell bootloader appears and it restarts. No kernel panic, no pstore dump, no NVIDIA Xid. A clean instant power loss with zero kernel trace is a power/platform reset, not a software crash.

Triggers seen: unlock/resume from sleep, and launching a GPU-accelerated app (Zed). Common thread is a **load transient** (CPU/GPU burst) that the power system cannot absorb.

A more severe variant: after a crash the machine can **boot-loop at the Dell logo** (POST, before the kernel loads), then go fully dead / power button unresponsive for ~3 minutes, then recover after unplugging peripherals and waiting. This is firmware/EC level.

The flat-battery variant (seen 07-18 morning, 08-03, and 08-17): with the pack near 0%, every boot attempt dies 2-6 seconds in with the usual instant-cut signature, even though ACPI reports the AC adapter on-line at kernel start. On 08-17 the machine only survived boot once the battery had reached ~11%. Two implications: boot needs battery assist (the input path alone cannot reliably carry even early boot), and "AC on-line" does not prove the input path is actually delivering power.

## Leading hypothesis: charge-input / EC / PD-path fault
The failure lives in the **charge-input path (USB-C daughterboard / PD controller / DC-in / EC)**, not the battery output path.

Two linked faults reinforce each other:
1. **A load transient causes a hard power cut.** The XPS 9500 relies on battery assist for bursts that exceed the adapter's instantaneous output. When the power system cannot buffer a spike, a rail sags into a protective reset.
2. **A crash can latch the EC into a "no input power" state.** After the latch the EC reports AC offline and refuses to draw from the charger even though it is physically attached and the PD port has negotiated a contract. The machine then silently runs down the battery until it is flat, at which point the POST boot-loop/brick variant appears.

The `UCSI_GET_PDOS failed (-5)` error fires on **every boot** and is independent of the latch. It is the strongest standing evidence that the USB-C PD layer itself is flaky.

Three additions from the July-August outage (session logs below):
- **Port-cycling clears the no-charge state.** Replugging the same port does nothing, but moving the charger to a different USB-C port forces a fresh CC attach and PD negotiation, which re-arms charging. Every port eventually misbehaved, so no single port's hardware is at fault: the latch lives in the layer all three ports share (EC / PD controller / charge logic). This is also the fastest known recovery when the machine is flat and refusing to charge.
- **"AC on-line" cannot be trusted.** All the failed micro-boots of 07-18, 08-03 and 08-17 logged the adapter as on-line one second before dying. The visible latch (AC reads off-line) has a stealth sibling where the EC claims input is present but does not actually deliver or charge. The only honest indicator is the battery side: `BAT0/status` Discharging (or `current_now` flowing out) while plugged in means the input path is not really working.
- **Community precedent.** Multiple XPS 9500 owners report the same charger-not-recognised-on-any-port behaviour with power-off/replug dances as the only workaround, and Dell's official resolution in those threads is motherboard replacement (the PD controller is on the motherboard). Consistent with the EC/PD-layer picture, and relevant to repair-vs-refund economics.

## Session log: 2026-08-17 - revival after a month down; port-cycling discovered

Machine found flat and refusing to start (dead since mid-July, below). Reconstructed from journal, upower history, and observation:
- **12:18, 12:22, 12:44:** three boot attempts, each dying 2-6s in with a hard cut (journal stops at the early journald flush / Hyprland start). Every one logged `ACPI: AC: AC Adapter [AC] (on-line)` at kernel start and died anyway. Battery at ~0%.
- Unplug/replug on the same port did not restart charging. **Moving the charger between ports did.** Each port would begin charging and then develop the same trouble, but every port change re-armed charging. Not a single-port fault. (Physical-port-to-UCSI-connector mapping not yet recorded; worth capturing next time, since the left pair is on the motherboard and the right port is on the separate IO board.)
- **13:00:47:** a boot finally sticks. upower's first reading at 13:00:51: battery 11%, charging. The boot that survived is the one that had battery assist available.
- Charging then ran clean: steady ~40W (~2A into the pack), voltage climbing from 11.77V past 12.0V, about 1%/min. The pack charges fine once the input path actually delivers.
- PD contract on the working boot: **18V / 6.5A max (~117W)** on UCSI connector 001, again not the healthy 20V/6.5A (130W). The degraded-voltage contract persists even in the good state.
- `UCSI_GET_PDOS failed (-5)` plus `ucsi_acpi: unknown error 0` still fire at boot.
- All upower history from before this session is gone (hard crashes discard unsaved history), so no drain curves survive from July.
- **Later the same day: BIOS updated 1.36.1 → 1.40.0** (see Teardown day Step 0). Flash completed without incident. **Observation period starts here** — the open question is whether the EC/PD behaviour changed. Worth re-checking on the next few boots: the PD contract on UCSI connector 001 (was a degraded 18V/6.5A instead of 20V/6.5A), whether `UCSI_GET_PDOS failed (-5)` still fires, and whether the charge latch still needs port-cycling to re-arm. If those clear up, Steps 2-4 of teardown day may be unnecessary.
- **First post-update boot (17:01, boot 0): both PD markers are UNCHANGED.** The BIOS/EC update did not alter the PD layer at all:
	- PD contract on connector 001 is still **18V/6.5A (117W)** — `voltage_now: 18000000` while `voltage_max: 20000000`. The port and adapter advertise 20V capability, but the negotiated contract still settles at 18V. Byte-for-byte the same as the pre-update reading earlier the same day.
	- `ucsi_acpi USBC000:00: unknown error 0` and `UCSI_GET_PDOS failed (-5)` **still fire** at boot (17:01:12).
	- Machine state otherwise healthy at the time of reading: `AC/online 1`, `BAT0 Full`, 100%, 13.114V. No latch.
	- The omarchy `omarchy-powerprofiles-set` udev hook still fails with exit code 1 on every ucsi event, so there are still **no working low-battery warnings**. Relevant safety gap before any deliberate crash-trigger testing.
	- **Reading:** firmware is now largely eliminated as the fix. The degraded contract surviving a BIOS/EC update raises the weight on the adapter/cable (Step 4, needs no teardown) and on the PD controller hardware. Charge-latch behaviour is still unproven post-update, since it has not recurred yet.

### Breakthrough: the adapter offers 20V, the machine declines it

`UCSI_GET_PDOS` fails, but the **partner's advertised PDO list is readable another way**, via the Type-C class rather than the UCSI power-supply class. This was not known in earlier sessions and is the single most useful diagnostic found so far:

```bash
# port0-partner == the attached charger. Map: typec port0 <-> ucsi-source-psy-USBC000:001
find /sys/class/usb_power_delivery/pd2/ -type f | sort | while read f; do printf '%s = %s\n' "${f#*/pd2/}" "$(cat $f 2>/dev/null)"; done
```

First reading, 2026-08-17, post-BIOS-update, with the stock Dell charger attached. Advertised source capabilities:

| PDO | Type | Voltage | Max current | Notes |
|---|---|---|---|---|
| 1 | variable | max 50mV, min 26350mV | 3850mA | **Malformed.** Minimum voltage above maximum, and both nonsensical. |
| 2 | fixed | 5000mV | 1000mA | Low for a 5V rail (3A is typical). |
| 3 | fixed | 18000mV | 6500mA | 117W. **This is what the machine selects.** |
| 4 | fixed | 20000mV | 6500mA | 130W. The healthy contract. **Offered, but not taken.** |

**The adapter does advertise the full 20V/6.5A 130W PDO.** The negotiated contract (`voltage_now 18000000`, `current_now 6500000`) matches PDO 3 exactly, so the sink is choosing the 18V rail while a valid 20V rail sits in the list.

This reframes the whole degraded-contract question. It is not "the adapter cannot deliver 20V". It is **the machine declining to request the 20V PDO that is on offer.** Combined with the malformed PDO 1 and the standing `UCSI_GET_PDOS failed (-5)`, the coherent story is that the PD capability data is arriving corrupt, and the sink's PDO selection falls back to 18V rather than trusting the list.

Corruption could still originate in the adapter, its cable, or the machine's PD controller. The charger cross-check (Step 4) now discriminates cleanly between those, see below.

Also resolved incidentally: **typec `port0` maps to `ucsi-source-psy-USBC000:001`**, and `port0-partner` exposes `pd2`. Physical-port identity still needs recording by hand.

## Session log: 2026-07-18/19 - the crash that started a month of downtime (reconstructed from journal)

- **07-18 morning:** the flat-battery struggle pattern before it had a name: five micro-boots between 10:22 and 10:46 (mostly 2-16s), then a boot at 10:55 that stuck. The machine was already fighting the no-charge state that morning.
- **07-18 10:55 to 07-19 08:01:** ran ~21h idle overnight, AC on-line at boot. Journal ends mid-housekeeping at 08:01:02 (snapper had just run): the fourth documented instant power cut, idle-on-AC like 07-04 crash 1.
- **07-19 15:51:** revival attempt. Boot logs AC on-line, dies in 2s.
- **07-19 15:52:** second attempt. Kernel logs `AC Adapter [AC] (off-line)` with the charger attached: **the EC latch, caught in a boot log.** Runs 36s and dies as the desktop spins up.
- **08-03 15:28 and 15:38:** two more attempts weeks later, AC "on-line", dead in 2-5s each. The machine then sat until 08-17.
- Most consistent reading: the 21h session ran on AC input but the pack never actually charged (the stealth no-charge state), leaving it near-flat for the afternoon attempts. The alternative (pack charged overnight, then the 2s and 36s deaths happened on a full pack) fits the 07-04 evidence worse, since a latched machine has previously run half an hour on battery.

## Session log: 2026-07-04 (richest single-session signal)

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
- **Single-port hardware fault:** ruled out 08-17. All three USB-C ports eventually showed the no-charge behaviour, and a change to any other port is what re-arms charging. The fault is in the shared EC/PD layer.

## Suspicions still open
- **Battery may be an aftermarket clone.** `serial_number: 1` and a permanently stuck `cycle_count: 0` are not what genuine Dell/SMP packs report. A clone BMS reporting static values could itself confuse the Dell EC. Inspect when open.
- **Recently swapped battery on a second-hand machine** could mean the swap was done to paper over a known fault. Seller reachability / price paid relevant if a refund becomes the better path.
- **Outdated BIOS/EC firmware (now an action item).** 1.36.1 is from April 2025 and Dell has shipped several releases since, latest 1.40.014 (Jan 2026). BIOS updates carry EC firmware, and EC misbehaviour is the heart of this fault. Until updated, firmware stays a live suspect and is the cheapest possible fix.
- Omarchy power hooks are broken (`omarchy-battery-remaining: command not found` from omarchy-battery-monitor, udev `omarchy-power-profile` exit 1 on every ucsi event). Not crash-related, but it means **this machine has no working low-battery warnings at all**, which is exactly how a silent-drain session ends in a flat pack and a brick. Fix, or replace with a latch alarm that fires when the battery discharges while a charger is attached.

## Immediate operating guidance
- Health check while plugged in: `cat /sys/class/power_supply/AC/online /sys/class/power_supply/BAT0/status`. Latched if AC reads 0, **or** if AC reads 1 while BAT0 says Discharging (the stealth variant; on-line alone proves nothing).
- If latched: **shut down, unplug charger, hold power ~30-60s, replug, boot.** A replug or normal reboot will not fix it.
- If it is flat and will not charge or start: **move the charger to a different USB-C port** (a fresh PD attach re-arms charging; same-port replug does not). Then leave it alone until the pack has at least ~10% before attempting a boot. Boot attempts below that die in seconds and waste the trickle charge.
- Keep it charged while diagnosing. A flat battery brings on the POST boot-loop/brick variant and, as July-August showed, month-long outages.
- Treat any load spike (resume, unlock, launching a GPU app) as crash-prone while in a bad power state.

## Teardown day — checklist

Goal: run the power-fault isolation tests **and** do general maintenance (clean + repaste). Do the diagnostic tests **before** repasting so a teardown step does not mask the result. Priority order is now charge-input first.

### Step 0 - Firmware update (no tools, do before teardown day)
- [x] **DONE 2026-08-17: BIOS 1.36.1 → 1.40.0** (build date 11/26/2025), confirmed via `cat /sys/class/dmi/id/bios_version`. Note `dmidecode` is not installed on this machine; sysfs works without root.
	- LVFS does **not** carry the XPS 9500 BIOS (`fwupdmgr get-updates` shows System Firmware with no available update), so the fwupd path is out. Used the fallback: `XPS_9500_1.40.0.exe` from Dell support (driver page https://www.dell.com/support/home/en-us/drivers/driversdetails?driverid=w5d4j — must be a real browser, Dell 403s curl/scripts), copied to a FAT32 USB, flashed from the F12 one-time-boot menu ("BIOS Flash Update"). No Windows needed. Flash ran clean.
	- The latest version is **1.40.0**, not 1.40.014 as an earlier search suggested.
	- Note for future firmware work: if `sudo` is unavailable, udisks2 handles removable-media formatting via polkit. `udisksctl` in this build has no `format` verb, so call it over D-Bus: `gdbus call --system --dest org.freedesktop.UDisks2 --object-path /org/freedesktop/UDisks2/block_devices/sdXN --method org.freedesktop.UDisks2.Block.Format 'vfat' "{'label': <'BIOSFLASH'>, 'update-partition-type': <true>}"`. Expect a gdbus 25s timeout error on large/slow media even though the format succeeds; verify with `lsblk -f` rather than trusting the exit code.
- [ ] Optional, still pending: LVFS offers a KIOXIA XG6 SSD firmware update 10604106 → 10604107 (thermal SMART fix, medium urgency, needs AC + reboot): `fwupdmgr update`. Unrelated to the crash hypothesis.
- [ ] Precondition: battery well charged and charging confirmed healthy (fresh flea-power reset first). A power cut mid-flash is the one way this machine can get worse. The flash runs pre-OS at low steady load, not the load-transient profile that triggers the crashes, so the risk is real but small.
- [ ] Afterwards, run a normal observation period before doing the teardown tests: if the EC update fixes the latch/crash behaviour, Steps 2-4 may become unnecessary.

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
- [ ] This needs no teardown; do it as soon as a second charger is available. The 08-17 good-state contract was still 18V instead of 20V, which keeps adapter/cable on the suspect list.
- [ ] **The discriminating test (highest value, zero risk).** Any standards-compliant USB-C PD charger works for this, it does **not** need to be 130W. An Apple 96W is fine. Attach it, then dump the partner PDO list (`/sys/class/usb_power_delivery/pd2/`, command in the 08-17 log above) and read what comes back:
	- **List parses clean, no malformed PDO, and the machine selects the top rail →** the sink's PD logic is healthy and the stock Dell adapter/cable is producing the corrupt capability data. Cheapest possible fix: replace the adapter.
	- **List still contains malformed/garbled PDOs →** the corruption is in the machine's PD controller / EC read path, independent of what is plugged in. That is a motherboard-level fault, matching the community precedent in the hypothesis section, and it makes the repair-vs-refund call urgent.
	- Note the expected side effects of an under-spec adapter so they are not misread as faults: a Dell POST warning about adapter wattage, and CPU/GPU throttling under load.
	- **Do not run the crash-trigger tests on an under-spec adapter.** A crash on a 96W supply proves nothing, since insufficient headroom would plausibly cause the same rail sag being investigated. This test is for PD negotiation only.
- [ ] While testing, map physical ports to UCSI connectors (plug into each port, see which `ucsi-source-psy-USBC000:00X` reports online). If the no-charge state recurs, note whether left (motherboard) and right (IO board) ports behave differently; that localises the fault for the repair-vs-refund call.

### Step 5 — Maintenance (only after the tests above)
- [ ] Clean fans and vents (hold fan blades still while using air duster, keep can upright).
- [ ] Repaste CPU + GPU: clean old paste with 99% isopropyl + lint-free wipes, apply fresh.
- [ ] Reseat battery and DC-in connectors on reassembly; double-check screw positions/lengths.

### After reassembly
- [ ] Confirm `cat /sys/power/mem_sleep` shows `deep` active.
- [ ] Repeated sleep/unlock and GPU-app-launch cycles on a charged battery to see if the crash recurs.
- [ ] If AC-only was stable but battery-connected still bricks: pursue battery replacement and seriously weigh the refund/return path.
