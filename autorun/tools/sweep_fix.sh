#!/bin/sh
# Runs the whole game in speed100 over and over; each time a sweep breaks a chapter, the set goes into ex00_sweep.lua (AR_NO_SWEEP) and the run starts again.
#   sweep_fix.sh [rounds]
AR=/c/Users/Joel/grim_tools/autorun
cd "$AR" || exit 1
n=0
while [ $n -lt "${1:-12}" ]; do
	n=$((n + 1))
	MODE=speed100 LOG=w_100 sh run_all.sh 3000 > /tmp/sweep_fix.out 2>&1
	r=$(python tools/sweep_blame.py logs/w_100.log)
	echo "round $n: $r"
	[ "$r" = "PASSED" ] && break
	set_name=${r%%|*}
	why=${r#*|}
	[ "$set_name" = "?" ] && break
	grep -q "AR_NO_SWEEP\[\"$set_name\"\]" ex00_sweep.lua && { echo "already listed: $set_name"; break; }
	printf 'AR_NO_SWEEP["%s"] = "a chapter failed after the sweep: %s"\n' "$set_name" "$(echo "$why" | tr -d '"')" >> ex00_sweep.lua
done
