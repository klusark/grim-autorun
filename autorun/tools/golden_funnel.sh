#!/bin/sh
# Regression test for two walks that were stuck in ScummVM and not in the original (frames in logs/orig_ciwalk.log and logs/orig_ddcorner.log, the probes run on the original):
#  - the funnel sector in front of the door of ci (FUN_004a6790 picks the edge of a funnel that the walk goes along: the shorter of the opposite pair that is not the more
#    parallel; ScummVM always took the first): tests/probe_ciwalk.lua steers Manny through the corridor to the door, he leaves it at (-0.5266 1.5832) in the original;
#  - the search order of the sectors of a set that was restored from a saved game (it was empty, so that a walk over the edge to the next sector found none and
#    Manny slid along the edge): tests/probe_ddcorner.lua loads the game of ch16 and walks him across the edge of two sectors of dd, he is at (5.8566 -1.4347) in the original
#    after 49 frames.   sh tools/golden_funnel.sh
AR=/c/Users/Joel/grim_tools/autorun
cd "$AR"
EX="nav_cases.lua ar_fixture.lua ar_nt_lib.lua nav_known.lua nav_coll_expect.lua nav_slide_expect.lua rules_expect.lua rules_known.lua"
EXTRA="$EX" SIMMS=16 timeout 300 sh run_chapter.sh tests/probe_ciwalk.lua 120 > /dev/null 2>&1
SIMMS=16 timeout 300 sh run_chapter.sh tests/probe_ddcorner.lua 16 > /dev/null 2>&1
python3 - <<'PY'
import re
import sys

bad = []
last = None
for line in open("logs/probe_ciwalk.log", errors="ignore"):
    m = re.search(r"PROBE w \d+ k (\d+) (\S+) (\S+) yaw", line)
    if m:
        last = (int(m.group(1)), float(m.group(2)), float(m.group(3)))
if not last or last[0] != 10 or abs(last[1] + 0.5266) > 0.01 or abs(last[2] - 1.5832) > 0.01:
    bad.append("ciwalk ends at %s" % (last,))
at49 = None
for line in open("logs/probe_ddcorner.log", errors="ignore"):
    m = re.search(r"PROBE c 49 (\S+) (\S+) ", line)
    if m:
        at49 = (float(m.group(1)), float(m.group(2)))
if not at49 or abs(at49[0] - 5.8566) > 0.05 or abs(at49[1] + 1.4347) > 0.05:
    bad.append("ddcorner at frame 49 is %s" % (at49,))
print("GOLDEN funnel %s%s" % ("PASSED" if not bad else "FAILED ", "; ".join(bad)))
sys.exit(1 if bad else 0)
PY
