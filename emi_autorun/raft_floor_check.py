"""Offline check of the raft planner's floor test (emi_myst.lua ar_raft_floor) on the Mysts o' Tyme set (setx/mot.setb).

The water is cut into big triangles. A clearance measured inside ONE sector (GetFloorHeights(x, z, 0.8), the old test) leaves a dead
strip along every shared edge and cuts the water into islands: the planner found no way on most screens. The test now asks for floor at
the place and at 8 points round it (clearance from the edge of the water as a whole). Run: python raft_floor_check.py  (exit 1 on failure)
"""
import math, struct, sys
from collections import deque

def load(path):
    d = open(path, 'rb').read(); o = 0
    def u32():
        nonlocal o; v = struct.unpack_from('<I', d, o)[0]; o += 4; return v
    for _ in range(u32()):
        o += 128; fl = u32(); o += fl + 12 + 16 + 12
    nl = u32(); o += nl * (32 + 12 + 16 + 4 + 4 + 4 + 12 + 16)
    secs = []
    for _ in range(u32()):
        nv = u32(); vs = [struct.unpack_from('<3f', d, o + 12 * i) for i in range(nv)]; o += nv * 12
        n = u32(); nm = d[o:o + n].split(b'\0')[0].decode('latin1'); o += n
        o += 4; vis = d[o]; o += 1; typ = u32(); nsp = u32(); o += 4 * nsp + 4
        secs.append((nm, typ, vis, vs))
    return secs

def contains(vs, x, z, m):  # Sector::containsXZ of the port
    a = [vs[1][i] - vs[0][i] for i in range(3)]; b = [vs[-1][i] - vs[0][i] for i in range(3)]
    ny = a[2] * b[0] - a[0] * b[2]
    if abs(ny) < 1e-4:
        return False
    w = 1 if ny > 0 else -1
    vv = vs + [vs[0]]
    for i in range(len(vs)):
        ex = vv[i + 1][0] - vv[i][0]; ez = vv[i + 1][2] - vv[i][2]; L = math.hypot(ex, ez)
        if L > 0 and w * (ez * (x - vv[i][0]) - ex * (z - vv[i][2])) / L < m - 1e-5:
            return False
    return True

secs = load(sys.argv[1] if len(sys.argv) > 1 else 'setx/mot.setb')
walk = [s[3] for s in secs if s[1] & 0x1000 and s[2]]
def floor(x, z, m): return any(contains(v, x, z, m) for v in walk)
def old_test(x, z): return floor(x, z, 0.8)
def new_test(x, z, r=0.8):
    return floor(x, z, 0) and all(floor(x + r * math.cos(k * math.pi / 4), z + r * math.sin(k * math.pi / 4), 0) for k in range(8))

def path(test, s, t):  # the grid search of ar_raft_path (1-unit cells, 8 neighbours, the goal cell always allowed)
    prev = {s}; q = deque([s])
    while q:
        c = q.popleft()
        if c == t:
            return True
        for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1)):
            n = (c[0] + dx, c[1] + dz)
            if n not in prev and abs(n[0] - s[0]) < 90 and abs(n[1] - s[1]) < 90 and (n == t or test(*n)):
                prev.add(n); q.append(n)
    return False

# (start, goal) cells of drives from the runs: screen 4 bottom-left arrival to the up exit (the channel on the right, round the bank)
cases = [('screen 4 up', (293, 7), (293, 39))]
ok = True
for name, s, t in cases:
    o, n = path(old_test, s, t), path(new_test, s, t)
    print(f"{name}: old test {'way' if o else 'no way'}, new test {'way' if n else 'no way'}")
    ok = ok and n and not o
# screen 2's arrival (99.8, -6.2) is a channel about a unit wide between the left and right exit triggers, with a neck narrower than
# 0.6 at z -4.2: the last pass of ar_raft_walk (half-unit cells, no clearance, trigger margin 0.25) gets through, one-unit cells do not
trig = [(s[0], s[3]) for s in secs if s[1] & 0x8000 and s[2] and min(p[0] for p in s[3]) < 130 and max(p[0] for p in s[3]) > 70]
def near_trigger(x, z, m):  # the margin test of ar_raft_path: points round the cell, any exit trigger but the goal's
    k = -m
    while k <= m + 0.01:
        j = -m
        while j <= m + 0.01:
            if any(nm != 'up_trigger' and contains(v, x + k, z + j, 0) for nm, v in trig):
                return True
            j += m / 2
        k += m / 2
    return False
def grid_path(step, edge, margin, s, t):  # returns how near the goal the search gets (in cells), as ar_raft_path's fallback uses it
    sx, sz = round(s[0] / step), round(s[1] / step); tx, tz = round(t[0] / step), round(t[1] / step)
    seen = {(sx, sz)}; q = deque([(sx, sz)]); best = 1e9
    while q:
        c = q.popleft()
        best = min(best, (c[0] - tx) ** 2 + (c[1] - tz) ** 2)
        for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1)):
            n = (c[0] + dx, c[1] + dz)
            if n in seen or abs(n[0] - sx) >= 90 or abs(n[1] - sz) >= 90:
                continue
            far = (abs(n[0] - tx) > 2 or abs(n[1] - tz) > 2) and (abs(n[0] - sx) > 4 or abs(n[1] - sz) > 4)
            if n == (tx, tz) or (new_test(n[0] * step, n[1] * step, edge) and not (far and near_trigger(n[0] * step, n[1] * step, margin))):
                seen.add(n); q.append(n)
    return best <= 9
coarse = grid_path(1, 0.3, 0.5, (99.8, -6.2), (99.8, 38.75))
fine = grid_path(0.5, 0, 0.25, (99.8, -6.2), (99.8, 38.75))
print(f"screen 2 up: one-unit cells {'way' if coarse else 'no way'}, half-unit cells without clearance {'way' if fine else 'no way'}")
ok = ok and fine and not coarse
print('PASS' if ok else 'FAIL')
sys.exit(0 if ok else 1)
