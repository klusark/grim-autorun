#!/usr/bin/env python3
"""Compares the walker state at every call of Walker_WalkSectors:
  walk_cmp.py <ScummVM log (WALKSEC lines, DEBUGFLAGS=actors)> <grimtrace log (GRIMTRACE_BP=4a8610 GRIMTRACE_PEEK="ecx+0,ecx+c,ecx+18,ecx+24")> [limit]
Only the calls of depth 0 are compared (the original logs the recursive calls too: they are skipped by the distance argument being the rest of a step).
Prints the first call in which the position or the forward vector differ by more than the limit (default 1e-6) and the largest difference seen."""
import re
import struct
import sys


def f(h):
    return struct.unpack("<f", struct.pack("<I", int(h, 16)))[0]


lim = float(sys.argv[3]) if len(sys.argv) > 3 else 1e-6
sv = []
for line in open(sys.argv[1], errors="ignore"):
    m = re.match(r"WALKSEC (\S+) depth (\d+) dist (\S+) pos (\S+) (\S+) (\S+) fwd (\S+) (\S+) (\S+)", line)
    if m:
        sv.append((int(m.group(2)), [float(m.group(i)) for i in range(4, 10)], float(m.group(3))))
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
    m = re.match(r"\s+\[esp\+004\] (\w+) ", line)
    if m and cur is not None and "d" not in cur:
        cur["d"] = f(m.group(1))
n = min(len(sv), len(orig))
worst = 0.0
for k in range(n):
    o = orig[k]
    d, vals, dist = sv[k]
    if "ecx+0" not in o["p"]:
        continue
    pos = o["p"]["ecx+0"]
    fwd = o["p"]["ecx+18"]
    diff = max(abs(pos[0] - vals[0]), abs(pos[1] - vals[1]), abs(pos[2] - vals[2]), abs(fwd[0] - vals[3]), abs(fwd[1] - vals[4]), abs(fwd[2] - vals[5]))
    worst = max(worst, diff)
    if diff > lim:
        print("call %d (depth %d): position %s / %s, forward %s / %s, difference %.3g" % (k + 1, d, [round(x, 7) for x in pos], [round(x, 7) for x in vals[:3]],
                                                                                   [round(x, 7) for x in fwd], [round(x, 7) for x in vals[3:]], diff))
        break
print("%d calls compared (%d / %d), largest difference %.3g" % (n, len(sv), len(orig), worst))
