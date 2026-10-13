#!/bin/bash
# mkpublish.sh OUTDIR: assemble the public repository contents (patches, configs, scripts) from the
# working tree. Kernel changes are exported as one patch per subsystem against the base tag.
set -e
TOP=$(dirname "$(dirname "$(dirname "$(readlink -f "$0")")")"); L=$TOP/linux; M=$L/mainline; K=$M/linux-audio
OUT=$(readlink -f "$1"); BASE=v7.3-rc7; BR=audio
rm -rf "$OUT"/{patches,config,scripts,phone,tools,initramfs}; mkdir -p "$OUT"/{patches,config,scripts,phone,tools,initramfs}
n=0
topic() { # topic NAME TITLE PATH...
	local name=$1 title=$2; shift 2; n=$((n+1)); local f; f=$(printf '%s/patches/%02d-%s.patch' "$OUT" $n "$name")
	{ echo "Subject: $title"; echo; echo "Combined diff of the following commits (base $BASE):"; echo
	  git -C "$K" log --no-merges --reverse --format='  - %s' $BASE..$BR -- "$@"; echo; echo "---"
	  git -C "$K" diff --stat=100 $BASE..$BR -- "$@"; echo
	  git -C "$K" diff $BASE..$BR -- "$@"; } > "$f"
}
topic bindings   "dt-bindings for SM7250 and OnePlus avicii" Documentation include
topic clk        "clk: qcom: SM7250 clock controllers" drivers/clk
topic pinctrl    "pinctrl: qcom: SM7250 TLMM" drivers/pinctrl
topic soc-pm     "soc/pmdomain/phy: qcom: SM7250 support" drivers/soc drivers/pmdomain drivers/phy
topic ufs        "ufs: qcom: SM7250 fixes" drivers/ufs
topic display    "drm: SM7250 display, Samsung AMS644VK04 panel, Adreno 620" drivers/gpu
topic iommu      "iommu/arm-smmu-qcom: SM7250 GPU SMMU" drivers/iommu
topic power      "power: supply: PM7250B charger, BQ27411 gauge" drivers/power
topic touch      "Input: Goodix GT9886 touchscreen" drivers/input
topic remoteproc "remoteproc: qcom: pas: SM7250 ADSP" drivers/remoteproc
topic qrtr-hack  "HACK: net: qrtr: ns: retry announcing local servers" net
topic audio      "ASoC: codecs: NXP/Goodix TFA9874 amplifier" sound
topic dts        "arm64: dts: qcom: SM7250 and OnePlus Nord (avicii)" arch
# every changed file must be in exactly one patch
a=$(git -C "$K" diff --name-only $BASE..$BR | sort); b=$(grep -h '^diff --git' "$OUT"/patches/*.patch | sed 's|^diff --git a/\(.*\) b/.*|\1|' | sort)
[ "$a" = "$b" ] || { echo "patch set does not cover the tree"; diff <(echo "$a") <(echo "$b") | head; exit 1; }
git -C "$K" log --no-merges --reverse --format='%h %s' $BASE..$BR > "$OUT/patches/COMMITS.txt"
cp "$M"/avicii*.config "$OUT/config/"
cp "$M/try.sh" "$L/psh.py" "$L/flash-recovery.sh" "$OUT/scripts/"
sed -e 's/out-audio/out/g' -e 's/avicii-audio\.img/avicii.img/' "$M/pack-audio.sh" > "$OUT/scripts/pack.sh"
cp "$L"/phone/*.sh "$OUT/phone/"
cp "$L"/tools/*.py "$L"/tools/*.c "$L"/tools/font8x16.h "$L"/tools/mkpublish.sh "$OUT/tools/"
cp "$L/initramfs/build.sh" "$L/initramfs/init" "$L/initramfs/flashpart" "$OUT/initramfs/"
echo "patches: $(ls "$OUT"/patches/*.patch | wc -l), $(cat "$OUT"/patches/*.patch | wc -l) lines"
