#!/bin/bash
# Idempotent phone-side setup for hexagonrpcd + SSC sensors (run as root on the phone).
# From PC (not yet tested on the device; phone went into rescue before the test):
#   cd ~/work/nord-unbrick/linux/phone
#   tar -cf - sensors-config sensors-registry-gen | ssh ... root@172.16.42.1 'cat > /tmp/sensors-payload.tar'
#   ssh ... root@172.16.42.1 'bash -s' < sensors-setup.sh
# Layout follows hexagonrpcd README: <root>/sensors/{config,registry,sns_reg.conf}, <root>/socinfo.
# Registry is GENERATED (sscregistrygen -p MTP -s 400 from stock /vendor/etc/sensors/config),
# because hexagonrpcd is read-only: the persist copy needs writes (../temp.json, ../sns_reg_version).
# Needs on phone: nothing new (hexagonrpcd, libssc, iio-sensor-proxy already installed).
set -e
D=/usr/share/qcom/sm7250/oneplus/avicii
P=/tmp/sensors-payload.tar
W=$(mktemp -d)
[ -f $P ] && tar -xf $P -C $W
mkdir -p $D/sensors/config $D/sensors/registry $D/socinfo
# keep the old persist copy out of the served tree
if [ -d $D/sensors/registry/registry ] && [ ! -d $D/sensors/registry-persist-orig ]; then
  mv $D/sensors/registry $D/sensors/registry-persist-orig; mkdir $D/sensors/registry
fi
[ -d $W/sensors-config ] && cp -r $W/sensors-config/. $D/sensors/config/
[ -d $W/sensors-registry-gen ] && cp -r $W/sensors-registry-gen/. $D/sensors/registry/
# socinfo emulation (/sys/devices/soc0): real values where mainline has them
for f in soc_id revision; do cat /sys/devices/soc0/$f > $D/socinfo/$f; done
echo MTP > $D/socinfo/hw_platform
echo 0 > $D/socinfo/platform_subtype_id
echo Unknown > $D/socinfo/platform_subtype
echo 65536 > $D/socinfo/platform_version
chown -R fastrpc:fastrpc $D
rm -rf $W
# env file used by the stock unit
echo "hexagonrpcd_fw_dir=$D" > /etc/conf.d/hexagonrpcd-adsp-sensorpd
echo "setup done. Then: systemctl start hexagonrpcd-adsp-sensorspd iio-sensor-proxy; watch dmesg for PDM/DOG; monitor-sensor"
