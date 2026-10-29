#!/bin/sh
# Regression test: the volume and pan SetSoundPosition gives a playing sound (places around the camera, volume ranges including the byte quirks, falloff distances,
# a change of the setup), against the original (tests/golden/soundpos_orig.txt, 92 values).   sh tools/golden_soundpos.sh
AR=/c/Users/Joel/grim_tools/autorun
cd "$AR"
EX="nav_cases.lua ar_fixture.lua ar_nt_lib.lua nav_known.lua nav_coll_expect.lua nav_slide_expect.lua rules_expect.lua rules_known.lua"
EXTRA="$EX" SIMMS=17 timeout 300 sh run_chapter.sh tests/probe_soundpos.lua 120 > logs/golden_soundpos.out 2>&1
grep -a "SNDPOS" logs/golden_soundpos.out | sed 's/.*SNDPOS //' > logs/golden_soundpos_sv.txt
if diff -q logs/golden_soundpos_sv.txt tests/golden/soundpos_orig.txt > /dev/null; then echo "GOLDEN soundpos PASSED ($(wc -l < logs/golden_soundpos_sv.txt) values)"; else echo "GOLDEN soundpos FAILED"; diff logs/golden_soundpos_sv.txt tests/golden/soundpos_orig.txt | head; exit 1; fi
