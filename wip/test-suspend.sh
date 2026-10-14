#!/bin/bash
# Suspend test for the avicii-pm image, run on the PC. Usage:
#   test-suspend.sh [LEVEL]
# LEVEL = freezer | devices | platform | processors | core   (pm_test dry runs: go through that
#         stage, wait 5 s, resume; the board never really sleeps)
#       | freeze                                              (real s2idle, wake by RTC after 20 s)
# Safe order: freezer, devices, platform, processors, core, then freeze. Default: devices.
# Env: KEEP_WIFI=1 leaves wlan0 up (default: wlan0 is set down first, ath10k has no WoWLAN).
# Everything runs under flock /tmp/nord-phone.lock. The phone side runs detached, because the
# USB gadget (our ssh link) drops while the board sleeps; the PC polls until ssh answers again.
set -u
cd "$(dirname "$0")"
LEVEL=${1:-devices}
case $LEVEL in freezer|devices|platform|processors|core|freeze) ;; *) echo "bad level $LEVEL" >&2; exit 2;; esac
S="ssh -i ../keys/nord_ed25519 -o UserKnownHostsFile=../keys/known_hosts -o BatchMode=yes -o ConnectTimeout=5 root@172.16.42.1"
LOG=../mainline/logs/suspend-$LEVEL-$(date +%Y%m%d-%H%M%S).txt
mkdir -p ../mainline/logs
exec 9>/tmp/nord-phone.lock; flock 9

$S 'bash -s' "$LEVEL" "${KEEP_WIFI:-0}" > "$LOG" 2>&1 <<'EOF'
LEVEL=$1; KEEP_WIFI=$2
[ -w /sys/power/pm_test ] || { echo "no /sys/power/pm_test: image lacks CONFIG_PM_DEBUG"; exit 1; }
grep -q freeze /sys/power/state || { echo "freeze unsupported"; exit 1; }
cat > /run/suspend-test.sh <<'EOS'
LEVEL=$1; KEEP_WIFI=$2
L=/run/suspend-test.log; : > $L
k() { echo "suspend-test: $*" > /dev/kmsg; echo "$*" >> $L; }
echo 1 > /sys/power/pm_debug_messages
echo 1 > /sys/power/pm_print_times 2>/dev/null
[ "$KEEP_WIFI" = 1 ] || ip link set wlan0 down 2>/dev/null
sync
if [ "$LEVEL" = freeze ]; then
  echo none > /sys/power/pm_test
  echo freeze > /sys/power/mem_sleep 2>/dev/null
  RT=/sys/class/rtc/rtc0
  NOW=$(cat $RT/since_epoch)
  echo 0 > $RT/wakealarm; echo $((NOW+20)) > $RT/wakealarm
  k "BEGIN freeze rtc_now=$NOW alarm=$(cat $RT/wakealarm)"
else
  echo $LEVEL > /sys/power/pm_test
  k "BEGIN pm_test=$LEVEL"
fi
echo freeze > /sys/power/state; rc=$?
k "END rc=$rc"
echo none > /sys/power/pm_test
[ "$KEEP_WIFI" = 1 ] || ip link set wlan0 up 2>/dev/null
echo done >> $L
EOS
setsid nohup bash /run/suspend-test.sh "$LEVEL" "$KEEP_WIFI" >/dev/null 2>&1 < /dev/null &
echo started
EOF
cat "$LOG"
grep -q started "$LOG" || exit 1

echo "waiting for resume (up to 120 s)..."
sleep 8
for i in $(seq 1 56); do
  if $S 'grep -q "^done" /run/suspend-test.log' 2>/dev/null; then OK=1; break; fi
  sleep 2
done
if [ "${OK:-0}" != 1 ]; then
  echo "NO RESUME after ~2 min: see recovery in the header notes (hold power ~10 s, then boot avicii-full2)." | tee -a "$LOG"
  exit 3
fi
$S 'bash -s' >> "$LOG" 2>&1 <<'EOF'
echo "== test log"; cat /run/suspend-test.log
echo "== suspend_stats"; cat /sys/kernel/debug/suspend_stats 2>&1
echo "== wakeup sources with events"; for w in /sys/class/wakeup/*; do echo "$(cat $w/name) active=$(cat $w/active_count) wakeups=$(cat $w/wakeup_count) last_ms=$(cat $w/last_time_ms)"; done | sort -k2 | head -20
echo "== dmesg since BEGIN"
dmesg | sed -n '/suspend-test: BEGIN/,$p' | grep -v "^\[.*\] \(wlan0\|audit\)" | tail -150 | cut -c1-200
echo "== failures"; dmesg | sed -n '/suspend-test: BEGIN/,$p' | grep -iE "fail|error|timed out|-110|-16 |blocked" | head -20 | cut -c1-200
echo "== cpuidle residency"; grep . /sys/devices/system/cpu/cpu0/cpuidle/state*/{name,time,usage} 2>/dev/null | tr '\n' ' '; echo
EOF
echo "log: $LOG"
