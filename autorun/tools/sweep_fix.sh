#!/bin/sh
# Runs the whole game in speed100 (with the checkpoints, SAVE=1) until it passes. When a chapter fails, the set or dialog whose extra came before the failure is
# blocked in ex00_sweep.lua and the chapter is played again from the save of the one before it (quick) until it passes; then the whole game again, which is
# what counts (a chapter can pass from its save and fail in the run).
#   sweep_fix.sh [rounds]     (ROUND_MAX=900 s for a round of the whole game, REPLAY_MAX=300 s for a chapter played again: a try that takes longer is killed)
AR=/c/Users/Joel/grim_tools/autorun
cd "$AR" || exit 1
. "$AR/tools/sweep_lib.sh"
n=0
while [ $n -lt "${1:-12}" ]; do
	n=$((n + 1))
	SAVE=1 MODE=speed100 LOG=w_100 sh run_all.sh ${ROUND_MAX:-900} > /tmp/sweep_fix.out 2>&1
	r=$(ROUND_MAX=${ROUND_MAX:-900} python tools/sweep_blame.py logs/w_100.log)
	# (each round's log is kept: the next round writes w_100.log again)
	cp logs/w_100.log "logs/w_100_r$n.log"
	echo "round $n: $r"
	[ "$r" = "PASSED" ] && break
	# (no result at all: the engine was killed from outside, e.g. by another session stopping its own run; the round is played again, twice at most in a row)
	if [ "$r" = "?|no result" ]; then
		lost=$((${lost:-0} + 1))
		[ "$lost" -le 2 ] && { echo "  the engine stopped without a result: the round again"; continue; }
		echo "  no result $lost times in a row: stopping"; break
	fi
	lost=0
	ch=$(grep "AUTORUN === chapter" logs/w_100.log | tail -1 | sed 's/.*chapter \(.*\) ===.*/\1/')
	block "$r" "$ch" || { echo "no new block for $ch"; break; }
	t=0
	while [ $t -lt 6 ] && [ -n "$ch" ]; do
		t=$((t + 1))
		MODE=speed100 LOGTAG=_s100 sh run_chapter.sh "$ch.lua" ${REPLAY_MAX:-300} > /tmp/sweep_ch.out 2>&1
		rr=$(ROUND_MAX=${REPLAY_MAX:-300} python tools/sweep_blame.py "logs/${ch}_s100.log")
		echo "  $ch replay $t: $rr"
		[ "$rr" = "PASSED" ] && break
		block "$rr" "$ch" || break
	done
done
