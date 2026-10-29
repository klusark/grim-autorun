# Compares the walker state at every step of the sector walk of the original (a breakpoint trace of Walker_WalkSectors, 0x4a8610, made with
#   GRIMRUN=./grimtrace.exe GRIMTRACE_LOG=<file> GRIMTRACE_BP=4a8610 GRIMTRACE_PEEK="ecx+0,ecx+c,ecx+18,ecx+24,ecx+30,ecx+5c" ...)
# with the WSTATE lines of ScummVM (DEBUGFLAGS=scripts,actors): the first step in which the position or the frame differ by more than the limit.
#   wstate_cmp.py <grimtrace log> <scummvm log> [actor name] [limit] [skip steps of the original]
# The steps of the two are matched in order for one actor (the original does not say which one a step belongs to: skip the steps before the walker
# of the actor starts: they are matched by position).
import re
import struct
import sys


def f(h):
    return struct.unpack("<f", struct.pack("<I", int(h, 16)))[0]


orig = []
cur = None
for l in open(sys.argv[1], errors="ignore"):
    l = l.rstrip("\n")
    if l.startswith("BP "):
        cur = {"peek": {}}
        orig.append(cur)
        continue
    if cur is None:
        continue
    m = re.match(r"\s+\[esp\+004\] ([0-9a-f]{8})", l)
    if m and "dist" not in cur:
        cur["dist"] = f(m[1])
    m = re.match(r"\s+peek (\w+\+\w+): ([0-9a-f ]+) /", l)
    if m:
        cur["peek"][m[1]] = [f(x) for x in m[2].split()[:3]]
sv = []
actor = sys.argv[3] if len(sys.argv) > 3 else "Manny"
for l in open(sys.argv[2], errors="ignore"):
    m = re.search(r"WSTATE (\S+) dist (\S+) pos (\S+) (\S+) (\S+) right (\S+) (\S+) (\S+) fwd (\S+) (\S+) (\S+) up (\S+) (\S+) (\S+)", l)
    if m and m[1] == actor:
        v = [float(x) for x in m.groups()[1:]]
        sv.append({"dist": v[0], "pos": v[1:4], "right": v[4:7], "fwd": v[7:10], "up": v[10:13]})
limit = float(sys.argv[4]) if len(sys.argv) > 4 else 1e-6
skip = int(sys.argv[5]) if len(sys.argv) > 5 else 0
print("original steps %d, scummvm steps for %s: %d" % (len(orig), actor, len(sv)))
# align: the first ScummVM step against the first step of the original after the skip whose position is the same
o = [h for h in orig[skip:] if "ecx+0" in h["peek"]]
if not sv or not o:
    sys.exit(0)
start = None
for i, h in enumerate(o):
    if max(abs(a - b) for a, b in zip(h["peek"]["ecx+0"], sv[0]["pos"])) < 1e-3:
        start = i
        break
if start is None:
    print("no step of the original at the first position of ScummVM", sv[0]["pos"])
    sys.exit(0)
for k, s in enumerate(sv):
    if start + k >= len(o):
        break
    h = o[start + k]
    pk = h["peek"]
    d = {
        "dist": abs(h.get("dist", 0) - s["dist"]),
        "pos": max(abs(a - b) for a, b in zip(pk["ecx+0"], s["pos"])),
        "right": max(abs(a - b) for a, b in zip(pk["ecx+c"], s["right"])),
        "fwd": max(abs(a - b) for a, b in zip(pk["ecx+18"], s["fwd"])),
        "up": max(abs(a - b) for a, b in zip(pk["ecx+24"], s["up"])),
    }
    if max(d.values()) > limit:
        print("step %d (original step %d) differs: %s" % (k, start + k, " ".join("%s %.3g" % (n, v) for n, v in d.items())))
        print(" original pos", pk["ecx+0"], "fwd", pk["ecx+18"], "right", pk["ecx+c"], "up", pk["ecx+24"], "dist", h.get("dist"))
        print(" scummvm  pos", s["pos"], "fwd", s["fwd"], "right", s["right"], "up", s["up"], "dist", s["dist"])
        break
else:
    print("all %d steps are the same within %g" % (min(len(sv), len(o) - start), limit))
