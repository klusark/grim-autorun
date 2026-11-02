#!/bin/sh
# Runs a test file (or the whole-game autorun) on the REBUILT game (grim-decomp, build/run/grimfandango.exe) the way orig_test.sh
# does on the original: rebuilt_test.sh <test file | "test"> [max seconds] [log copy]
#   env: REBUILT_DIR (default /c/Users/Joel/grim-decomp/build/run), SIMTIME (ms per frame, default 17 = the original's patched frame time),
#        REBUILT_DELAY (seconds from start to the injection, default 25; the game must be in Manny's office), NOMOVIE (default 1)
# The engine side is in grim-decomp: GRIM_LUA_FILE (lines run as Lua, once, between frames), GRIM_DEBUGLOG (PrintDebug -> log, like
# grimdlg.dll), GRIM_SIMTIME (fixed frame time like patches/grim/simtime.py), GRIM_ACTIVE (no pause when unfocused), GRIM_NOMOVIE.
# Only kills the game it started (by pid), never the user's own copy.
AR=/c/Users/Joel/grim_tools/autorun
# GRIMDATA/autorun_all.lua, grimdebug.log and the saves are shared: one run at a time, others wait here
LOCK=/c/Users/Joel/grim_tools/autorun/logs/rebuilt.lock
while ! mkdir "$LOCK" 2>/dev/null; do
	# a lock of a run that died (older than 40 minutes) is taken over
	[ -n "$(find "$LOCK" -maxdepth 0 -mmin +40 2>/dev/null)" ] && rmdir "$LOCK" 2>/dev/null
	sleep 5
done
trap 'rmdir "$LOCK" 2>/dev/null' EXIT
GD="/c/GOG Games/GRIMDATA"
L="$GD/grimdebug.log"
# the hand-made test sets (tools/mk_set.py: t_flat, t_edge, ...; test_rules.lua and the turn tier of test_nav.lua) live in tests/sets/DATAUSR.LAB. The
# original ran with it installed in GRIMDATA; the install keeps it as DATAUSR.LAB.bak, so it is put there for the length of the run (we hold the lock)
if [ ! -e "$GD/DATAUSR.LAB" ] && [ -f "$AR/tests/sets/DATAUSR.LAB" ]; then
	cp "$AR/tests/sets/DATAUSR.LAB" "$GD/DATAUSR.LAB"
	trap 'rm -f "$GD/DATAUSR.LAB"; rmdir "$LOCK" 2>/dev/null' EXIT
fi
file="${1:-$AR/test_nav.lua}"
max="${2:-3000}"
copy="${3:-$AR/logs/rebuilt_test_last.log}"
EXE_DIR="${REBUILT_DIR:-/c/Users/Joel/grim-decomp/build/run}"
CMD="$(cygpath -w "$AR/logs/rebuilt_cmd.lua")"
: > "$AR/logs/rebuilt_cmd.lua"
: > "$L"
TESTFILE="$file" sh "$AR/build_original.sh" > /dev/null || { echo "build_original.sh failed"; exit 1; }
cd "$GD"
GRIM_MULTI=autorun GRIM_ACTIVE=1 GRIM_NOMOVIE="${NOMOVIE:-1}" GRIM_SIMTIME="${SIMTIME:-17}" GRIM_DEBUGLOG="$(cygpath -w "$L")" \
	GRIM_LUA_FILE="$CMD" GRIM_LUA_LOG="$(cygpath -w "$AR/logs/rebuilt_hook.log")" "$EXE_DIR/grimfandango.exe" > "$AR/logs/rebuilt_game.out" 2>&1 &
PID=$!
sleep "${REBUILT_DELAY:-25}"
# the injection: what grimpatch.bin does on the original (CRLF is not needed here)
printf '%s\n' 'PrintDebug("running autorun_all.lua")' >> "$AR/logs/rebuilt_cmd.lua"
printf '%s\n' 'dofile("autorun_all.lua")' >> "$AR/logs/rebuilt_cmd.lua"
i=0
until grep -aq "NAVTEST SUMMARY unit\|INJECTION FAILED\|AUTORUN RESULT" "$L" 2>/dev/null || [ $i -ge "$max" ]; do
	sleep 5; i=$((i + 5))
	kill -0 $PID 2>/dev/null || { echo "the game has gone"; break; }
done
cp "$L" "$copy"
kill $PID 2>/dev/null; taskkill //F //PID $PID > /dev/null 2>&1
# (the exit trap removes DATAUSR.LAB: the process must have let go of it)
wait $PID 2>/dev/null; sleep 2
echo "done after $i s, log in $copy"
