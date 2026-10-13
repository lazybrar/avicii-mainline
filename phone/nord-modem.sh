#!/bin/sh
# nord-modem start|stop: start or stop the modem (Wi-Fi) and ADSP (audio) remote processors.
# They are found by name; their index depends on probe order. Their firmware lives on the root
# filesystem, so the kernel's own attempt at boot (before root is mounted) fails.
rc=1
for r in /sys/class/remoteproc/remoteproc*; do
	case "$(cat "$r/name")" in modem|adsp) ;; *) continue ;; esac
	s=$(cat "$r/state")
	case "$1:$s" in start:running|stop:offline) rc=0; continue ;; esac
	echo "$1" > "$r/state" && rc=0
done
exit $rc
