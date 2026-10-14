#!/bin/bash
# Run on the PC. hci_qca is built in and asks for qca/crbtfw32.tlv before the rootfs is up;
# re-binding the serdev device after boot lets the firmware load. Then scan 10 s.
cd "$(dirname "$0")"
S="ssh -i ../keys/nord_ed25519 -o UserKnownHostsFile=../keys/known_hosts -o BatchMode=yes root@172.16.42.1"
exec 9>/tmp/nord-phone.lock; flock 9
$S 'bash -s' <<'EOF'
D=$(basename "$(readlink -f /sys/bus/serial/drivers/hci_uart_qca/*-0 2>/dev/null | head -1)")
[ -n "$D" ] || D=$(ls /sys/bus/serial/devices | head -1)
echo "serdev: $D"
echo BT_REBIND > /dev/kmsg
echo "$D" > /sys/bus/serial/drivers/hci_uart_qca/unbind 2>&1; sleep 1
echo "$D" > /sys/bus/serial/drivers/hci_uart_qca/bind; sleep 6
dmesg | sed -n '/BT_REBIND/,$p' | grep -iE 'hci0|qca|bluetooth' | tail -8 | cut -c1-150
btmgmt info 2>/dev/null | head -4
bluetoothctl power on 2>/dev/null | tail -1
timeout 12 bluetoothctl --timeout 10 scan on 2>/dev/null | grep -c 'NEW.*Device'
EOF
