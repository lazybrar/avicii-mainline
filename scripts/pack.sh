#!/bin/bash
cd "$(dirname "$0")"
mkbootimg --header_version 2 --kernel out/arch/arm64/boot/Image.gz --ramdisk initramfs-gpu.cpio.gz --dtb out/arch/arm64/boot/dts/qcom/sm7250-oneplus-avicii.dtb --pagesize 4096 --base 0x0 --kernel_offset 0x8000 --ramdisk_offset 0x1000000 --tags_offset 0x100 --dtb_offset 0x1f00000 --cmdline "clk_ignore_unused pd_ignore_unused regulator_ignore_unused watchdog.handle_boot_enabled=0 nord.boot=debian console=tty0 fbcon=font:TER16x32 loglevel=8 ignore_loglevel printk.time=1 printk.devkmsg=on rdinit=/init panic=5" -o avicii.img
