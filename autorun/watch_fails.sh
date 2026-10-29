#!/bin/sh
# Watches the log of a run (default logs/all.log) and prints the lines that matter the moment they are written: every
# failure, every error of the Lua or the engine, and the result, after which it ends. It also says so when the log has not
# grown for STALL seconds (default 90), once for each stall. ("cannot set object state type" and "Won't reload" are messages of
# the game itself.)
# NEWONLY=1: only what is written from now on (a resume of the original adds to the log of the run before it)
LOG="${1:-/c/Users/Joel/grim_tools/autorun/logs/all.log}"
STALL="${STALL:-90}"
pat='AUTORUN FAIL\|AUTORUN RESULT\|Error:\|ERROR:\|too many local\|failed to load'
skip=0
[ -n "$NEWONLY" ] && skip=$(grep -ac "" "$LOG" 2>/dev/null || echo 0)
seen=0
stalled=""
while true; do
	sleep 3
	[ -f "$LOG" ] || continue
	total=$(grep -ac "" "$LOG")
	# (a resume of the original empties the log after the watch began: from the start of it then)
	if [ "$total" -lt "$skip" ]; then
		skip=0
	fi
	cur=$(tail -n +$((skip + 1)) "$LOG")
	n=$(printf '%s\n' "$cur" | grep -a "$pat" | grep -avc "cannot set object state type\|Won.t reload")
	if [ "$n" -gt "$seen" ]; then
		printf '%s\n' "$cur" | grep -a "$pat" | grep -av "cannot set object state type\|Won.t reload" | tail -n $((n - seen)) | cut -c1-260
		seen=$n
	fi
	if printf '%s\n' "$cur" | grep -aq "AUTORUN RESULT"; then
		break
	fi
	age=$(( $(date +%s) - $(stat -c %Y "$LOG") ))
	if [ "$age" -gt "$STALL" ]; then
		if [ -z "$stalled" ]; then
			echo "STALLED: the log has not grown for ${age}s, last line: $(tail -n 1 "$LOG" | cut -c1-160)"
			stalled=1
		fi
	else
		stalled=""
	fi
done
