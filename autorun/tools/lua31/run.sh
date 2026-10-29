#!/bin/sh
# Tier A: the planner tests, offline, in the Lua 3.1 of the original game (its LUA.DLL; lua31.exe is built from host.c with the
# 32 bit gcc: PATH=/c/msys64/mingw32/bin:$PATH gcc -O1 -o lua31.exe host.c). Usage: tools/lua31/run.sh [files after the cases]
# The cases run in batches of 100 (the Lua of the game stops a script that runs long without a break_here); the counts are added up.
D=$(cd "$(dirname "$0")" && pwd)
AR=$(cd "$D/../.." && pwd)
cd "$D"
cp -n "/c/GOG Games/GRIMDATA/LUA.DLL" . 2>/dev/null
# (the walks of a full run as cases, when tools/gen_cases.py has made them: FULL=1 sh run.sh; 400 cases take 3 minutes, the core 1 second)
RUNCASES=""
[ -n "$FULL" ] && [ -f "$AR/nav_cases_run.lua" ] && RUNCASES="$AR/nav_cases_run.lua"
from=1
pass=0
run=0
while :; do
	to=$((from + 99))
	r=$(./lua31.exe LUA.DLL prelude.lua "$AR/ar_nav.lua" "$AR/nav_setfile.lua" "$AR/ar_nav_sets.lua" $RUNCASES "$AR/nav_cases.lua" offline.lua "=AR_NT_FROM=$from AR_NT_TO=$to" "$@" offline_run.lua 2>&1)
	echo "$r" | grep -a "FAIL\|ERROR\|error"
	s=$(echo "$r" | grep -a "NAVTEST SUMMARY unit" | tail -1)
	p=$(echo "$s" | sed "s|.*unit \([0-9]*\)/\([0-9]*\).*|\1|")
	t=$(echo "$s" | sed "s|.*unit \([0-9]*\)/\([0-9]*\).*|\2|")
	pass=$((pass + ${p:-0}))
	run=$((run + ${t:-0}))
	echo "$r" | grep -aq "NAVTEST LAST" && break
	echo "$r" | grep -aq "NAVTEST SUMMARY" || break
	from=$((to + 1))
done
echo "NAVTEST SUMMARY unit $pass/$run"
