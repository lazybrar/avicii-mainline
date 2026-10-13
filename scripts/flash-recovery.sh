#!/bin/bash
# Write an image to recovery_a over EDL, verify it, and boot it via "adb reboot recovery".
# Works from fastboot, stock OOS (adb), or our own initramfs (telnet on 172.16.42.1).
# fastboot downloads stall on this phone, so everything goes through EDL.
# usage: flash-recovery.sh [image]   (default boot/test-recovery.img)
set -u
D=$(dirname "$(readlink -f "$0")")
IMG=$(readlink -f "${1:-$D/boot/test-recovery.img}")
TOP=$(dirname "$D")
EDLOPT="--lun=4 --skipstorageinit --loader=$TOP/fhprg_opnord.bin --devicemodel=20801 --memory=ufs"
RB=$(mktemp)
trap 'rm -f "$RB"' EXIT

has() { lsusb | grep -q "$1"; }
wait_usb() { for _ in $(seq 1 "$2"); do has "$1" && return 0; sleep 0.5; done; return 1; }

if has 1d6b:0104; then
	python3 "$D/psh.py" '{ (sleep 1; rebootto edl || /tmp/rebootto edl) >/dev/null 2>&1 & }' >/dev/null
elif has 18d1:d00d; then
	timeout 10 fastboot reboot >/dev/null 2>&1
fi
if ! has 05c6:9008; then
	wait_usb 05c6:9008 6 || { timeout 110 adb wait-for-usb-device && adb reboot edl; }
fi
wait_usb 05c6:9008 60 || { echo "phone did not reach EDL"; exit 1; }

timeout 200 edl w recovery_a "$IMG" $EDLOPT 2>&1 | grep -E '^Wrote|rror|Fail'
timeout 200 edl r recovery_a "$RB" $EDLOPT 2>&1 | grep -E 'rror|Fail'
cmp -n "$(stat -c %s "$IMG")" "$RB" "$IMG" || { echo "VERIFY FAILED"; exit 1; }
echo "verify ok"
timeout 60 edl reset --loader="$TOP/fhprg_opnord.bin" --devicemodel=20801 >/dev/null 2>&1

timeout 110 adb wait-for-usb-device || { echo "stock system did not come up"; exit 1; }
adb reboot recovery
for _ in $(seq 1 100); do
	lsusb | grep -qE '1d6b:0104|05c6:9008|18d1:d00d' && break
	sleep 1
done
if has 1d6b:0104; then
	for _ in $(seq 1 20); do ping -c1 -W1 172.16.42.1 >/dev/null 2>&1 && break; sleep 1; done
	echo "BOOTED: our kernel is up"
elif has 18d1:d00d; then
	echo "REJECTED: bootloader fell back to fastboot"; exit 2
else
	echo "UNKNOWN state:"; lsusb; exit 3
fi
