# QSEECOM (/dev/qseecom) for the OnePlus Nord

Three patches on top of the avicii tree: SCM load/unload helpers, a `/dev/qseecom`
misc device with the downstream ioctl numbers (version, app query, load, unload,
send command), and the `oneplus,avicii` allowlist entry.

Status: builds (arm64, `CONFIG_QCOM_QSEECOM_DEV=y`) and boots on the Nord. Tested on
the phone: version query (0x1402000), app query (found `qcom.tz.uefisecapp`,
`keymaster64`; ENOENT for an unknown name) and the error paths (EBADF, EINVAL,
ENOTTY). Not tested: loading a real app image and sending commands to an app.
Listeners are not supported, so apps needing RPMB or the secure file system will not work.
