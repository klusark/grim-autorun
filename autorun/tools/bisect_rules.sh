#!/bin/sh
# Runs the slide and turn tiers of the navigation tests on ScummVM once with every rule of the engine on and once for each rule switched off (GRIMOFF of
# run_chapter.sh), to find the rule that changes a result:  sh tools/bisect_rules.sh [tiers, default "slide turn"] [rules, default the new ones]
AR=/c/Users/Joel/grim_tools/autorun
cd "$AR"
tiers=${1:-"slide turn"}
rules=${2:-"chore_timing turn_actor_to path_planner movie_frame"}
t=""
for x in $tiers; do t="$t$x = 1, "; done
echo "AR_NT_TIERS = { $t}" > nt_run_bisect.lua
for off in "" $rules; do
	GRIMOFF="$off" TESTSETS=1 SIMMS=17 LOGTAG=_bisect EXTRA="nav_cases.lua ar_fixture.lua ar_nt_lib.lua nav_known.lua nav_coll_expect.lua nav_slide_expect.lua rules_expect.lua rules_known.lua nt_run_bisect.lua" timeout 900 sh run_chapter.sh test_nav.lua 900 > logs/tn_bisect.out 2>&1
	echo "== off: ${off:-nothing}"
	grep -a "NAVTEST \(slide\|turn\) .* FAIL" logs/test_nav_bisect.log | sed 's/^.*NAVTEST //' | sort -u | cut -c1-150
	grep -a "NAVTEST SUMMARY" logs/test_nav_bisect.log | sed 's/^.*NAVTEST //' | sort -u
done
