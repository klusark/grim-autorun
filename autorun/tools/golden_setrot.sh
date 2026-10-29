#!/bin/sh
# Regression test: the angle that is seen after SetActorRot on a tilted sector, with and without the turn key, and the first steps of the walk
# (tests/probe_setrot.lua) against what the original gave (tests/golden/probe_setrot_orig.txt): the turn rate of the walker is negative after an immediate
# SetActorRot until an update turns the heading that is seen, the key turns the other way until then.   sh tools/golden_setrot.sh
AR=/c/Users/Joel/grim_tools/autorun
cd "$AR"
TESTSETS=1 SIMMS=17 EXTRA="nav_cases.lua ar_fixture.lua ar_nt_lib.lua nav_known.lua nav_coll_expect.lua nav_slide_expect.lua rules_expect.lua rules_known.lua" timeout 300 sh run_chapter.sh tests/probe_setrot.lua 300 > /dev/null 2>&1
grep -a "PROBE" logs/probe_setrot.log | sed 's/^.*PROBE/PROBE/' > logs/golden_setrot_sv.txt
if python3 tools/numdiff.py logs/golden_setrot_sv.txt tests/golden/probe_setrot_orig.txt 2e-4 > logs/golden_setrot_diff.txt; then echo "GOLDEN setrot PASSED"; else echo "GOLDEN setrot FAILED"; head -8 logs/golden_setrot_diff.txt; exit 1; fi
