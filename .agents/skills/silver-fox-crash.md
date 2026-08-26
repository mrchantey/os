# XPS 15 9500 (silver-fox) — power fault: findings and conclusion

**Status: closed. Not being repaired, not being torn down.** The fault is on the motherboard, a board costs AU$500-800 against a machine worth AU$400-700, and the machine has already crashed on battery with no charger attached, so there is no workaround left. The laptop will be sold as faulty or stripped for parts. This document is the record, not a repair plan.

## Provenance

Bought second-hand for **AU$400 from Facebook Marketplace** around June 2026. The battery had been replaced by the seller shortly before sale. The seller will not be contacted. The machine did the job it was bought for (a time-sensitive presentation) and owes nothing.

## The machine

- Dell XPS 15 9500, service tag **FTDFN53**
- Motherboard DP/N **05XYW7**, rev A00, Compal **LA-J191P**
- i7-10750H, NVIDIA GTX 1650 Ti 4GB (compute only, drives no displays), Intel UHD on eDP-1
- 32GB DDR4 as 2 x 16GB SODIMM, JEDEC 3200 MT/s, derated to 2933 by the Comet Lake controller
- KIOXIA KXG60ZNV1T02 (XG6) 1TB, M.2 2280 NVMe
- 15.6" UHD+ 3840x2400 touch panel
- Battery DELL 70N2F95, SMP, 86Wh class, ~97% of design capacity
- BIOS **1.40.0**, flashed from 1.36.1 during diagnosis
- Omarchy, Arch-based, Hyprland/Wayland

USB-C port mapping: right-hand single port = `typec port2` = `ucsi-source-psy-USBC000:003`, on the separate IO daughterboard. Left-hand pair includes `port0` = connector 001, on the motherboard.

## The symptom

Recurring **hard power cut**. The machine dies instantly with no kernel trace, no panic, no pstore dump, no NVIDIA Xid. The journal stops mid-line and the next boot reports it uncleanly shut down. A clean instant power loss with zero kernel trace is a platform-level reset, not a software crash.

The trigger is a **load transient**: resume, unlock, launching a GPU-accelerated app, starting text-to-speech. It has also happened while completely idle, on AC, at 100% charge, which killed the early theory that low battery was required.

Two worse variants:

- **POST boot-loop / brick.** After a crash the machine can loop at the Dell logo before the kernel loads, then go fully unresponsive for a few minutes before recovering. Firmware/EC level.
- **The EC latch.** After a crash the EC can report the AC adapter offline with the charger physically attached and a PD contract negotiated, and refuse to draw from it. The machine then silently runs the battery flat. A stealth variant exists where AC reads on-line but nothing is actually delivered, so `AC/online` alone proves nothing. The only honest indicator is `BAT0/status` reading Discharging while plugged in.

Latch recovery, both confirmed: a full poweroff with the charger unplugged and the power button held (flea-power reset), or moving the charger to a **different** USB-C port. A same-port replug or a normal reboot does neither. Every port eventually misbehaved, so no single port's hardware is at fault.

## The decisive evidence: PD capability corruption

The USB-C PD layer returns corrupt data, and it does so independent of what is plugged in.

Read the attached charger's advertised capabilities through the Type-C class rather than UCSI, which is the diagnostic that broke this open:

```bash
# find the pd node under port*-partner, then:
cd /sys/class/usb_power_delivery/pdN/source-capabilities
for d in [0-9]*:*; do echo "-- $d"; cat $d/voltage $d/maximum_current; done
```

Tested with two unrelated chargers on two different port groups:

| | Dell 130W (left port, motherboard) | Apple 96W (right port, IO board) |
|---|---|---|
| PDO slot 1 | malformed: max 50mV, min 26350mV, **3850mA** | malformed: 1150mV, **3850mA** |
| Top rail offered | 20V / 6.5A (130W) | 20V / 4.8A (96W) |
| Rail actually taken | **18V** | **15V** |
| Contract coherent? | no | no: reports 15V paired with 4800mA, but 4.8A belongs to the 20V PDO and the 15V PDO is 3A |

Four things follow:

1. **PDO slot 1 is garbage both times, with a byte-identical bogus `3850mA` field.** Slot 1 must be a clean 5V fixed PDO by spec. Garbage that follows the machine across two unrelated manufacturers is generated locally, not by the adapter.
2. **The machine declines the top rail every time**, including from the genuine Dell brick that advertises the full 130W it is rated for.
3. **Both port groups are affected**, which clears the IO daughterboard as a standalone cause. The fault is in the layer they share.
4. The garbage leaks into the power-supply objects: `voltage_min` reports 1150000, straight from the malformed slot.

Alongside this, on every boot: `ucsi_acpi USBC000:00: unknown error 0` and `UCSI_GET_PDOS failed (-5)`. And reading the machine's own local port capabilities (`/sys/class/usb_power_delivery/pd0`) blocks in the kernel for minutes and cannot be killed, while the partner's capabilities read instantly. The stall is on the machine's side.

