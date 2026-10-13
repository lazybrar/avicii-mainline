#!/bin/sh
# Assemble initramfs.cpio.gz from the Alpine minirootfs + busybox-extras + ./init
set -e
cd "$(dirname "$0")"
rm -rf root && mkdir root
tar -xzf dl/alpine-minirootfs-*-aarch64.tar.gz -C root
cp dl/bbx/bin/busybox-extras root/bin/busybox-extras
chmod 755 root/bin/busybox-extras
install -m 755 init root/init
install -m 755 ../tools/drmtext ../tools/rebootto flashpart root/usr/bin/
(cd root && find . | cpio -o -H newc -R 0:0 2>/dev/null | gzip -9) > initramfs.cpio.gz
ls -la initramfs.cpio.gz
