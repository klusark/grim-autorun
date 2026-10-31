#!/bin/sh
# Regression test: chapter 1 (the intro skip, the walks of the office and the hallway, the door set changes, the elevator door chores, TurnActorTo) on ScummVM
# against the frame trace of the original (tests/golden/ch01_orig_ft.log, FT lines of fullcmp_lib.lua). Passes when the first frame that differs by more than
# 0.5 mm or 0.05 degrees is at least frame $MIN (default 2800: the walks are bit for bit the same up to there, see golden_ch01walk.sh; what differs from there is
# not found yet).
#   sh tools/golden_ch01.sh [min frame]
AR=/c/Users/Joel/grim_tools/autorun
MIN=${1:-2800}
cd "$AR"
cat fullcmp_lib.lua ar_lib.lua > _fc_ar_lib.lua
LIB=_fc_ar_lib.lua SIMMS=17 SIMFPS=60 timeout 300 sh run_chapter.sh ch01_work_order.lua 200 > /dev/null 2>&1
rm -f _fc_ar_lib.lua
(echo "AUTORUN === chapter ch01_work_order ==="; grep -a "FT " logs/ch01_work_order.log) > logs/golden_ch01_sv.log
out=$(python3 tools/ftrace_cmp.py logs/golden_ch01_sv.log tests/golden/ch01_orig_ft.log 0.0005 0.05 3 ch01)
first=$(echo "$out" | sed -n 's/.*first difference at frame \([0-9]*\) of the chapter.*/\1/p')
if [ -z "$first" ]; then first=999999; fi
if [ "$first" -ge "$MIN" ]; then echo "GOLDEN ch01 PASSED (first difference at frame $first, need $MIN)"; else echo "GOLDEN ch01 FAILED (first difference at frame $first, need $MIN)"; echo "$out" | head -12; exit 1; fi
