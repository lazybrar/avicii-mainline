#!/bin/bash
# Run on the PC. Starts the compute DSP and binds the venus video driver now that
# their firmware is on the rootfs (both tried at ~0.8 s, before rootfs, and gave up).
# Each step leaves a /dev/kmsg marker; if the phone hangs, the last marker is the culprit.
cd "$(dirname "$0")"
S="ssh -i ../keys/nord_ed25519 -o UserKnownHostsFile=../keys/known_hosts -o BatchMode=yes -o ConnectTimeout=6 root@172.16.42.1"
exec 9>/tmp/nord-phone.lock; flock 9
$S 'bash -s' <<'EOF'
echo TEST_CDSP > /dev/kmsg
R=$(dirname "$(grep -l cdsp /sys/class/remoteproc/*/name)")
echo start > $R/state; sleep 5
echo "cdsp: $(cat $R/state)  fastrpc: $(ls /dev/fastrpc-* | tr '\n' ' ')"
dmesg | sed -n '/TEST_CDSP/,$p' | grep -iE "cdsp|fastrpc|fail|error" | tail -6 | cut -c1-160
echo TEST_VENUS > /dev/kmsg
echo aa00000.video-codec > /sys/bus/platform/drivers/qcom-venus/bind; sleep 3
echo "video: $(ls /dev/video* 2>/dev/null | tr '\n' ' ')"
dmesg | sed -n '/TEST_VENUS/,$p' | grep -iE "venus|video|fail|error" | tail -8 | cut -c1-160
v4l2-ctl --list-devices 2>/dev/null | head -8
EOF
