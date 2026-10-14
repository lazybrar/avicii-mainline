#!/bin/bash
# Run on the PC with the phone on stock Android (adb): copy the SSC sensor config from YOUR phone.
# These JSON files are OnePlus/Qualcomm property and are not distributed in this repository.
# Then generate the registry with sscregistrygen (-p MTP -s 400) and use push-sensors.sh.
set -e
cd "$(dirname "$0")"; mkdir -p sensors-config
adb pull /vendor/etc/sensors/config/. sensors-config/
