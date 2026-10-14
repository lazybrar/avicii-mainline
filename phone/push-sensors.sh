#!/bin/bash
# Run on the PC: push the sensor config + generated registry, run sensors-setup.sh,
# start the sensor file daemon and watch 100 s for ADSP crashes.
set -e
cd "$(dirname "$0")"
S="ssh -i ../keys/nord_ed25519 -o UserKnownHostsFile=../keys/known_hosts -o BatchMode=yes -o ConnectTimeout=5 root@172.16.42.1"
exec 9>/tmp/nord-phone.lock; flock 9
tar -cf - sensors-config sensors-registry-gen | $S 'cat > /tmp/sensors-payload.tar'
$S 'bash -s' < sensors-setup.sh | tail -1
$S 'bash -s' <<'EOF'
echo SENSORS_TEST_START > /dev/kmsg
systemctl start hexagonrpcd-adsp-sensorspd
sleep 100
echo "daemon: $(systemctl is-active hexagonrpcd-adsp-sensorspd)"
echo "adsp crashes since start: $(dmesg | sed -n '/SENSORS_TEST_START/,$p' | grep -c 'crash detected in adsp')"
dmesg | sed -n '/SENSORS_TEST_START/,$p' | grep -iE 'PDM|adsp|fastrpc' | tail -6 | cut -c1-170
journalctl -u hexagonrpcd-adsp-sensorspd --no-pager -n 8 | cut -c1-170
EOF
