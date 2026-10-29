#!/usr/bin/env python3
"""Compares the paths of the planner on the two engines (tests/probe_planner.lua):
  plan_cmp.py <ScummVM log (WALKTO lines)> <grimtrace log of FUN_004917e0 (GRIMTRACE_BP=4917e0)>
The original gives the points of the path as the argument of FUN_004917e0 (the first four points are in the trace: the start, then the points to walk to);
ScummVM prints the points to walk to, the next one last."""
import re
import struct
import sys


def f(h):
    return struct.unpack("<f", struct.pack("<I", int(h, 16)))[0]


sv = []
for line in open(sys.argv[1], errors="ignore"):
    m = re.match(r"WALKTO Manny from (\S+) (\S+) (\S+) to (\S+) (\S+) (\S+) path \(next last\):(.*)", line)
    if m:
        pts = [tuple(float(x) for x in p.split()) for p in re.findall(r"\(([^)]*)\)", m.group(7))]
        sv.append((tuple(float(m.group(i)) for i in range(1, 7)), list(reversed(pts))))

orig = []
cur = None
for line in open(sys.argv[2], errors="ignore"):
    if line.startswith("BP "):
        cur = {}
        orig.append(cur)
        continue
    m = re.match(r"\s+\[esp\+012\] (\w+) \S+ -> (.*)", line)
    if m and cur is not None:
        cur["pts"] = [float(x) for x in m.group(2).split()[:12]]
    m = re.match(r"\s+\[esp\+016\] (\w+) ", line)
    if m and cur is not None:
        cur["n"] = int(m.group(1), 16)

bad = 0
for k, (hdr, pts) in enumerate(sv):
    if k >= len(orig):
        break
    o = orig[k]
    n = o.get("n", 0)
    # (the start first, then the points to walk to, in the order of the walk)
    op = [tuple(o["pts"][3 * i:3 * i + 3]) for i in range(min(n, 4))]
    ok = len(op) >= 1
    show = []
    for i, p in enumerate(op[1:]):
        if i < len(pts):
            d = max(abs(p[0] - pts[i][0]), abs(p[1] - pts[i][1]))
            if d > 1e-3:
                ok = False
            show.append("(%.5f %.5f | %.5f %.5f)" % (p[0], p[1], pts[i][0], pts[i][1]))
    if len(op) - 1 != min(len(pts), 3) and not (n > 4 and len(pts) >= 3):
        ok = False
    if not ok:
        bad += 1
        print("pair %d from %.2f %.2f to %.2f %.2f: original has %d points, ScummVM %d: %s" % (k + 1, hdr[0], hdr[1], hdr[3], hdr[4], n - 1, len(pts), " ".join(show)))
print("%d paths of ScummVM, %d calls of the original, %d paths differ" % (len(sv), len(orig), bad))
