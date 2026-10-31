#!/bin/sh
# Runs the whole game in speed100 (with the checkpoints, SAVE=1) until it passes. When a chapter fails, the set or dialog whose extra came before the failure is
# blocked in ex00_sweep.lua and the chapter is played again from the save of the one before it (quick) until it passes; then the whole game again, which is
# what counts (a chapter can pass from its save and fail in the run).
#   sweep_fix.sh [rounds]
AR=/c/Users/Joel/grim_tools/autorun
cd "$AR" || exit 1
. "$AR/tools/sweep_lib.sh"
n=0
while [ $n -lt "${1:-12}" ]; do
	n=$((n + 1))
	SAVE=1 MODE=speed100 LOG=w_100 sh run_all.sh 3000 > /tmp/sweep_fix.out 2>&1
	r=$(python tools/sweep_blame.py logs/w_100.log)
	echo "round $n: $r"
	[ "$r" = "PASSED" ] && break
	ch=$(grep "AUTORUN === chapter" logs/w_100.log | tail -1 | sed 's/.*chapter \(.*\) ===.*/\1/')
	block "$r" || { echo "no new block for $ch"; break; }
	t=0
	while [ $t -lt 6 ] && [ -n "$ch" ]; do
		t=$((t + 1))
		MODE=speed100 LOGTAG=_s100 sh run_chapter.sh "$ch.lua" 900 > /tmp/sweep_ch.out 2>&1
		rr=$(python tools/sweep_blame.py "logs/${ch}_s100.log")
		echo "  $ch replay $t: $rr"
		[ "$rr" = "PASSED" ] && break
		block "$rr" || break
	done
done
