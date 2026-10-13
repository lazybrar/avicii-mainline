#!/usr/bin/env python3
# List the entries of an Android dtbo image with the properties the bootloader matches on.
import re, struct, sys

KEYS = re.compile(r"^(model|qcom,(board-id|msm-id|pmic-id)|oplus,.*|oem,.*|oneplus,.*)$")


def root_props(fdt):
    """properties of / and of /fragment@N/__overlay__ when it targets the root"""
    magic, total, off_struct, off_str = struct.unpack(">IIII", fdt[:16])
    p, depth, path, out = off_struct, 0, [], []
    while True:
        tok = struct.unpack(">I", fdt[p:p + 4])[0]; p += 4
        if tok == 1:
            e = fdt.index(b"\0", p); path.append(fdt[p:e].decode()); p = (e + 4) & ~3; depth += 1
        elif tok == 2:
            path.pop(); depth -= 1
        elif tok == 3:
            ln, no = struct.unpack(">II", fdt[p:p + 8]); p += 8
            val = fdt[p:p + ln]; p = (p + ln + 3) & ~3
            e = fdt.index(b"\0", off_str + no); name = fdt[off_str + no:e].decode()
            if depth == 1 or (depth == 3 and path[-1] == "__overlay__"):
                if KEYS.match(name):
                    if val.endswith(b"\0") and all(32 <= c < 127 or c == 0 for c in val):
                        v = val[:-1].decode().replace("\0", ",")
                    else:
                        v = " ".join("%x" % x for x in struct.unpack(">%dI" % (ln // 4), val[:ln // 4 * 4]))
                    out.append("%s=%s" % (name, v))
        elif tok == 9:
            return out


d = open(sys.argv[1], "rb").read()
magic, total, hsz, esz, cnt, eoff = struct.unpack(">IIIIII", d[:24])
assert magic == 0xD7B7AB1E, hex(magic)
for i in range(cnt):
    size, off = struct.unpack(">II", d[eoff + i * esz: eoff + i * esz + 8])
    print("%2d %7d  %s" % (i, size, "  ".join(root_props(d[off:off + size]))))
