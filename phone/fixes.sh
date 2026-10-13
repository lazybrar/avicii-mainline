#!/bin/bash
# Small fixes for the avicii Arch install. Run as root on the phone.
set -e
cat > /etc/systemd/system/charge-limit.service <<'U'
[Unit]
Description=Battery charge limit (stop at 80%, resume at 75%)
ConditionPathExists=/sys/class/power_supply/pm7250b-usb/charge_control_end_threshold

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'echo 80 > /sys/class/power_supply/pm7250b-usb/charge_control_end_threshold; echo 75 > /sys/class/power_supply/pm7250b-usb/charge_control_start_threshold'

[Install]
WantedBy=multi-user.target
U
# ath10k has no MAC in the device tree and picks a random one each boot: pin one.
# Pass your own as the first argument, or a stable locally administered one is derived from machine-id.
MAC=${1:-$(sed 's/^\(..\)\(..\)\(..\)\(..\)\(..\).*/02:\1:\2:\3:\4:\5/' /etc/machine-id)}
mkdir -p /etc/systemd/network
cat > /etc/systemd/network/10-wlan0-mac.link <<U
[Match]
Driver=ath10k_snoc

[Link]
MACAddressPolicy=none
MACAddress=$MAC
U
# A short power-key press must not power the phone off (sxmo handles the key).
mkdir -p /etc/systemd/logind.conf.d
printf '[Login]\nHandlePowerKey=ignore\nHandlePowerKeyLongPress=poweroff\n' > /etc/systemd/logind.conf.d/10-powerkey.conf
systemctl daemon-reload
systemctl enable --now charge-limit.service
cat /sys/class/power_supply/pm7250b-usb/charge_control_end_threshold /sys/class/power_supply/pm7250b-usb/charge_control_start_threshold
echo "fixes done, MAC=$MAC"
