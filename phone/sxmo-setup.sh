set -e
sed -n 78,92p /usr/bin/sxmo_wm.sh
cat > '/usr/local/bin/sxmo_deviceprofile_oneplus,avicii.sh' <<'P'
#!/bin/sh
# sxmo device profile: OnePlus Nord (avicii), mainline kernel

export SXMO_VOLUME_BUTTON="1:1:gpio-keys"
export SXMO_POWER_BUTTON="0:0:pm8941_pwrkey"
export SXMO_MONITOR="DSI-1"
export SXMO_TOUCHSCREEN_ID="Goodix GT9886 Touchscreen"
export SXMO_SWAY_SCALE="3"
P
chmod 755 '/usr/local/bin/sxmo_deviceprofile_oneplus,avicii.sh'
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf <<'U'
[Service]
ExecStart=
ExecStart=-/sbin/agetty -o '-p -f -- \\u' --noclear --autologin arch %I $TERM
U
install -d -o arch -g arch /home/arch/.config/sxmo /home/arch/.config/fish/conf.d
cat > /home/arch/.config/fish/conf.d/sxmo.fish <<'F'
# Start sxmo (sway) on the phone screen after autologin on tty1.
if status is-login; and test (tty) = /dev/tty1; and not set -q WAYLAND_DISPLAY
    exec sxmo_swayinit.sh
end
F
[ -f /home/arch/.config/sxmo/profile ] || cp /usr/share/sxmo/appcfg/profile_template /home/arch/.config/sxmo/profile
sed -i 's|^# export SXMO_TERMINAL="st"|export SXMO_TERMINAL="alacritty"|' /home/arch/.config/sxmo/profile
grep -n 'SXMO_TERMINAL' /home/arch/.config/sxmo/profile
chown -R arch:arch /home/arch/.config/sxmo /home/arch/.config/fish/conf.d
loginctl enable-linger arch 2>/dev/null || true
systemctl daemon-reload
echo setup-ok; sync
# afterwards appended to the device profile:
#   export SXMO_SUSPENDABLE_STATES="nosuspend 0"
