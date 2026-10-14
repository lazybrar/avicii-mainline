#!/bin/bash
# Plasma Mobile session for user arch on tty1 (autologin already set up), plus brave-bin from the AUR.
pacman -S --noconfirm --needed plasma-mobile plasma-keyboard plasma-settings kscreen plasma-nm plasma-pa powerdevil breeze qt6-wayland xdg-desktop-portal-kde kde-cli-tools > /var/tmp/plasma.log 2>&1; echo "plasma rc=$?"; tail -1 /var/tmp/plasma.log | cut -c1-120
sync
ls /usr/bin/startplasmamobile /usr/share/wayland-sessions/ 2>&1
rm -f /home/arch/.config/fish/conf.d/phosh.fish /home/arch/.config/fish/conf.d/sxmo.fish
cat > /home/arch/.config/fish/conf.d/plasma-mobile.fish <<'F'
# Start Plasma Mobile on the phone screen after autologin on tty1.
if status is-login; and test (tty) = /dev/tty1; and not set -q WAYLAND_DISPLAY
    exec startplasmamobile
end
F
# never suspend or lock by itself (suspend is untested on this kernel); screen off after 5 min
install -d -o arch -g arch /home/arch/.config
cat > /home/arch/.config/powerdevilrc <<'P'
[AC][SuspendAndShutdown]
AutoSuspendAction=0
PowerButtonAction=0

[Battery][SuspendAndShutdown]
AutoSuspendAction=0
PowerButtonAction=0

[LowBattery][SuspendAndShutdown]
AutoSuspendAction=0
PowerButtonAction=0
P
cat > /home/arch/.config/kscreenlockerrc <<'P'
[Daemon]
Autolock=false
LockOnResume=false
P
chown arch:arch /home/arch/.config/powerdevilrc /home/arch/.config/kscreenlockerrc /home/arch/.config/fish/conf.d/plasma-mobile.fish
sync
/root/sxmo-aur.sh brave-bin 2>&1 | tail -6 | cut -c1-200
pacman -Q brave-bin 2>&1
