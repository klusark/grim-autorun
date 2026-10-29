"""Fixed frame time for the original GRIMFANDANGO.EXE (v1.01, already patched by patch_debuglog.py / patch_framelimit.py / v101_autorun).

usage: patch_simtime.py <exe in> <exe out> [ms per frame, default 17]

The per frame function FUN_004016a0 reads the one-shot global DAT_004f5a48 ("fixed frame time") at 0x401721 and passes it to FUN_00482990, which
runs the fixed step FUN_004a3c80(ms) when it is not zero and the wall clock FUN_004a3c10 when it is. The load at 0x401721 (mov eax,[0x4f5a48],
5 bytes) becomes mov eax,<ms>: every frame is a frame of <ms> milliseconds whatever the machine does, as ScummVM's --sim-fps does.
"""
import struct, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from patch_debuglog import PE

src, dst = sys.argv[1], sys.argv[2]
ms = int(sys.argv[3]) if len(sys.argv) > 3 else 17
pe = PE(open(src, "rb").read())
o = pe.off(0x00401721)
assert bytes(pe.d[o:o + 5]) == b"\xa1\x48\x5a\x4f\x00", "not the exe this patch is for: %r" % bytes(pe.d[o:o + 5])
pe.d[o:o + 5] = b"\xb8" + struct.pack("<I", ms)
open(dst, "wb").write(pe.d)
print("patched %s -> %s, %d ms a frame" % (src, dst, ms))
