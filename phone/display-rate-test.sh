# Display refresh test (run on the phone as root over ssh: ssh ... root@172.16.42.1 sh -s < this). Switches 90->60->90 with kscreen-doctor, measures real frame rate with vkcube, counts kwin -EBUSY. 2026-10-16
export XDG_RUNTIME_DIR=/run/user/1001 WAYLAND_DISPLAY=wayland-0
as() { runuser -u arch -- env XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR WAYLAND_DISPLAY=$WAYLAND_DISPLAY "$@"; }
kd() { as kscreen-doctor "$@" 2>&1 | sed 's/\x1b\[[0-9;]*m//g'; }
S=/sys/kernel/debug/dri/0/crtc-0/status
run() { # label
  e0=$(journalctl --since now --no-pager 2>/dev/null | wc -l)
  fc0=$(grep -o 'total_framecount:[0-9]*' $S | cut -d: -f2); t0=$(date +%s.%N)
  as timeout 12 vkcube --wsi wayland >/dev/null 2>&1 &
  sleep 6; echo "$1 mid: $(grep vblank $S)"; sleep 6; wait
  fc1=$(grep -o 'total_framecount:[0-9]*' $S | cut -d: -f2); t1=$(date +%s.%N)
  echo "$1: frames $((fc1-fc0)) in $(echo "$t1 - $t0" | bc) s"
}
command -v vkcube bc >/dev/null || { echo "missing vkcube or bc"; command -v vkcube; command -v bc; }
echo "t0 errors=$(journalctl -b --no-pager | grep -c 'atomic commit failed')"
echo "== 90 Hz"; run 90
echo "errors now=$(journalctl -b --no-pager | grep -c 'atomic commit failed')"
kd output.DSI-1.mode.1 >/dev/null; sleep 3
echo "== 60 Hz"; run 60
echo "errors now=$(journalctl -b --no-pager | grep -c 'atomic commit failed')"
kd output.DSI-1.mode.2 >/dev/null; sleep 3; kd -o | grep -m1 Modes
