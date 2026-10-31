#!/bin/sh
# Regression test: the scheduling of the tasks of the game's Lua (start_script runs the first pass at once, the order of the tasks in a frame, how long sleep_for
# takes, the frame time of the first pass) against the original (tests/golden/probe_sched_orig.txt).   sh tools/golden_sched.sh
AR=/c/Users/Joel/grim_tools/autorun
cd "$AR"
SIMMS=17 SIMFPS=60 timeout 300 sh run_chapter.sh tests/probe_sched.lua 300 > /dev/null 2>&1
grep -a PROBE logs/probe_sched.log | sed 's/^.*PROBE/PROBE/' > logs/golden_sched_sv.txt
if diff -q logs/golden_sched_sv.txt tests/golden/probe_sched_orig.txt > /dev/null; then echo "GOLDEN sched PASSED"; else echo "GOLDEN sched FAILED"; diff logs/golden_sched_sv.txt tests/golden/probe_sched_orig.txt | head; exit 1; fi
