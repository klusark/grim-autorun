# Compares the T47 frame lines (tests/diag_ch47b.lua) of a ScummVM log and a log of the original, frame by frame.
#   cmp_t47.py <scummvm log> <original log> [shift ms] [pos tol m] [yaw tol deg] [lines of context]
# Prints the first frame in which they differ by more than the tolerances, with the lines around it.
import re
import sys


def load(p):
    d = {}
    for l in open(p, errors="ignore"):
        m = re.search(r"T47\s+(\d+)\s+(-?[\d.]+)\s+(-?[\d.]+)\s+(-?[\d.]+)\s+yaw\s+(-?[\d.]+)(?:\s+pr\s+(-?[\d.]+)\s+(-?[\d.]+))?\s+mv\s+(\S*)\s+tn\s+(\S*)\s+drift\s+(\S*)\s+cut\s+(\d+)", l)
        if m:
            d[int(m[1])] = (float(m[2]), float(m[3]), float(m[4]), float(m[5]) % 360, m[8], m[9], m[10], int(m[11]), m[6], m[7])
    return d


a = load(sys.argv[1])
b = load(sys.argv[2])
sh = int(sys.argv[3]) if len(sys.argv) > 3 else 0
ptol = float(sys.argv[4]) if len(sys.argv) > 4 else 0.002
ytol = float(sys.argv[5]) if len(sys.argv) > 5 else 0.05
ctx = int(sys.argv[6]) if len(sys.argv) > 6 else 8
frames = sorted(t for t in a if t + sh in b)
first = None
for t in frames:
    x = a[t]
    y = b[t + sh]
    dpos = max(abs(x[0] - y[0]), abs(x[1] - y[1]), abs(x[2] - y[2]))
    dyaw = abs(((x[3] - y[3] + 180) % 360) - 180)
    if dpos > ptol or dyaw > ytol or x[7] != y[7]:
        first = t
        break
print("frames compared %d (of %d / %d); first difference: %s" % (len(frames), len(a), len(b), first))
if first is not None:
    i = frames.index(first)
    for t in frames[max(0, i - 2):i + ctx]:
        x = a[t]
        y = b[t + sh]
        print(t, "S %.5f %.5f %.5f %9.4f cut %d" % (x[0], x[1], x[2], x[3], x[7]), "| O %.5f %.5f %.5f %9.4f cut %d" % (y[0], y[1], y[2], y[3], y[7]))
