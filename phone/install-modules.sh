#!/bin/bash
# Run on the PC. Installs the kernel modules of the full build (venus etc.) on the phone.
# Needs the phone booted with the matching kernel (same kernelrelease), ssh over USB.
set -e
cd "$(dirname "$0")/../mainline"
export ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-
O=out-full
STAGE=/tmp/nord-modules
KREL=$(make -s -C linux-full O="$PWD/$O" kernelrelease)
rm -rf "$STAGE"; mkdir -p "$STAGE"
make -C linux-full O="$PWD/$O" modules_install INSTALL_MOD_PATH="$STAGE" INSTALL_MOD_STRIP=1 -j8
# the release baked into the build (include/config/kernel.release) can differ from what
# `make kernelrelease` reports after later commits; trust the installed directory name
KREL=$(ls "$STAGE/lib/modules")
rm -f "$STAGE/lib/modules/$KREL/build"
S="ssh -i ../keys/nord_ed25519 -o UserKnownHostsFile=../keys/known_hosts -o BatchMode=yes root@172.16.42.1"
echo "kernelrelease: $KREL (phone runs: $($S uname -r))"
tar -C "$STAGE/lib/modules" -cf - "$KREL" | $S "mkdir -p /lib/modules && tar -C /lib/modules -xf - && depmod $KREL"
echo "installed to /lib/modules/$KREL"
