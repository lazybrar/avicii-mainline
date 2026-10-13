#!/bin/bash
# Build and install sxmo and its AUR dependencies. Run as root on the phone; builds as user alarm.
# usage: sxmo-aur.sh [pkg ...]   log: /var/tmp/sxmo-build/build.log
B=/var/tmp/sxmo-build; mkdir -p $B; chown alarm $B; cd $B
PKGS=${*:-pnc mnc superd light lisgd bonsai wvkbd mmsd-tng vvmd sxmo-utils-git}
for p in $PKGS; do
	if pacman -Q $p >/dev/null 2>&1; then echo "== $p already installed"; continue; fi
	echo "== $p"
	rm -rf $p; runuser -u alarm -- git clone -q https://aur.archlinux.org/$p.git || { echo "FAIL clone $p"; continue; }
	[ -f $p/PKGBUILD ] || { echo "FAIL no PKGBUILD $p"; continue; }
	deps=$(cd $p && runuser -u alarm -- makepkg --printsrcinfo | awk '/^\t(make|check)?depends = /{print $3}' | sed 's/[<>=].*//')
	for d in $deps; do pacman -Q $d >/dev/null 2>&1 || pacman -S --noconfirm --needed $d >/dev/null 2>&1 || echo "   (dep $d not in repos)"; done
	(cd $p && runuser -u alarm -- makepkg -f -d -A --skippgpcheck --noconfirm) > $p.log 2>&1 || { echo "FAIL build $p"; tail -15 $p.log; continue; }
	{ pacman -U --noconfirm $p/*.pkg.tar.* > $p.install.log 2>&1 || { echo "   (dependency check failed, forcing)"; grep -i "unable to satisfy\|breaks" $p.install.log; pacman -U --noconfirm -dd $p/*.pkg.tar.* >> $p.install.log 2>&1; }; } && echo "OK $p" || { echo "FAIL install $p"; tail -8 $p.install.log; }
done
echo "ALL DONE"
