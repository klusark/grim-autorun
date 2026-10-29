# Plans a walk through the walkable triangles of a set that keeps clear of round obstacles (the original honours the
# collision spheres of actors, ScummVM does not). usage: plan_route.py <log with SECTOR lines> x0 y0 x1 y1 rocks "x,y;x,y;..." 
import re, heapq, math, sys
log, x0, y0, x1, y1, rk = sys.argv[1], *map(float, sys.argv[2:6]), sys.argv[6]
spacing = float(sys.argv[7]) if len(sys.argv) > 7 else 0.5
tris = []
for l in open(log, errors='replace'):
    m = re.search(r'SECTOR \d+ (\S+) type=(\d+) visible=\d+:(.*)!', l)
    if not m or int(m.group(2)) != 4096:
        continue
    pts = [tuple(map(float, p.split(','))) for p in re.findall(r'\(([^)]*)\)', m.group(3))]
    if len(pts) == 3:
        tris.append(pts)
rocks = [tuple(map(float, r.split(','))) for r in rk.split(';')]
def tri_z(p):
    x, y = p
    for a, b, c in tris:
        den = (b[1]-c[1])*(a[0]-c[0])+(c[0]-b[0])*(a[1]-c[1])
        if abs(den) < 1e-9: continue
        l1 = ((b[1]-c[1])*(x-c[0])+(c[0]-b[0])*(y-c[1]))/den
        l2 = ((c[1]-a[1])*(x-c[0])+(a[0]-c[0])*(y-c[1]))/den
        l3 = 1-l1-l2
        if l1 >= -1e-6 and l2 >= -1e-6 and l3 >= -1e-6:
            return l1*a[2]+l2*b[2]+l3*c[2]
    return 0.0

def inside(p):
    x, y = p
    for a, b, c in tris:
        a, b, c = a[:2], b[:2], c[:2]
        d1 = (x-b[0])*(a[1]-b[1])-(a[0]-b[0])*(y-b[1])
        d2 = (x-c[0])*(b[1]-c[1])-(b[0]-c[0])*(y-c[1])
        d3 = (x-a[0])*(c[1]-a[1])-(c[0]-a[0])*(y-a[1])
        if not (((d1 < 0) or (d2 < 0) or (d3 < 0)) and ((d1 > 0) or (d2 > 0) or (d3 > 0))):
            return True
    return False
step = 0.025
def free(p, clear):
    return inside(p) and all(math.hypot(p[0]-r[0], p[1]-r[1]) >= clear for r in rocks)
def find(clear):
    key = lambda p: (round(p[0]/step), round(p[1]/step))
    sk, gk = key((x0, y0)), key((x1, y1))
    dist = {sk: 0}; prev = {}; pq = [(0, sk)]
    while pq:
        d, k = heapq.heappop(pq)
        if k == gk:
            path = []
            while k != sk:
                path.append((k[0]*step, k[1]*step)); k = prev[k]
            path.append((sk[0]*step, sk[1]*step)); path.reverse(); return path
        if d > dist[k]: continue
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                if not dx and not dy: continue
                n = (k[0]+dx, k[1]+dy); p = (n[0]*step, n[1]*step)
                if n != gk and not free(p, clear): continue
                nd = d + math.hypot(dx, dy)
                if nd < dist.get(n, 1e9):
                    dist[n] = nd; prev[n] = k; heapq.heappush(pq, (nd, n))
    return None
MIN_CLEAR = 0.30   # a path needs at least this much room
WANT = 0.55        # and is pulled toward the middle of the free space up to this
def cost_at(p):
    d = min(math.hypot(p[0]-r[0], p[1]-r[1]) for r in rocks)
    return 1.0 + 40.0 * max(0.0, WANT - d) ** 2
def find():
    key = lambda p: (round(p[0]/step), round(p[1]/step))
    sk, gk = key((x0, y0)), key((x1, y1))
    dist = {sk: 0}; prev = {}; pq = [(0, sk)]
    while pq:
        d, k = heapq.heappop(pq)
        if k == gk:
            path = []
            while k != sk:
                path.append((k[0]*step, k[1]*step)); k = prev[k]
            path.append((sk[0]*step, sk[1]*step)); path.reverse(); return path
        if d > dist[k]: continue
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                if not dx and not dy: continue
                n = (k[0]+dx, k[1]+dy); p = (n[0]*step, n[1]*step)
                if n != gk and not free(p, MIN_CLEAR): continue
                nd = d + math.hypot(dx, dy) * cost_at(p)
                if nd < dist.get(n, 1e9):
                    dist[n] = nd; prev[n] = k; heapq.heappush(pq, (nd, n))
    return None
path = find()
if not path:
    print('no path'); sys.exit(1)
def clearance(a, b):
    n = int(math.hypot(b[0]-a[0], b[1]-a[1])/0.02) + 1
    return min(min(math.hypot(a[0]+(b[0]-a[0])*i/n-r[0], a[1]+(b[1]-a[1])*i/n-r[1]) for r in rocks) for i in range(n+1))
def walkable(a, b):
    n = int(math.hypot(b[0]-a[0], b[1]-a[1])/0.02) + 1
    return all(inside((a[0]+(b[0]-a[0])*i/n, a[1]+(b[1]-a[1])*i/n)) for i in range(n+1))
need = float(sys.argv[8]) if len(sys.argv) > 8 else 0.36
out = [path[0]]; i = 0
while i < len(path)-1:
    j = len(path)-1
    while j > i+1 and not (walkable(path[i], path[j]) and clearance(path[i], path[j]) >= need):
        j -= 1
    out.append(path[j]); i = j
print('clearance of the planned path: %.2f' % min(clearance(a, b) for a, b in zip(out, out[1:])))
for x, y in out[1:]:
    print('	{ %.2f, %.2f, %.2f },' % (x, y, tri_z((x, y))))
