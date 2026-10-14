#!/bin/sh
# nord-modem start|stop: start or stop the modem (Wi-Fi), ADSP (audio) and CDSP remote processors.
# They are found by name; their index depends on probe order. Their firmware lives on the root
# filesystem, so the kernel's own attempt at boot (before root is mounted) fails (cdsp does not
# auto-boot at all). A failing cdsp (PAS error) must not stop the others from starting.
rc=1
for r in /sys/class/remoteproc/remoteproc*; do
	case "$(cat "$r/name")" in modem|adsp|cdsp) ;; *) continue ;; esac
	s=$(cat "$r/state")
	case "$1:$s" in start:running|stop:offline) rc=0; continue ;; esac
	echo "$1" > "$r/state" && rc=0
done
exit $rc
