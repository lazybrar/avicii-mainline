#!/bin/bash
# Run on the PC after avicii-full2.img has booted. Installs modules, deploys the updated
# nord-modem starter, starts cdsp, loads venus, and saves the results to logs/full2-test.txt.
set -e
cd "$(dirname "$0")"
S="ssh -i ../keys/nord_ed25519 -o UserKnownHostsFile=../keys/known_hosts -o BatchMode=yes -o ConnectTimeout=6 root@172.16.42.1"
OUT=../mainline/logs/full2-test.txt
bash ./install-modules.sh 2>&1 | tail -2
exec 9>/tmp/nord-phone.lock; flock 9
$S 'cat > /usr/local/bin/nord-modem && chmod 755 /usr/local/bin/nord-modem' < nord-modem.sh
$S 'bash -s' > "$OUT" 2>&1 <<'EOF'
echo TEST_FULL2 > /dev/kmsg
nord-modem start 2>&1 | tail -3; sleep 5
modprobe venus-core 2>&1; modprobe venus-dec 2>&1; modprobe venus-enc 2>&1; sleep 3
for r in /sys/class/remoteproc/*; do echo "$(cat $r/name) $(cat $r/state)"; done
ls /dev/fastrpc-* /dev/video* 2>/dev/null | tr '\n' ' '; echo
dmesg | grep -E 'HACK pas|qcom_scm' | cut -c1-200
dmesg | sed -n '/TEST_FULL2/,$p' | grep -iE 'cdsp|venus|remoteproc|fail|error' | tail -15 | cut -c1-200
dmesg | grep -iE 'hci0|qca' | tail -6 | cut -c1-160
cat /proc/cmdline | grep -o 'msm.tc_sync[^ ]*'
EOF
cat "$OUT"
