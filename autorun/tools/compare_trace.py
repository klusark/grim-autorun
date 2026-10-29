#!/usr/bin/env python3
"""Compares the NAVTRACE lines (case, frame, x y z yaw) of two logs: for every case the first frame in which the positions differ by more
than the limit (default 1 cm), and the positions there.   compare_trace.py a.log b.log [limit_m] [case-prefix]"""
import re, sys

def read(path):
    r = {}
    for line in open(path, errors='replace'):
        m = re.search(r'NAVTRACE (\S+) (\d+) (-?[\d.]+) (-?[\d.]+) (-?[\d.]+) (-?[\d.]+)', line)
        if m and 'AUTORUN' not in line:
            r.setdefault(m.group(1), {})[int(m.group(2))] = tuple(float(m.group(i)) for i in range(3, 7))
    return r

a = read(sys.argv[1]); b = read(sys.argv[2])
lim = float(sys.argv[3]) if len(sys.argv) > 3 else 0.01
pre = sys.argv[4] if len(sys.argv) > 4 else ''
same = diff = 0
import os

def mirror(tr):
    # the approach: from the first position to the one 8 frames on (a head-on slide goes to either side of this line, which one is not a property of the engine)
    p0 = tr[1]
    p1 = tr[min(8, max(tr))]
    ux, uy = p1[0] - p0[0], p1[1] - p0[1]
    n = (ux * ux + uy * uy) ** 0.5
    if n == 0:
        return tr
    ux, uy = ux / n, uy / n
    out = {}
    for f, p in tr.items():
        rx, ry = p[0] - p0[0], p[1] - p0[1]
        al = rx * ux + ry * uy
        out[f] = (p0[0] + 2 * al * ux - rx, p0[1] + 2 * al * uy - ry, p[2], p[3])
    return out
for case in sorted(set(a) & set(b)):
    if not case.startswith(pre):
        continue
    def firstdiff(ta, tb):
        for f in sorted(set(ta) & set(tb)):
            pa, pb = ta[f], tb[f]
            if ((pa[0]-pb[0])**2 + (pa[1]-pb[1])**2) ** 0.5 > lim:
                return f
        return None
    first = firstdiff(a[case], b[case])
    if first is not None and os.environ.get('SYM'):
        # (the other side of the approach is as good: see the note in test_nav.lua)
        m = firstdiff(a[case], mirror(b[case]))
        if m is None or m > first:
            first = m
    if first is None:
        same += 1
    else:
        diff += 1
        pa, pb = a[case][first], b[case][first]
        print('%s: frame %d  A %.4f %.4f  B %.4f %.4f  (A frame0 %s)' % (case, first, pa[0], pa[1], pb[0], pb[1], a[case].get(1)))
print('%d traces the same, %d diverge' % (same, diff))
