#!/bin/sh
# Regression test: a walk along a planned path in the garage (tests/probe_pathwalk.lua), the position and the forward vector of the walker at every step of
# Walker_WalkSectors against the original (tests/golden/pathwalk_orig.txt, from the tracer). Bit for bit.   sh tools/golden_pathwalk.sh
AR=/c/Users/Joel/grim_tools/autorun
cd "$AR"
DEBUGFLAGS=scripts,actors TESTSETS=1 SIMMS=17 EXTRA="nav_cases.lua ar_fixture.lua ar_nt_lib.lua nav_known.lua nav_coll_expect.lua nav_slide_expect.lua rules_expect.lua rules_known.lua" timeout 300 sh run_chapter.sh tests/probe_pathwalk.lua 300 > /dev/null 2>&1
python3 - <<'PY'
import re
sv = []
for line in open("logs/probe_pathwalk.log", errors="ignore"):
    m = re.match(r"WALKSEC (\S+) depth (\d+) dist (\S+) pos (\S+) (\S+) (\S+) fwd (\S+) (\S+) (\S+)", line)
    if m:
        sv.append([float(m.group(i)) for i in range(4, 10)])
exp = []
for line in open("tests/golden/pathwalk_orig.txt"):
    m = re.match(r"WALKSEC (\d+) pos (\S+) (\S+) (\S+) fwd (\S+) (\S+) (\S+)", line)
    exp.append([float(m.group(i)) for i in range(2, 8)])
worst = 0.0
for a, b in zip(sv, exp):
    worst = max(worst, max(abs(x - y) for x, y in zip(a, b)))
ok = len(sv) == len(exp) and worst == 0
print("GOLDEN pathwalk %s (%d / %d calls, largest difference %.3g)" % ("PASSED" if ok else "FAILED", len(sv), len(exp), worst))
PY
