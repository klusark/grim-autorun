"""Makes ar_nav_data.lua (AR_NAV, see ar_nav.lua) from the sector lists that ScummVM writes to its log.

usage: ar_nav_data.py <log> [<log> ...] > ar_nav_data.lua
A list starts at "AUTORUN SECTORS OF <set>", followed by "SECTOR <id> <name> type=<n> visible=<n>: (x,y,z) ..." lines.
"""
import re
import sys

EPS = 0.002
ZTOL = 0.25  # sectors further apart than this in height are not neighbours
TOL = 0.03  # edges that are this close (and parallel enough) count as shared
WALK = (4096, 4352)
HOT = 32768
sets = {}
hots = {}
offs = {}
order = []
cur = None
for path in sys.argv[1:]:
    for line in open(path, errors="replace"):
        m = re.search(r"AUTORUN SECTORS OF (.*?)\s*$", line)
        if m:
            cur = m.group(1)
            if cur not in sets:
                sets[cur] = {}
                order.append(cur)
            continue
        m = re.search(r"SECTOR \d+ (\S+) type=(\d+) visible=(\d+): (.*?)!?\s*$", line)
        if m and cur:
            pts = [tuple(float(v) for v in p.split(",")) for p in re.findall(r"\(([^)]*)\)", m.group(4))]
            if int(m.group(2)) in WALK and len(pts) >= 3:
                if m.group(1) not in sets[cur]:
                    sets[cur][m.group(1)] = (int(m.group(2)), pts)
                    if m.group(3) == "0":
                        offs.setdefault(cur, []).append(m.group(1))
            elif int(m.group(2)) == HOT and len(pts) >= 3:
                if m.group(1) not in hots.setdefault(cur, {}):
                    hots[cur][m.group(1)] = pts
                    if m.group(3) == "0":
                        offs.setdefault(cur, []).append(m.group(1))


def overlap(a1, a2, b1, b2):
    """The part of segment a that lies on segment b (both 2D collinear within EPS), or None."""
    dx, dy = a2[0] - a1[0], a2[1] - a1[1]
    ln = (dx * dx + dy * dy) ** 0.5
    if ln < EPS:
        return None
    for q in (b1, b2):
        if abs((q[0] - a1[0]) * dy - (q[1] - a1[1]) * dx) / ln > TOL:
            return None
    t = lambda q: ((q[0] - a1[0]) * dx + (q[1] - a1[1]) * dy) / (ln * ln)
    lo, hi = max(0.0, min(t(b1), t(b2))), min(1.0, max(t(b1), t(b2)))
    if (hi - lo) * ln < EPS:
        return None
    lerp = lambda s: tuple(a1[i] + s * (a2[i] - a1[i]) for i in range(3))
    return lerp(lo), lerp(hi)


def inside2(poly, x, y):
    ins = False
    j = len(poly) - 1
    for k in range(len(poly)):
        xk, yk, xj, yj = poly[k][0], poly[k][1], poly[j][0], poly[j][1]
        if (yk > y) != (yj > y) and x < (xj - xk) * (y - yk) / (yj - yk) + xk:
            ins = not ins
        j = k
    return ins


def plane_z(poly, x, y):
    (ax, ay, az), (bx, by, bz), (cx, cy, cz) = poly[0], poly[1], poly[2]
    den = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
    if abs(den) < 1e-6:
        return az
    l1 = ((by - cy) * (x - cx) + (cx - bx) * (y - cy)) / den
    l2 = ((cy - ay) * (x - cx) + (ax - cx) * (y - cy)) / den
    return l1 * az + l2 * bz + (1 - l1 - l2) * cz


def seg_cross(p1, p2, p3, p4):
    d = (p2[0] - p1[0]) * (p4[1] - p3[1]) - (p2[1] - p1[1]) * (p4[0] - p3[0])
    if abs(d) < 1e-9:
        return None
    t = ((p3[0] - p1[0]) * (p4[1] - p3[1]) - (p3[1] - p1[1]) * (p4[0] - p3[0])) / d
    u = ((p3[0] - p1[0]) * (p2[1] - p1[1]) - (p3[1] - p1[1]) * (p2[0] - p1[0])) / d
    if 0 <= t <= 1 and 0 <= u <= 1:
        return (p1[0] + t * (p2[0] - p1[0]), p1[1] + t * (p2[1] - p1[1]))
    return None


def overlap_point(pa, pb):
    """A point where the polygons overlap in 2D (the centre of the points of the overlap), or None."""
    pts = [(v[0], v[1]) for v in pa if inside2(pb, v[0], v[1])] + [(v[0], v[1]) for v in pb if inside2(pa, v[0], v[1])]
    for k in range(len(pa)):
        for l in range(len(pb)):
            c = seg_cross(pa[k], pa[(k + 1) % len(pa)], pb[l], pb[(l + 1) % len(pb)])
            if c:
                pts.append(c)
    if not pts:
        return None
    return (sum(p[0] for p in pts) / len(pts), sum(p[1] for p in pts) / len(pts))


def fmt(v):
    return ("%.3f" % v).rstrip("0").rstrip(".") if v else "0"


print("-- made by ar_nav_data.py from the sector lists of a ScummVM run; do not edit")
print("AR_NAV = { }")
for name in order:
    secs = list(sets[name].items())
    if not secs:
        continue
    print("AR_NAV[%s] = {" % ('"' + name.replace('"', '') + '"'))
    print("\tn = { %s }," % ", ".join('"%s"' % s[0] for s in secs))
    print("\tt = { %s }," % ", ".join(str(s[1][0]) for s in secs))
    print("\tp = {")
    for _, (_, pts) in secs:
        print("\t\t{ %s }," % ", ".join(fmt(c) for p in pts for c in p))
    print("\t},")
    hs = list(hots.get(name, {}).items())
    print("\thn = { %s }," % ", ".join('"%s"' % h[0] for h in hs))
    print("\thp = {")
    for _, pts in hs:
        print("\t\t{ %s }," % ", ".join(fmt(c) for p in pts for c in p))
    print("\t},")
    print("\tadj = {")
    for i, (_, (_, pa)) in enumerate(secs):
        row = []
        for j, (_, (_, pb)) in enumerate(secs):
            if i == j:
                continue
            best = None
            for k in range(len(pa)):
                for l in range(len(pb)):
                    o = overlap(pa[k], pa[(k + 1) % len(pa)], pb[l], pb[(l + 1) % len(pb)])
                    # (sectors at different heights are not joined: Manny cannot walk from one to the other)
                    if o and all(abs(plane_z(pb, q[0], q[1]) - q[2]) < ZTOL for q in o):
                        best = o
            if not best:
                c = overlap_point(pa, pb)
                if c:
                    za, zb = plane_z(pa, *c), plane_z(pb, *c)
                    if abs(za - zb) < ZTOL:
                        best = ((c[0], c[1], (za + zb) / 2), (c[0], c[1], (za + zb) / 2))
            if best:
                row.append("{ %d, %s }" % (j + 1, ", ".join(fmt(c) for p in best for c in p)))
        print("\t\t{ %s }," % ", ".join(row))
    print("\t},")
    print("}")
