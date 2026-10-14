#!/bin/bash
# Internet for the phone through the USB cable, without root on the PC:
# the PC opens `ssh -N -R 127.0.0.1:1080 root@172.16.42.1` (a SOCKS5 proxy on the phone that exits
# on the PC); sing-box on the phone routes all traffic into it while that proxy is up.
pacman -S --noconfirm --needed sing-box >/dev/null 2>&1; pacman -Q sing-box
mkdir -p /etc/sing-box
cat > /etc/sing-box/usb-internet.json <<'J'
{
  "log": { "level": "warn" },
  "dns": { "servers": [ { "type": "tcp", "tag": "remote", "server": "1.1.1.1", "detour": "usb" } ] },
  "inbounds": [
    { "type": "tun", "tag": "tun-in", "interface_name": "usbnet0", "address": [ "172.19.0.1/30", "fdfe:dcba:9876::1/126" ],
      "auto_route": true, "strict_route": false, "stack": "system" }
  ],
  "outbounds": [
    { "type": "socks", "tag": "usb", "server": "127.0.0.1", "server_port": 1080, "version": "5" },
    { "type": "direct", "tag": "direct" }
  ],
  "route": {
    "rules": [
      { "action": "sniff" },
      { "protocol": "dns", "action": "hijack-dns" },
      { "ip_is_private": true, "outbound": "direct" },
      { "network": "udp", "action": "reject" }
    ],
    "final": "usb",
    "auto_detect_interface": true
  }
}
J
sing-box check -c /etc/sing-box/usb-internet.json && echo config-ok
cat > /etc/systemd/system/usb-internet.service <<'U'
[Unit]
Description=Route internet through the USB cable (SOCKS tunnel opened by the PC)

[Service]
ExecStart=/usr/bin/sing-box run -c /etc/sing-box/usb-internet.json
Restart=on-failure
U
cat > /usr/local/bin/usb-internet-watch <<'W'
#!/bin/sh
# Run usb-internet.service only while the PC's tunnel (127.0.0.1:1080) is open.
while :; do
	if ss -ltnH 'sport = :1080' | grep -q 127.0.0.1; then
		systemctl is-active -q usb-internet || systemctl start usb-internet
	else
		systemctl is-active -q usb-internet && systemctl stop usb-internet
	fi
	sleep 3
done
W
chmod 755 /usr/local/bin/usb-internet-watch
cat > /etc/systemd/system/usb-internet-watch.service <<'U'
[Unit]
Description=Switch internet to the USB cable when the PC tunnel is up

[Service]
ExecStart=/usr/local/bin/usb-internet-watch
Restart=always

[Install]
WantedBy=multi-user.target
U
systemctl daemon-reload; systemctl enable --now usb-internet-watch >/dev/null 2>&1; systemctl is-active usb-internet-watch; sync
