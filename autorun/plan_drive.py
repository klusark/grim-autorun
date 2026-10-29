# Plans a route for a vehicle along some of a set's walk sectors, staying away from their edges.
# usage: plan_drive.py <log with SECTOR lines> <name regex> x0 y0 x1 y1 [margin] [spacing]
import re, heapq, math, sys
log, pat = sys.argv[1], re.compile(sys.argv[2])
x0, y0, x1, y1 = map(float, sys.argv[3:7])
margin = float(sys.argv[7]) if len(sys.argv) > 7 else 0.5
spacing = float(sys.argv[8]) if len(sys.argv) > 8 else 2.0
polys = []
for l in open(log, errors='replace'):
    m = re.search(r'SECTOR \d+ (\S+) type=(\d+) visible=\d+:(.*)!', l)
    if m and int(m.group(2)) == 4096 and pat.search(m.group(1)):
        polys.append([tuple(map(float, p.split(','))) for p in re.findall(r'\(([^)]*)\)', m.group(3))])
def in_poly(p, poly):
    x, y = p; c = False
    for i in range(len(poly)):
        a, b = poly[i], poly[i-1]
        if (a[1] > y) != (b[1] > y) and x < (b[0]-a[0])*(y-a[1])/(b[1]-a[1])+a[0]:
            c = not c
    return c
def inside(p):
    return any(in_poly(p, q) for q in polys)
def ok(p):
    if not inside(p): return False
    for k in range(8):
        a = k*math.pi/4
        if not inside((p[0]+margin*math.cos(a), p[1]+margin*math.sin(a))): return False
    return True
def z_at(p):
    # height from the plane of the (planar) sector that holds the point
    for poly in polys:
        if in_poly(p, poly):
            a, b, c = poly[0], poly[1], poly[2]
            den = (b[1]-c[1])*(a[0]-c[0])+(c[0]-b[0])*(a[1]-c[1])
            if abs(den) < 1e-9:
                continue
            l1 = ((b[1]-c[1])*(p[0]-c[0])+(c[0]-b[0])*(p[1]-c[1]))/den
            l2 = ((c[1]-a[1])*(p[0]-c[0])+(a[0]-c[0])*(p[1]-c[1]))/den
            return l1*a[2]+l2*b[2]+(1-l1-l2)*c[2]
    return 0.0
step = 0.1
key = lambda p: (round(p[0]/step), round(p[1]/step))
sk, gk = key((x0, y0)), key((x1, y1))
dist = {sk: 0}; prev = {}; pq = [(0, sk)]
found = False
while pq:
    d, k = heapq.heappop(pq)
    if k == gk: found = True; break
    if d > dist[k]: continue
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            if not dx and not dy: continue
            n = (k[0]+dx, k[1]+dy); p = (n[0]*step, n[1]*step)
            if n != gk and not ok(p): continue
            nd = d + math.hypot(dx, dy)
            if nd < dist.get(n, 1e9):
                dist[n] = nd; prev[n] = k; heapq.heappush(pq, (nd, n))
if not found:
    print('no path (try a smaller margin)'); sys.exit(1)
path = []; k = gk
while k != sk:
    path.append((k[0]*step, k[1]*step)); k = prev[k]
path.append((sk[0]*step, sk[1]*step)); path.reverse()
out = [path[0]]; acc = 0
for a, b in zip(path, path[1:]):
    acc += math.hypot(b[0]-a[0], b[1]-a[1])
    if acc >= spacing:
        out.append(b); acc = 0
out.append(path[-1])
for x, y in out[1:]:
    print('	{ %.2f, %.2f, %.2f },' % (x, y, z_at((x, y))))
