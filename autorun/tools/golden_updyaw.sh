#!/bin/sh
# Regression test: the vector Walker_UpdateYaw (FUN_00491230) turns into the frame of the walker before it normalizes it (the two numbers that go into the asin), for the
# first 1000 updates of Manny in chapter 1, against the original (tests/golden/ch01_updyaw_orig.txt, from the tracer: GRIMTRACE_BP=4912e4 GRIMTRACE_PEEK="esi+24,esi+c";
# the vector is at [esp]), bit for bit as floats. The updates are matched by the position and the yaw that was seen.   sh tools/golden_updyaw.sh
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
    m = re.match(r"UPDYAW Manny l1 (\w+) yaw (\S+) pos (\S+) (\S+) pre (\S+) (\S+) ", line)
    if m:
        sv.append((float(m.group(2)), float(m.group(3)), float(m.group(4)), f32(float(m.group(5))), f32(float(m.group(6)))))
exp = []
for line in open("tests/golden/ch01_updyaw_orig.txt"):
    v = line.split()
    exp.append([float(x) for x in v[1:]])
j = 0
bad = 0
for o in exp:
    if j >= len(sv):
        break
    s = sv[j]
    if abs(o[0] - s[1]) < 0.03 and abs(o[1] - s[2]) < 0.03 and abs(o[2] - s[0]) < 2e-3:
        if f32(o[3]) != s[3] or f32(o[4]) != s[4]:
            bad += 1
        j += 1
ok = j == len(exp) and bad == 0
print("GOLDEN updyaw %s (%d updates matched of %d, %d differ)" % ("PASSED" if ok else "FAILED", j, len(exp), bad))
PY
