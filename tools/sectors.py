# Plots the SECTOR lines of a log (DumpSectors in the autorun) as an ASCII map of x/y, walk sectors
# as their id character, other types in lower case marks. usage: sectors.py log [step] [MANNYx MANNYy]
import re, sys
log = open(sys.argv[1], errors='replace').read().split('\n')
step = float(sys.argv[2]) if len(sys.argv) > 2 else 0.25
secs = []
for l in log:
    m = re.search(r'SECTOR (\d+) (\S+) type=(\d+) visible=(\d):(.*)', l)
    if m:
        pts = [tuple(float(v) for v in p.split(',')) for p in re.findall(r'\(([^)]*)\)', m.group(5))]
        secs.append((int(m.group(1)), m.group(2), int(m.group(3)), int(m.group(4)), pts))
# only the last dump: sectors restart with id order, keep from the last 'first id' repeat
last = []
seen = set()
for s in secs:
    if s[0] in seen and s[0] == secs[0][0]:
        last = []
        seen = set()
    seen.add(s[0]); last.append(s)
secs = last
for s in secs:
    print(s[0], s[1], 'type', s[2], 'vis', s[3], ' '.join('(%.2f,%.2f,%.2f)' % p for p in s[4]))
def inside(x, y, pts):
    n = len(pts); c = False
    j = n - 1
    for i in range(n):
        xi, yi = pts[i][0], pts[i][1]; xj, yj = pts[j][0], pts[j][1]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi:
            c = not c
        j = i
    return c
walk = [s for s in secs if s[2] & 0x2000 or s[2] == 4096 or True]
xs = [p[0] for s in secs for p in s[4]]; ys = [p[1] for s in secs for p in s[4]]
if not xs: sys.exit()
chars = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
y = max(ys)
print('x from %.2f to %.2f step %.2f' % (min(xs), max(xs), step))
while y >= min(ys) - 1e-6:
    row = ''
    x = min(xs)
    while x <= max(xs) + 1e-6:
        c = '.'
        for s in secs:
            if s[3] and inside(x, y, s[4]):
                c = chars[s[0] % 62] if s[2] in (0x1000, 4096) or True else '+'
                break
        row += c
        x += step
    print('%7.2f %s' % (y, row))
    y -= step
