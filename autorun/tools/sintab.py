#!/usr/bin/env python3
"""Reads the sine table of the original exe (the one FUN_0047bd20 interpolates in) and prints what it is.
   sintab.py [exe] [first VA] [count]"""
import struct, sys, math
exe = sys.argv[1] if len(sys.argv) > 1 else 'C:/GOG Games/GRIMDATA/GRIMFANDANGO.EXE'
d = open(exe, 'rb').read()
pe = struct.unpack_from('<I', d, 0x3c)[0]
nsec = struct.unpack_from('<H', d, pe + 6)[0]
optsz = struct.unpack_from('<H', d, pe + 20)[0]
base = struct.unpack_from('<I', d, pe + 24 + 28)[0]
secs = []
for i in range(nsec):
    o = pe + 24 + optsz + i * 40
    name = d[o:o + 8].rstrip(b'\0').decode()
    vsize, va, rsize, raw = struct.unpack_from('<IIII', d, o + 8)
    secs.append((name, va + base, vsize, raw, rsize))
def at(va, n):
    for name, sva, vs, raw, rs in secs:
        if sva <= va < sva + max(vs, rs):
            off = raw + (va - sva)
            return d[off:off + n]
    raise KeyError(hex(va))
first = int(sys.argv[2], 16) if len(sys.argv) > 2 else 0x4cf600
count = int(sys.argv[3]) if len(sys.argv) > 3 else 0x5000
vals = struct.unpack('<%df' % count, at(first, 4 * count))
open('C:/msys64/tmp/w/sintab.bin', 'wb').write(at(first, 4 * count))
for i in (0, 1, 2, 4095, 4096, 4097, 8191, 8192, 12288, 16383, 16384, 16385, 20479):
    if i < count:
        print(i, hex(first + 4 * i), vals[i])
# the formula: which step and phase give these numbers exactly in float?
best = None
for steps in (4096, 4095, 4097):
    for ph in (0.0, 0.5):
        err = max(abs(struct.unpack('<f', struct.pack('<f', math.sin((i + ph) * math.pi / 2 / steps)))[0] - vals[0x4000 + i]) for i in range(0, 4096, 7))
        print('steps', steps, 'phase', ph, 'max error', err)
