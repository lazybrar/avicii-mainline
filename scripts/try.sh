#!/bin/bash
# try.sh IMAGE [LOGNAME]
# Wait for the phone to be in the downstream rescue system (recovery, kernel 4.19), flash IMAGE
# to boot_a from there, reboot into it and report what came up. If it lands in Qualcomm
# Crashdump Mode, pull the ramoops console out of RAM into logs/LOGNAME/.
# Getting from Crashdump Mode back to recovery is manual: VolUp+Power ~10 s, then VolDown+Power.
set -u
M=$(dirname "$(readlink -f "$0")"); L=$(dirname "$M"); TOP=$(dirname "$L")
IMG=$(readlink -f "$1"); NAME=${2:-crash-$(date +%H%M%S)}
SUM=$(sha256sum "$IMG" | cut -d' ' -f1)
PORT=$((8200 + RANDOM % 700)); SRV=$(mktemp -d); trap 'rm -rf "$SRV"; kill $HTTP 2>/dev/null' EXIT
cp "$IMG" "$SRV/boot.img"

ver() { lsusb -v -d 1d6b:0104 2>/dev/null | awk '/bcdDevice/{print $2}'; }
echo "waiting for rescue system (kernel 4.19) on USB..."
for _ in $(seq 1 520); do [ "$(ver)" = "4.19" ] && break; sleep 1; done
[ "$(ver)" = "4.19" ] || { echo "rescue system did not appear; USB now:"; lsusb | grep -viE 'root hub|Camera|Bluetooth'; exit 1; }
for _ in $(seq 1 20); do ping -c1 -W1 172.16.42.1 >/dev/null 2>&1 && break; sleep 1; done

(cd "$SRV" && exec python3 -m http.server $PORT --bind 172.16.42.2 >/dev/null 2>&1) & HTTP=$!
sleep 1
PSH_TIMEOUT=90 python3 "$L/psh.py" "flashpart boot_a http://172.16.42.2:$PORT/boot.img $SUM" | tee /dev/stderr | grep -q verified || { echo "flash failed"; exit 1; }
python3 "$L/psh.py" '{ (sleep 1; rebootto) >/dev/null 2>&1 & }' >/dev/null 2>&1
for _ in $(seq 1 30); do lsusb | grep -q 1d6b:0104 || break; sleep 0.5; done
for _ in $(seq 1 90); do lsusb | grep -qE '1d6b:0104|05c6:900e|18d1:d00d' && break; sleep 1; done

if lsusb | grep -q 05c6:900e; then
	echo "RESULT: crashdump"
	D="$M/logs/$NAME"
	"$TOP/tools/edl-venv/bin/python" "$L/tools/crashread.py" "$D" 0xcbe00000:0x400000:ramoops 2>&1 | grep -E '^ramoops'
	python3 - "$D" <<'EOF'
import re, sys
d = open(sys.argv[1] + '/ramoops.bin', 'rb').read()[0x17f000 + 12:0x17f000 + 0x40000]
L = []
for l in d.decode(errors='replace').split('\n'):
    if re.match(r'^\[\s*\d+\.\d{6}\] ', l): L.append(l)
    elif L: break
open(sys.argv[1] + '/mainline-console.txt', 'w').write('\n'.join(L) + '\n')
print('console lines:', len(L)); print('\n'.join(x[:170] for x in L[-8:]))
EOF
elif [ "$(ver)" = "4.19" ]; then echo "RESULT: back in rescue (4.19)"
elif lsusb | grep -q 1d6b:0104; then echo "RESULT: booted, gadget kernel version $(ver)"
else echo "RESULT: unknown"; lsusb | grep -viE 'root hub|Camera|Bluetooth'; fi
