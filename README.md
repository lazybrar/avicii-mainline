# avicii-mainline

Mainline Linux on the OnePlus Nord (codename `avicii`, Qualcomm SM7250 / Snapdragon 765G).

This is a personal project. **The goal is a headless home server, not a complete phone.** The
phone this was developed on has had its microphone and cameras physically removed, so those parts
(and anything else a server does not need) are not implemented and cannot be tested here.
Everything is work in progress and nothing has been sent upstream.

Base: Linux `v7.3-rc7`. Userspace used for testing: Arch Linux ARM on the `userdata` partition.

## Status

| Part | State |
|---|---|
| 8 CPU cores, cpufreq | works |
| UFS storage | works |
| USB device mode (network gadget) | works |
| USB host mode (USB 2.0, role switch, VBUS) | implemented, not confirmed with a real device |
| USB 3, DisplayPort alt mode, USB PD | not implemented |
| Display (Samsung AMS644VK04, DSI command mode with DSC) | works; compositors log occasional `atomic commit failed: busy` |
| GPU (Adreno 620, Mesa Turnip/freedreno) | works: Vulkan 1.3, `vkcube`, Wayland compositors |
| Touchscreen (Goodix GT9886) | works, multi-touch |
| Power and volume keys, RTC, watchdog, thermal | works |
| Wi-Fi (WCN3990 through the modem) | works; needs a workaround commit marked `HACK` (qrtr) |
| Battery gauge (BQ27411) | works |
| Charging on/off and charge thresholds (PM7250B) | works; a full slow charge through the threshold is untested |
| Speaker (ADSP + NXP TFA9874 on primary MI2S) | plays, **but the ADSP restarts about every 40 s** (see below) |
| Bluetooth | not started |
| Microphone, cameras | not implemented: the hardware is removed from the development phone |
| Earpiece, headset codec, sensors, modem data/calls, fingerprint, NFC, vibration | not implemented |
| Suspend to RAM | untested |

### Known problems

- **ADSP restarts.** The sensor process inside the ADSP firmware waits for a FastRPC file server on
  the Linux side (`hexagonrpcd`) and for the phone's sensor registry files. Without them its
  watchdog restarts the whole ADSP roughly every 40 seconds, which interrupts audio. The FastRPC
  node is in the device tree; the userspace side is not finished.
- **TFA9874 driver.** New, minimal, no speaker protection or calibration. The direction of its
  gain control and one TDM setting were inferred from the vendor configuration. Keep the volume low.
- **Kernel crashes are hard to see.** There is no serial console. A hard hang ends in Qualcomm
  Crashdump Mode; `tools/crashread.py` reads the ramoops region out of RAM over EDL before a reset
  wipes it.
- The board must never touch TLMM `gpio0-3` and `gpio59-62` (secure world); they are reserved in the
  device tree.

## What is in this repository

| Path | Content |
|---|---|
| `patches/` | Kernel changes against `v7.3-rc7`, one combined patch per subsystem, plus `COMMITS.txt` (the original commit list) |
| `config/` | Kconfig fragments merged over the arm64 `defconfig` |
| `scripts/` | Boot image packing, flash-and-test helper, rescue flashing |
| `initramfs/` | The small initramfs (`init`, rescue shell, `flashpart`) |
| `phone/` | Setup scripts that run on the phone (services, charge limit, desktop shells, USB internet) |
| `tools/` | Host and phone helpers (crash log reader, dtbo patcher, Wi-Fi board file builder, ...) |

**No firmware and no keys are included.** The modem/Wi-Fi, ADSP and GPU zap-shader firmware are
signed for this device and must be copied from your own phone (partition `modem_a`, directory
`image/`, and the vendor partition) into `/usr/lib/firmware/qcom/sm7250/oneplus/avicii/`.
`qcom/a650_sqe.fw` and `qcom/a650_gmu.bin` come from `linux-firmware`.

## Building

```sh
git clone --depth 1 --branch v7.3-rc7 https://github.com/torvalds/linux.git
cd linux
for p in ../patches/*.patch; do git apply --index "$p"; done

make O=../out ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- defconfig
ARCH=arm64 scripts/kconfig/merge_config.sh -m -O ../out ../out/.config ../config/avicii*.config
make O=../out ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- olddefconfig
make O=../out ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j"$(nproc)" Image.gz qcom/sm7250-oneplus-avicii.dtb
```

`scripts/pack.sh` shows the `mkbootimg` parameters (header v2, the kernel command line, offsets).
Everything is built in; no modules are loaded on the phone. The bootloader needs `dtbo_a` erased
to accept the mainline device tree.

The scripts were written for one machine and one phone. Read them before running them: they
assume paths, a rescue system in `recovery_a` and an unlocked bootloader, and flashing the wrong
partition can brick the device.

## Credits

- The SM7250 clock, pinctrl and base device tree work started from the SM7250 patch series by
  Sreeshankar K posted to the Linux kernel mailing lists, and uses mainline SM7150/SM6350/SM8250
  code by Danila Tikhonov, David Wronek and others as templates.
- Register values, stream IDs and sequences were taken from OnePlus' published downstream kernel
  source for this device.
- Most of the porting work was done with Claude (Anthropic) driving the builds and tests.

## License

Kernel patches: GPL-2.0-only, like the Linux kernel. Scripts and tools in this repository:
GPL-2.0-only unless a file says otherwise. See `LICENSE`.
