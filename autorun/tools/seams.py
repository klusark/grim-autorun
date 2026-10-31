#!/usr/bin/env python
"""Seams between walk sectors, read from the set files in the game's archives.

usage: seams.py [set.set ...] [--gap MM] [--all]

For every pair of walk (and funnel) sectors of a set with an edge in common (two edges nearly on one line and overlapping along it) the gap between the two
lines along the overlap (min and max, in mm), whether the end vertices of the shared stretch are vertices of both sectors, and the height difference of the
planes at the ends. Without set names all the sets of the game. Only pairs with a gap over --gap mm (default 0.2) or a height step over 1 cm are listed unless
--all. The portals of a seam are the vertices one sector has that lie on the other's edge within the exact test's tolerance (0.02 mm).
"""
import glob, re, struct, sys, math

GRIM = 'C:/GOG Games/GRIMDATA'

def lab_members():
    out = {}
    for f in sorted(glob.glob(GRIM + '/*.LAB')):
        d = open(f, 'rb').read()
        if d[:4] != b'LABN':
            continue
        n, sl = struct.unpack('<II', d[8:16])
        so = 16 + n * 16
        for i in range(n):
            no, st, sz, _ = struct.unpack('<IIII', d[16 + i * 16:32 + i * 16])
            e = d.index(b'\0', so + no)
            name = d[so + no:e].decode()
            if name.lower().endswith('.set'):
                out[name.lower()] = (d, st, sz)
    return out

def parse(text):
    secs = []
    for s in re.split(r'\n\s*sector\s+', text)[1:]:
        name = s.split('\n')[0].strip()
        t = re.search(r'type\s+(\S+)', s)
        if 'vertices:' not in s or not t:
            continue
        v = re.findall(r'(-?\d+\.\d+)\s+(-?\d+\.\d+)\s+(-?\d+\.\d+)', s.split('vertices:')[1])
        secs.append((name, t.group(1), [(float(a), float(b), float(c)) for a, b, c in v]))
    return secs

def plane_z(pts, x, y):
    # z of the plane through the first three vertices at (x, y) (the set files give the height as z), None where vertical
    (x1, y1, z1), (x2, y2, z2), (x3, y3, z3) = pts[0], pts[1], pts[2]
    a = (y2 - y1) * (z3 - z1) - (z2 - z1) * (y3 - y1)
    b = (z2 - z1) * (x3 - x1) - (x2 - x1) * (z3 - z1)
    c = (x2 - x1) * (y3 - y1) - (y2 - y1) * (x3 - x1)
    if abs(c) < 1e-9:
        return z1
    return z1 - (a * (x - x1) + b * (y - y1)) / c

def seg_overlap(p, q, r, s):
    """The overlap of the segments pq and rs projected on pq: (t0, t1) along pq, the distances of r and s from the line pq."""
    dx, dy = q[0] - p[0], q[1] - p[1]
    L = math.hypot(dx, dy)
    if L < 1e-9:
        return None
    ux, uy = dx / L, dy / L
    def along(a): return (a[0] - p[0]) * ux + (a[1] - p[1]) * uy
    def off(a): return -(a[0] - p[0]) * uy + (a[1] - p[1]) * ux
    t0, t1 = sorted((along(r), along(s)))
    lo, hi = max(0.0, t0), min(L, t1)
    if hi - lo < 0.01:
        return None
    return lo, hi, off(r), off(s), L, ux, uy

def analyse(name, text, gapmm, show_all):
    secs = [s for s in parse(text) if s[1] in ('walk', 'funnel')]
    rows = []
    for i in range(len(secs)):
        for j in range(i + 1, len(secs)):
            A, B = secs[i], secs[j]
            pa, pb = A[2], B[2]
            for ia in range(len(pa)):
                p, q = pa[ia], pa[(ia + 1) % len(pa)]
                for ib in range(len(pb)):
                    r, s = pb[ib], pb[(ib + 1) % len(pb)]
                    o = seg_overlap(p, q, r, s)
                    if not o:
                        continue
                    lo, hi, d1, d2, L, ux, uy = o
                    # only edges that lie within 5 cm of each other all along the overlap and run about the same way
                    if max(abs(d1), abs(d2)) > 0.05:
                        continue
                    # (the offsets are at r and s, the ends of the other edge; along the overlap the gap is between them, interpolated)
                    gaps = [abs(d1), abs(d2)]
                    gap = (min(gaps) * 1000, max(gaps) * 1000)
                    # the height of the planes at the ends of the overlap
                    ends = [(p[0] + ux * t, p[1] + uy * t) for t in (lo, hi)]
                    dz = max(abs(plane_z(pa, x, y) - plane_z(pb, x, y)) for x, y in ends)
                    # portals: vertices of one on the other's edge within 0.02 mm
                    portals = []
                    for v in (p, q):
                        if abs(-(v[0] - r[0]) * (s[1] - r[1]) + (v[1] - r[1]) * (s[0] - r[0])) / max(math.hypot(s[0] - r[0], s[1] - r[1]), 1e-9) < 2e-5:
                            portals.append((round(v[0], 3), round(v[1], 3)))
                    for v in (r, s):
                        if abs(-(v[0] - p[0]) * (q[1] - p[1]) + (v[1] - p[1]) * (q[0] - p[0])) / max(math.hypot(q[0] - p[0], q[1] - p[1]), 1e-9) < 2e-5:
                            portals.append((round(v[0], 3), round(v[1], 3)))
                    if show_all or gap[1] > gapmm or dz > 0.01:
                        rows.append((gap[1], name, A[0], B[0], round(hi - lo, 2), gap, round(dz * 1000, 1), sorted(set(portals))))
    return rows

def main():
    args = sys.argv[1:]
    gapmm, show_all = 0.2, False
    names = []
    i = 0
    while i < len(args):
        if args[i] == '--gap':
            gapmm = float(args[i + 1]); i += 2
        elif args[i] == '--all':
            show_all = True; i += 1
        else:
            names.append(args[i].lower()); i += 1
    mem = lab_members()
    if not names:
        names = sorted(mem)
    rows = []
    for n in names:
        if n not in mem:
            continue
        d, st, sz = mem[n]
        rows += analyse(n, d[st:st + sz].decode('latin-1'), gapmm, show_all)
    rows.sort(key=lambda r: -r[0])
    print('set sectorA sectorB overlap_m gap_mm(min,max) dz_mm portals')
    for r in rows:
        print(r[1], r[2], r[3], r[4], '%.2f-%.2f' % r[5], r[6], r[7])
    print('%d seams' % len(rows))

main()
