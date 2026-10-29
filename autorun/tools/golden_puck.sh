#!/bin/sh
# Regression test: ActorPuckOrient (FUN_00490f50) and the angles that SetActorRot leaves (pitch and roll as set, the heading from the forward row of the three angles
# in the frame of the walker, FUN_0044f080): the three angles of Manny frame by frame for ten starts, on the flat floor of mo and the tilted sector of bs, with the
# orientation on and off, standing and walking, against the original (tests/golden/puck_orig.txt, tests/probe_puck.lua), within a thousandth of a degree.
#   sh tools/golden_puck.sh
AR=/c/Users/Joel/grim_tools/autorun
cd "$AR"
EX="nav_cases.lua ar_fixture.lua ar_nt_lib.lua nav_known.lua nav_coll_expect.lua nav_slide_expect.lua rules_expect.lua rules_known.lua"
EXTRA="$EX" SIMMS=17 timeout 300 sh run_chapter.sh tests/probe_puck.lua 300 > logs/golden_puck.out 2>&1
python3 - <<'PY'
import re
import sys


def load(f):
    d = {}
    for line in open(f, errors="ignore"):
        m = re.search(r"PROBE (\S+) (\d+) pos (\S+) (\S+) (\S+) rot (\S+) (\S+) (\S+)", line)
        if m:
            d[(m.group(1), int(m.group(2)))] = [float(m.group(i)) for i in range(3, 9)]
        else:
            m = re.match(r"(\S+) (\d+) pos (\S+) (\S+) (\S+) rot (\S+) (\S+) (\S+)", line)
            if m:
                d[(m.group(1), int(m.group(2)))] = [float(m.group(i)) for i in range(3, 9)]
    return d


a = load("logs/probe_puck.log")
b = load("tests/golden/puck_orig.txt")
bad = [k for k in b if k not in a or max(abs(x - y) for x, y in zip(a[k], b[k])) > 0.001]
print("GOLDEN puck %s (%d values, %d differ)" % ("PASSED" if not bad else "FAILED", len(b), len(bad)))
sys.exit(1 if bad else 0)
PY
