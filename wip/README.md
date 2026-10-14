# WIP: suspend (pm) and Bluetooth (bt2)

Patches on top of the `full` branch state (apply after patches/). `pm`: s2idle suspend + Type-C wake (verified: RTC wake works). `bt2`: Bluetooth is a WCN3991; RX wake IRQ removed from uart5 (verified: firmware loads, scan works). bt2 still contains HACK debug commits; drop them before upstreaming. Firmware loads only after rootfs (see bt-rebind.sh) and the controller needs a public address set (btmgmt public-addr).
