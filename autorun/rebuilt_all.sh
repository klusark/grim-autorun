#!/bin/sh
# All test tiers on the REBUILT game, one after the other (they share GRIMDATA/autorun_all.lua and the game's log):
# sh rebuilt_all.sh  -> logs/rebuilt_<tier>.log, summary on stdout. Compare with the original: python tools/compare_navtest.py logs/orig_tn_full.log logs/rebuilt_walk.log walk
AR=/c/Users/Joel/grim_tools/autorun
EXTRA="nav_known.lua nav_coll_expect.lua nav_slide_expect.lua rules_expect.lua rules_known.lua"
cd "$AR"
for t in "unit:unit" "walk:walk" "move:move" "coll:coll" "misc:turn slide"; do
	name=${t%%:*}; tiers=${t#*:}
	list=""; for x in $tiers; do list="$list$x = 1, "; done
	{ echo "AR_NT_TIERS = { $list}"; cat $EXTRA test_nav.lua; } > logs/rt_$name.lua
	sh rebuilt_test.sh "$AR/logs/rt_$name.lua" 1800 "$AR/logs/rebuilt_$name.log" | tail -1
	echo "$name: $(grep -ac "NAVTEST $name .*PASS\|NAVTEST turn .*PASS\|NAVTEST slide .*PASS" logs/rebuilt_$name.log) pass, $(grep -ac "NAVTEST [a-z]* .* FAIL" logs/rebuilt_$name.log) fail"
done
{ cat $EXTRA test_rules.lua; } > logs/rt_rules.lua
sh rebuilt_test.sh "$AR/logs/rt_rules.lua" 1800 "$AR/logs/rebuilt_rules.log" | tail -1
echo "rules: $(grep -ac "NAVTEST rules .*PASS" logs/rebuilt_rules.log) pass, $(grep -ac "NAVTEST rules .* FAIL" logs/rebuilt_rules.log) fail"
