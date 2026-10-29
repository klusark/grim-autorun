import re
import sys


def load(f):
    d = {}
    for line in open(f, errors="ignore"):
        m = re.search(r"PROBE (\S+) (\d+) pos (\S+) (\S+) (\S+) rot (\S+) (\S+) (\S+)", line)
        if m:
            d[(m.group(1), int(m.group(2)))] = [float(m.group(i)) for i in range(3, 9)]
    return d


a = load(sys.argv[1])
b = load(sys.argv[2])
tol = float(sys.argv[3]) if len(sys.argv) > 3 else 0.02
bad = {}
for k in sorted(b):
    if k in a and max(abs(x - y) for x, y in zip(a[k], b[k])) > tol:
        bad.setdefault(k[0], []).append((k[1], round(max(abs(x - y) for x, y in zip(a[k], b[k])), 3)))
for t in sorted({k[0] for k in b}):
    print(t, len([k for k in b if k[0] == t]), "bad", bad.get(t, [])[:4])
