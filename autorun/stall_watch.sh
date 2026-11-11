#!/bin/sh
# Kills scummvm when a run stalls: no new AUTORUN line in the log for N seconds of the wall clock (the scripts of the game have stopped, so no
# timeout of the autorun, which counts game time, can fire, while the engine goes on with its frames).
#
#   stall_watch.sh <log> [seconds, default 90] [pid of the script that started the run: the watch ends with it]
log="$1"
limit="${2:-90}"
parent="$3"
[ "$limit" -gt 0 ] 2>/dev/null || exit 0
last=-1
since=$(date +%s)
while sleep 5; do
	[ -n "$parent" ] && ! kill -0 "$parent" 2>/dev/null && exit 0
	# (the cpu time of the game so far, the last sample kept: the wall time of a run depends on what else the machine does, the cpu time does not)
	cpu=$(sh "$(dirname "$0")/tools/svm_ps.sh" cpu)
	[ -n "$cpu" ] && echo "$cpu" > "${log%.log}.cpu"
	n=$(grep -c "AUTORUN" "$log" 2>/dev/null)
	if [ "$n" != "$last" ]; then
		last="$n"
		since=$(date +%s)
	fi
	if [ $(( $(date +%s) - since )) -ge "$limit" ]; then
		# (what the scripts are doing, asked of the engine through its remote Lua, if the run has one: SCUMMVM_LUA_REMOTE is the folder of it)
		if [ -n "$SCUMMVM_LUA_REMOTE" ]; then
			rm -f "$SCUMMVM_LUA_REMOTE/cmd.out"
			cp "$(dirname "$0")/stall_diag.lua" "$SCUMMVM_LUA_REMOTE/cmd.lua"
			w=0
			while [ ! -f "$SCUMMVM_LUA_REMOTE/cmd.out" ] && [ $w -lt 10 ]; do sleep 1; w=$((w + 1)); done
			echo "Debug: AUTORUN STALL state: $(cat "$SCUMMVM_LUA_REMOTE/cmd.out" 2>/dev/null || echo 'no answer from the engine')" >> "$log"
			sleep 1
		fi
		echo "Debug: AUTORUN STALL: no AUTORUN output for $limit s, scummvm killed" >> "$log"
		# (only the engine of this run, found by its ini _scummvm_<parent>.ini: an EMI run or a clean-room run going on at the same time is left alone)
		if [ -n "$parent" ]; then
			powershell.exe -NoProfile -Command "Get-CimInstance Win32_Process -Filter \"Name='scummvm.exe'\" | Where-Object { \$_.CommandLine -like '*_scummvm_${parent}.ini*' } | ForEach-Object { Stop-Process -Id \$_.ProcessId -Force }" > /dev/null 2>&1
		else
			taskkill //F //IM scummvm.exe > /dev/null 2>&1
		fi
		exit 0
	fi
done
