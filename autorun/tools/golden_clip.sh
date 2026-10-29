#!/bin/sh
# Regression test for SetActorClipPlane / SetActorClipActive and the side test of SetActorShadowValid (the rules clip_plane and shadow_valid of the engine):
# frames of tests/probe_clip.lua and tests/probe_shadow_scan.lua, with the rules on and off (GRIMOFF), compared pixel by pixel (tools/pngdiff.py).
#   - an actor with the clip off, or switched off again, looks like one that was never clipped;
#   - the plane through Manny (x and z) changes the frame when it is on, and does not when the rule is off;
#   - the shadow of Manny is hidden by SetActorShadowValid(1) at some of the places of os (the same frames with the rule off still show it), and drawn as before with the value 0.
# (the bd frames are checked against frames of the original; the others are the behaviours of the original from its code, FUN_004950a0 / FUN_0040d880 / FUN_004936e0; no frames of the original were taken for them.)
#   sh tools/golden_clip.sh
AR=/c/Users/Joel/grim_tools/autorun
cd "$AR"
EX="nav_cases.lua ar_fixture.lua ar_nt_lib.lua nav_known.lua nav_coll_expect.lua nav_slide_expect.lua rules_expect.lua rules_known.lua"
T=$AR/shots/golden_clip
mkdir -p "$T/on" "$T/off" "$T/sh_on" "$T/sh_off" "$T/bd"
DUMPDIR=C:/Users/Joel/grim_tools/autorun/shots/golden_clip/on EXTRA="$EX" SIMMS=17 timeout 200 sh run_chapter.sh tests/probe_clip.lua 120 > /dev/null 2>&1
DUMPDIR=C:/Users/Joel/grim_tools/autorun/shots/golden_clip/off GRIMOFF="clip_plane" EXTRA="$EX" SIMMS=17 timeout 200 sh run_chapter.sh tests/probe_clip.lua 120 > /dev/null 2>&1
DUMPDIR=C:/Users/Joel/grim_tools/autorun/shots/golden_clip/sh_on EXTRA="$EX" SIMMS=17 timeout 200 sh run_chapter.sh tests/probe_shadow_scan.lua 120 > /dev/null 2>&1
DUMPDIR=C:/Users/Joel/grim_tools/autorun/shots/golden_clip/sh_off GRIMOFF="shadow_valid" EXTRA="$EX" SIMMS=17 timeout 200 sh run_chapter.sh tests/probe_shadow_scan.lua 120 > /dev/null 2>&1
DUMPDIR=C:/Users/Joel/grim_tools/autorun/shots/golden_clip/bd EXTRA="$EX" SIMMS=17 timeout 200 sh run_chapter.sh tests/probe_clip_bd2.lua 120 > /dev/null 2>&1
python3 - <<'PY'
import subprocess
import sys

T = "shots/golden_clip/"


def diff(a, b):
    out = subprocess.run([sys.executable, "tools/pngdiff.py", T + a, T + b], capture_output=True, text=True).stdout
    return int(out.split(",")[0].strip("("))


bad = []
def check(name, ok):
    if not ok:
        bad.append(name)

check("noclip == off (clip on)", diff("on/mo_noclip.png", "on/mo_off.png") == 0)
check("x plane changes the frame", diff("on/mo_noclip.png", "on/mo_clipA.png") > 500)
check("z plane changes the frame", diff("on/mo_noclip.png", "on/mo_clipB.png") > 500)
check("the two planes cut differently", diff("on/mo_clipA.png", "on/mo_clipB.png") > 0)
for n in ("mo_clipA", "mo_clipB"):
    check("rule clip_plane off: %s as not clipped" % n, diff("off/mo_noclip.png", "off/%s.png" % n) == 0)
check("rule off equals the unclipped frame of the rule on", diff("on/mo_noclip.png", "off/mo_clipA.png") == 0)
hidden = 0
for s in ("01", "02", "03", "04", "05"):
    # (the frames of the two runs are taken at the same frames, so the same pose; the old test of ScummVM does not look at the value)
    if diff("sh_off/s%s_v1.png" % s, "sh_on/s%s_v1.png" % s) > 100:
        hidden += 1
    # with the value 0 both draw the shadow
    check("shadow with value 0 as before: s%s" % s, diff("sh_off/s%s_v0.png" % s, "sh_on/s%s_v0.png" % s) == 0)
check("shadow hidden on one side at some places (%d)" % hidden, hidden >= 1)
# bd, the extinguisher spray with the planes of bd.clip_planes running or not (frames of the original, tests/probe_clip_bd2.lua through tools/framecap.py): the spray is
# cut off where Manny stands in the sectors 1, 6 and 7 (heading 45 or 135, except sector 1 at 135, where the original shows no difference either)
for s, y in (("01", 45), ("06", 135), ("06", 45), ("07", 135), ("07", 45)):
    check("bd spray cut by the planes: sector %s yaw %d" % (s, y), diff("bd/b%s_%d_on.png" % (s, y), "bd/b%s_%d_off.png" % (s, y)) > 100)
check("bd sector 01 yaw 135 unchanged", diff("bd/b01_135_on.png", "bd/b01_135_off.png") == 0)
if bad:
    print("golden_clip FAILED: " + "; ".join(bad))
    sys.exit(1)
print("golden_clip ok: the plane clips, %d of 5 places hide the shadow on one side" % hidden)
PY
