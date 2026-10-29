#!/bin/sh
# Regression test: Manny in COLLISION_BOX mode walking into Velasco (box or sphere), the 162 starts of the coll tier of test_nav.lua: the original takes the actor that
# moves for a sphere whatever its mode is (FUN_004939f0), so the end points are those of the original (tests/golden/collbox_orig.txt, to 0.05); the cases in
# tests/golden/collbox_known.txt end elsewhere (slides along a face that go to the other side by float noise, and starts where the original throws Manny far away).
#   sh tools/golden_collbox.sh
AR=/c/Users/Joel/grim_tools/autorun
cd "$AR"
EX="nav_cases.lua ar_fixture.lua ar_nt_lib.lua nav_known.lua nav_coll_expect.lua nav_slide_expect.lua rules_expect.lua rules_known.lua"
EXTRA="$EX" SIMMS=17 timeout 900 sh run_chapter.sh tests/collbox_run.lua 600 > logs/golden_collbox.out 2>&1
grep -a "NAVTEST coll " logs/golden_collbox.out | sed 's/.*NAVTEST coll \(\S*\) \S* ended at \(\S* \S*\).*/\1 \2/' > logs/golden_collbox_sv.txt
python3 - <<'PY'
import sys

def load(p):
    d = {}
    for l in open(p):
        a = l.split()
        if len(a) == 3 and a[0] not in d:
            d[a[0]] = (float(a[1].strip(",")), float(a[2].strip(",")))
    return d

sv = load("logs/golden_collbox_sv.txt")
orig = load("tests/golden/collbox_orig.txt")
known = set(open("tests/golden/collbox_known.txt").read().split())
bad = sorted(k for k in orig if k not in known and (k not in sv or max(abs(sv[k][0] - orig[k][0]), abs(sv[k][1] - orig[k][1])) > 0.05))
if bad:
    print("GOLDEN collbox FAILED: %d of %d differ from the original: %s" % (len(bad), len(orig), " ".join(bad[:8])))
    sys.exit(1)
print("GOLDEN collbox PASSED (%d starts, %d known differences)" % (len(orig), len(known)))
PY
