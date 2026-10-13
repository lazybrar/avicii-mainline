#!/usr/bin/env python3
# Read chosen RAM ranges from the phone while it sits in Qualcomm Crashdump Mode (USB 05c6:900e),
# using bkerler edl's Sahara memory-debug support. Used to fetch the ramoops region after a
# mainline kernel crash, since a hard reset out of Crashdump Mode clears RAM.
# usage (from the edl venv): crashread.py OUTDIR ADDR:LEN[:name] [ADDR:LEN[:name] ...]
#   e.g. crashread.py out 0xcbe00000:0x400000:ramoops
# The phone is left in Crashdump Mode afterwards (no reset is sent).
import os, runpy, sys

EDL = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "tools", "edl-src")
outdir = os.path.abspath(sys.argv[1])
wants = []
for a in sys.argv[2:]:
    f = a.split(":")
    wants.append((int(f[0], 0), int(f[1], 0), f[2] if len(f) > 2 else "mem_%s" % f[0]))

os.makedirs(outdir, exist_ok=True)
os.chdir(outdir)  # edl creates ./memory and log files in the cwd
sys.path.insert(0, EDL)
from edlclient.Library import sahara as sahara_mod


def dump_partitions(self, partitions):
    # replaces the stock "dump every DDR section" (12 GB) with just the requested ranges
    with open("memtable.txt", "w") as t:
        for p in partitions:
            t.write("%s (%s): base %#x len %#x\n" % (p["filename"], p["desc"], p["mem_base"], p["length"]))
    for addr, length, name in wants:
        with open(name + ".bin", "wb") as wf:
            self.read_memory(addr, length, True, wf)
            print("\n%s: read %#x of %#x bytes from %#x" % (name, wf.tell(), length, addr))
    return True


sahara_mod.sahara.dump_partitions = dump_partitions
sys.argv = ["edl", "memorydump"]
runpy.run_path(os.path.join(EDL, "edl.py"), run_name="__main__")
