#!/usr/bin/env python3
"""Bit-exact version of walk_cmp.py: the position and the forward vector at every call of Walker_WalkSectors, both as floats (ScummVM's %.9g lines read back
as floats). Prints the first calls that differ and the number of exact ones.
  walk_exact.py <ScummVM log (WALKSEC lines)> <grimtrace log (GRIMTRACE_BP=4a8610 GRIMTRACE_PEEK="ecx+0,ecx+c,ecx+18,ecx+24")> [number of differences to print]"""
import re
import struct
import sys


def f(h):
    return struct.unpack("<f", struct.pack("<I", int(h, 16)))[0]


def f32(x):
    return struct.unpack("<f", struct.pack("<f", x))[0]


show = int(sys.argv[3]) if len(sys.argv) > 3 else 5
sv = []
for line in open(sys.argv[1], errors="ignore"):
    m = re.match(r"WALKSEC (\S+) depth (\d+) dist (\S+) pos (\S+) (\S+) (\S+) fwd (\S+) (\S+) (\S+)", line)
    if m:
        sv.append((int(m.group(2)), [f32(float(m.group(i))) for i in range(4, 10)]))
orig = []
cur = None
for line in open(sys.argv[2], errors="ignore"):
    if line.startswith("BP "):
        cur = {"p": {}}
        orig.append(cur)
        continue
    m = re.match(r"\s+peek (\S+): (\w+) (\w+) (\w+) (\w+) /", line)
    if m and cur is not None:
        cur["p"][m.group(1)] = [f(m.group(i)) for i in (2, 3, 4)]
n = min(len(sv), len(orig))
same = 0
bad = 0
for k in range(n):
    o = orig[k]
    if "ecx+0" not in o["p"]:
        continue
    vals = sv[k][1]
    ov = o["p"]["ecx+0"] + o["p"]["ecx+18"]
    if all(a == b or (a == 0 and b == 0) for a, b in zip(ov, vals)):
        same += 1
    else:
        bad += 1
        if bad <= show:
            print("call %d (depth %d): original %s ScummVM %s" % (k + 1, sv[k][0], ["%.9g" % x for x in ov], ["%.9g" % x for x in vals]))
print("%d calls compared (%d / %d), %d exact, %d differ" % (n, len(sv), len(orig), same, bad))