## The crash that closed it out

**A hard cut occurred with the charger completely unplugged, running on battery.** Same instant-power-loss signature, on a load transient.

This is what ends the investigation. Every earlier crash had a charger attached, which supported a charge-input-only story and left "run it unplugged" as a plausible workaround. It isn't one. The fault reaches the system power path itself, not just the input side.

## What was ruled out

- **Firmware.** BIOS/EC updated 1.36.1 to 1.40.0. Both PD markers were byte-for-byte unchanged afterwards: same 18V contract on a 20V-capable link, same `UCSI_GET_PDOS failed (-5)`. Firmware is not the fix.
- **The charger.** Two unrelated adapters produce identical corruption. Buying a replacement Dell brick would have been wasted money.
- **A single bad USB-C port, and the IO daughterboard.** All three ports misbehave, and the corruption appears on both the motherboard ports and the IO board port.
- **Low battery as the trigger.** A crash happened idle, on AC, at 100%.
- **Battery output path.** The pack sources 2-3A cleanly under load, and charges normally at ~40W once input is actually delivered.
- **NVIDIA suspend/resume software.** `NVreg_PreserveVideoMemoryAllocations=1`, `NVreg_UseKernelSuspendNotifiers=1` and `SYSTEMD_SLEEP_FREEZE_USER_SESSIONS=false` are all correctly set. Not the cause.
- **Thermal.** The only "Thermal Critical" events in BIOS are from 2021, under the previous owner. Cool-on-wake crashes do not fit.
- **Deep sleep as a cure.** `mem_sleep=deep` is set and persisted via `/etc/tmpfiles.d/silver-fox-deep-sleep.conf`. It is a mitigation at best, and a boot still died across a `PM: suspend entry (deep)`.
- **Dell ePSA Advanced.** Passed. It runs at low steady load and cannot catch a load-dependent power fault.

## Conclusion

Motherboard-level fault in the shared PD controller / EC / system power path. Consistent with community precedent, where XPS 9500 owners reporting the same charger-not-recognised-on-any-port behaviour are told by Dell that the resolution is a motherboard replacement, since the PD controller is on the board.

Not worth repairing. A board is AU$500-800 and the whole machine is worth AU$400-700.

**One cheap thing was never tested:** the replacement battery is a suspected aftermarket clone (`serial_number: 1` and a permanently stuck `cycle_count: 0` are not what genuine Dell/SMP packs report), and a clone BMS tripping a protection cutout under load transient would also explain an unplugged crash. Testing it means a new pack and a bottom-cover removal. Not being pursued, but it is the one remaining alternative to a board fault and it is recorded here honestly.

## Salvage

Worth pulling or worth selling with the machine:

- **KIOXIA XG6 1TB M.2 2280 NVMe.** Take this. It fits every Framework laptop except the Laptop 12, which uses M.2 2230.
- **32GB DDR4-3200 SODIMM.** Worth AU$220-325 to replace, but it only fits the DDR4-era Framework 13 boards (11th, 12th, 13th gen Intel), which Framework no longer stocks. Everything current is DDR5. **Leave it in the machine when selling**, since a complete unit with 32GB fetches more than the sticks do alone.
- **UHD+ 3840x2400 touch screen assembly**, the **86Wh 69KF2 battery**, palmrest and base cover all interchange across the XPS 15 9500 / 9510 / 9520 / 9530 generation and have real resale value to someone repairing one.
- The previous generation (9550 / 9560 / 9570 / 7590) shares nothing meaningful. Do not let a buyer tell you otherwise.

Selling it complete and clearly described as faulty will recover more than parting it out, minus the SSD.

## Incidental notes worth keeping

- LVFS does not carry the XPS 9500 BIOS. The working path is the `.exe` from Dell's support site on a FAT32 USB, flashed from the F12 one-time-boot menu via "BIOS Flash Update". No Windows required. Dell's driver pages 403 curl and scripts, so a real browser is needed to download.
- To format removable media without sudo, udisks2 works over polkit. This build's `udisksctl` has no `format` verb, so call it over D-Bus: `gdbus call --system --dest org.freedesktop.UDisks2 --object-path /org/freedesktop/UDisks2/block_devices/sdXN --method org.freedesktop.UDisks2.Block.Format 'vfat' "{'label': <'BIOSFLASH'>, 'update-partition-type': <true>}"`. Expect a 25s gdbus timeout error even when the format succeeds; verify with `lsblk -f`.
- Omarchy's power hooks are broken on this machine (`omarchy-battery-remaining: command not found`, and the `omarchy-power-profile` udev hook exits 1 on every ucsi event), so it has no working low-battery warnings at all. Unrelated to the crash, but it is how a silent-drain session ends in a flat pack.
