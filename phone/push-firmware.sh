#!/bin/bash
# Run on the PC: extract venus + cdsp firmware from img/modem.img (rootless, 7z)
# and push to /lib/firmware/qcom/sm7250/oneplus/avicii/ (the DT firmware-name dir).
# Idempotent: rewrites the same files each run. Does not reboot or load anything.
set -e
cd "$(dirname "$0")"
# Must be the phone's own modem_a: img/modem.img is an older build and TZ rejects its
# cdsp/venus (-22). Refresh with: ssh ... 'cat /dev/disk/by-partlabel/modem_a' > backup/live/modem_a.bin
IMG=${IMG:-../../backup/live/modem_a.bin}
DST=/lib/firmware/qcom/sm7250/oneplus/avicii
S="ssh -i ../keys/nord_ed25519 -o UserKnownHostsFile=../keys/known_hosts -o BatchMode=yes -o ConnectTimeout=5 root@172.16.42.1"
T=$(mktemp -d /tmp/nord-fw.XXXXXX)
trap 'rm -rf "$T"' EXIT
7z e -y -bso0 -bsp0 -o"$T" "$IMG" 'image/venus.mdt' 'image/venus.b*' 'image/cdsp.mdt' 'image/cdsp.b*' || [ $? -eq 2 ]  # rc 2 = harmless trailing-truncation warning of the dump
[ "$(ls "$T" | wc -l)" -ge 17 ]
ls "$T"/venus.mdt "$T"/cdsp.mdt >/dev/null
echo "extracted: $(ls "$T" | wc -l) files, $(du -sh "$T" | cut -f1)"
exec 9>/tmp/nord-phone.lock; flock 9
tar -C "$T" -cf - . | $S "mkdir -p $DST && tar -C $DST -xf - --no-same-owner && chmod 644 $DST/venus.* $DST/cdsp.* && ls $DST | grep -cE '^(venus|cdsp)\.'"
$S 'bash -c '\''for r in /sys/class/remoteproc/*; do echo "$(basename $r) $(cat $r/name) $(cat $r/state)"; done; dmesg | grep -iE "venus|cdsp" | tail -15 | cut -c1-170'\'
