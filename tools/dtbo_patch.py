#!/usr/bin/env python3
# Add u32 root properties to one overlay of an Android dtbo image and rebuild the table.
# The OOS 10 bootloader matches overlays on oem,project-id / oem,hw-id, while Lineage-era
# overlays only carry oplus,dtsi_no / oplus,pcb_range.
# usage: dtbo_patch.py [--only] in.img out.img ENTRY name=hex[,hex...] [name=...]
#   --only  drop every other overlay so the bootloader has a single candidate
import struct, sys

FDT_BEGIN_NODE, FDT_PROP = 1, 3


def add_root_props(fdt, props):
    (magic, total, off_struct, off_str, off_rsv, ver, lastcomp, cpu, sz_str, sz_struct) = struct.unpack(">10I", fdt[:40])
    assert magic == 0xD00DFEED
    assert off_str >= off_struct + sz_struct, "strings block expected after struct block"
    # root node: BEGIN_NODE token + empty name padded to 4 bytes
    assert struct.unpack(">I", fdt[off_struct:off_struct + 4])[0] == FDT_BEGIN_NODE
    ins_at = off_struct + 8
    strings = bytearray(fdt[off_str:off_str + sz_str])
    blob = b""
    for name, vals in props:
        nameoff = len(strings)
        strings += name.encode() + b"\0"
        val = b"".join(struct.pack(">I", v) for v in vals)
        blob += struct.pack(">III", FDT_PROP, len(val), nameoff) + val
    new = bytearray(fdt[:ins_at]) + blob + fdt[ins_at:off_str] + strings
    new_off_str = off_str + len(blob)
    struct.pack_into(">10I", new, 0, magic, len(new), off_struct, new_off_str, off_rsv, ver, lastcomp, cpu,
                     len(strings), sz_struct + len(blob))
    return bytes(new)


def main():
    args = sys.argv[1:]
    only = args[0] == "--only"
    if only:
        args = args[1:]
    src, dst, entry = args[0], args[1], int(args[2])
    props = []
    for a in args[3:]:
        k, v = a.split("=")
        props.append((k, [int(x, 16) for x in v.split(",")]))
    d = open(src, "rb").read()
    magic, total, hsz, esz, cnt, eoff, page, ver = struct.unpack(">8I", d[:32])
    assert magic == 0xD7B7AB1E and esz == 32
    ents = []
    for i in range(cnt):
        size, off, *rest = struct.unpack(">8I", d[eoff + i * esz: eoff + (i + 1) * esz])
        fdt = d[off:off + size]
        if i == entry:
            fdt = add_root_props(fdt, props)
        if i == entry or not only:
            ents.append((fdt, rest))
    cnt = len(ents)
    out = bytearray(hsz + cnt * esz)
    pos = len(out)
    for i, (fdt, rest) in enumerate(ents):
        struct.pack_into(">8I", out, hsz + i * esz, len(fdt), pos, *rest)
        out += fdt
        pos += len(fdt)
    struct.pack_into(">8I", out, 0, magic, len(out), hsz, esz, cnt, hsz, page, ver)
    open(dst, "wb").write(out)
    print("wrote %s: %d entries, %d bytes" % (dst, cnt, len(out)))


if __name__ == "__main__":
    main()
