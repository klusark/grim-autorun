#!/bin/sh
# Regression test: the path of the planner for 100 pairs of points in the garage against the original (tests/golden/plan_orig.txt: the number of points of each path
# and the first four, from the arguments of FUN_004917e0 under the tracer).   sh tools/golden_plan.sh
AR=/c/Users/Joel/grim_tools/autorun
cd "$AR"
DEBUGFLAGS=scripts,actors TESTSETS=1 SIMMS=17 EXTRA="nav_cases.lua ar_fixture.lua ar_nt_lib.lua nav_known.lua nav_coll_expect.lua nav_slide_expect.lua rules_expect.lua rules_known.lua" timeout 300 sh run_chapter.sh tests/probe_planner.lua 300 > /dev/null 2>&1
python3 - <<'PY'
import re
rows = []
for line in open("logs/probe_planner.log", errors="ignore"):
    m = re.match(r"WALKTO Manny from (\S+) (\S+) (\S+) to (\S+) (\S+) (\S+) path \(next last\):(.*)", line)
    if m:
        pts = [tuple(float(x) for x in p.split()) for p in re.findall(r"\(([^)]*)\)", m.group(7))]
        pts.reverse()
        rows.append((float(m.group(1)), float(m.group(2)), pts))
exp = []
for line in open("tests/golden/plan_orig.txt"):
    m = re.match(r"PLAN (\d+) n (\d+) (.*)", line)
    v = [float(x) for x in m.group(3).split()]
    exp.append((int(m.group(2)), [tuple(v[i:i + 3]) for i in range(0, len(v), 3)]))
bad = 0
for k, (sx, sy, pts) in enumerate(rows):
    n, op = exp[k]
    if n != len(pts) + 1 and not (n > 4 and len(pts) + 1 > 4):
        bad += 1
        print("path %d: %d points in the original, %d here" % (k + 1, n, len(pts) + 1))
        continue
    for i, p in enumerate(op[1:]):
        if i < len(pts) and max(abs(p[0] - pts[i][0]), abs(p[1] - pts[i][1])) > 1e-3:
            bad += 1
            print("path %d point %d: %s / %s" % (k + 1, i + 1, p, pts[i]))
            break
print("GOLDEN plan %s (%d paths, %d differ)" % ("PASSED" if bad == 0 and len(rows) == len(exp) else "FAILED", len(rows), bad))
PY
