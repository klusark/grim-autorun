#!/bin/sh
# Regression test: the position and the forward vector of Manny at every call of Walker_WalkSectors in chapter 1 (the walks of the office and the hallway, the
# planned paths, the hot box teleport; 2052 calls) against the original (tests/golden/ch01_walk_orig.txt, from the tracer: GRIMTRACE_BP=4a8610
# GRIMTRACE_PEEK="ecx+0,ecx+c,ecx+18,ecx+24"), bit for bit as floats.   sh tools/golden_ch01walk.sh
AR=/c/Users/Joel/grim_tools/autorun
cd "$AR"
cat fullcmp_lib.lua ar_lib.lua > _fc_ar_lib.lua
DEBUGFLAGS=actors LIB=_fc_ar_lib.lua SIMMS=17 SIMFPS=60 TS=100 timeout 300 sh run_chapter.sh ch01_work_order.lua 100 > /dev/null 2>&1
rm -f _fc_ar_lib.lua
python3 - <<'PY'
import re
import struct


def f32(x):
    return struct.unpack("<f", struct.pack("<f", x))[0]


sv = []
for line in open("logs/ch01_work_order.log", errors="ignore"):
    m = re.match(r"WALKSEC (\S+) depth (\d+) dist (\S+) pos (\S+) (\S+) (\S+) fwd (\S+) (\S+) (\S+)", line)
    if m:
        sv.append([f32(float(m.group(i))) for i in range(4, 10)])
exp = []
for line in open("tests/golden/ch01_walk_orig.txt"):
    m = re.match(r"WALKSEC (\d+) pos (\S+) (\S+) (\S+) fwd (\S+) (\S+) (\S+)", line)
    exp.append([f32(float(m.group(i))) for i in range(2, 8)])
bad = 0
first = None
for k, (a, b) in enumerate(zip(sv, exp)):
    if any(x != y and not (x == 0 and y == 0) for x, y in zip(a, b)):
        bad += 1
        if first is None:
            first = k + 1
ok = len(sv) >= len(exp) and bad == 0
print("GOLDEN ch01walk %s (%d calls of the original, %d of ScummVM, %d differ%s)" % ("PASSED" if ok else "FAILED", len(exp), len(sv), bad, "" if first is None else ", the first is call %d" % first))
PY
