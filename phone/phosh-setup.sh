#!/bin/bash
# Replace the sxmo session with phosh for user arch, and move Wi-Fi to NetworkManager (iwd backend).
set -e
grep -n 'phoc.ini\|PHOC_INI' /usr/bin/phosh-session | head -5
mkdir -p /etc/phosh
cat > /etc/phosh/phoc.ini <<'P'
[core]
xwayland=false

[output:DSI-1]
scale = 3
P
# session start: phosh instead of sxmo
rm -f /home/arch/.config/fish/conf.d/sxmo.fish
cat > /home/arch/.config/fish/conf.d/phosh.fish <<'F'
# Start phosh on the phone screen after autologin on tty1.
if status is-login; and test (tty) = /dev/tty1; and not set -q WAYLAND_DISPLAY
    exec phosh-session
end
F
chown arch:arch /home/arch/.config/fish/conf.d/phosh.fish
# no automatic lock, blank after 5 min, never auto-suspend (suspend is untested on this kernel)
runuser -u arch -- env XDG_RUNTIME_DIR=/run/user/$(id -u arch) HOME=/home/arch dbus-run-session sh -c '
gsettings set org.gnome.desktop.screensaver lock-enabled false
gsettings set org.gnome.desktop.session idle-delay 300
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type nothing
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type nothing
gsettings set org.gnome.settings-daemon.plugins.power power-button-action nothing
gsettings set sm.puri.phosh.plugins.launcher-box folder "" 2>/dev/null || true
'
systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target >/dev/null 2>&1
# NetworkManager on top of iwd; usb0 stays with systemd-networkd
mkdir -p /etc/NetworkManager/conf.d
cat > /etc/NetworkManager/conf.d/10-avicii.conf <<'N'
[device]
wifi.backend=iwd

[keyfile]
unmanaged-devices=interface-name:usb0
N
sed -i 's/^EnableNetworkConfiguration=true/EnableNetworkConfiguration=false/' /etc/iwd/main.conf
systemctl enable NetworkManager >/dev/null 2>&1
echo phosh-setup-ok; sync
