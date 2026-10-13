#!/usr/bin/env python3
# Build an ath10k board-2.bin for WCN3990 from the phone's own bdwlan.* calibration files
# (modem partition, image/): one "bus=snoc,qmi-board-id=<id>" entry per file, bdwlan.bin = id ff.
# usage: python3 -I mkboard2.py OUT_board-2.bin DIR_WITH_bdwlan_files
import os, re, struct, sys


def pad4(b):
    return b + b"\0" * (-len(b) % 4)


def ie(i, d):
    return struct.pack("<II", i, len(d)) + pad4(d)


out, src = sys.argv[1], sys.argv[2]
blob = pad4(b"QCA-ATH10K-BOARD\0")
n = 0
for fn in sorted(os.listdir(src)):
    if fn == "bdwlan.bin":
        bid = 0xFF
    else:
        m = re.fullmatch(r"bdwlan\.b([0-9a-fA-F]{2})", fn)
        if not m:
            continue
        bid = int(m.group(1), 16)
    data = open(os.path.join(src, fn), "rb").read()
    name = ("bus=snoc,qmi-board-id=%x" % bid).encode()
    blob += ie(0, ie(0, name) + ie(1, data))  # BOARD { NAME, DATA }
    n += 1
open(out, "wb").write(blob)
print("%s: %d boards, %d bytes" % (out, n, len(blob)))
