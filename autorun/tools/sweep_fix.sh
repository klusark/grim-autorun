#!/bin/sh
# Runs the whole game in speed100 over and over (the live game is what counts: a chapter can pass from its save and fail in the run). Each time a sweep
# or the lines said of a dialog break a chapter, the set (AR_NO_SWEEP) or the dialog (AR_NO_TALK) goes into ex00_sweep.lua and the run starts again.
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
	who=${r%%|*}; why=${r#*|}; kind=${who%%:*}; name=${who#*:}
	[ "$who" = "?" ] && break
	why=$(echo "$why" | tr -d '"')
	if [ "$kind" = "talk" ]; then
		grep -q "AR_NO_TALK\[\"$name\"\]" ex00_sweep.lua && { echo "already listed: $name"; break; }
		printf 'AR_NO_TALK["%s"] = "a chapter failed after lines of it were said: %s"\n' "$name" "$why" >> ex00_sweep.lua
	else
		grep -q "AR_NO_SWEEP\[\"$name\"\]" ex00_sweep.lua && { echo "already listed: $name"; break; }
		printf 'AR_NO_SWEEP["%s"] = "a chapter failed after the sweep: %s"\n' "$name" "$why" >> ex00_sweep.lua
	fi
done
