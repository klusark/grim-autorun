#!/bin/sh
# Runs a test file on the ORIGINAL, waits for its summary (or the timeout) and CLOSES the game: orig_test.sh <test file | "test"> [max seconds] [log copy]
# (a plain resume_original.sh leaves the game open; this is the way for the tests). The log of the run is copied to the third argument.
AR=/c/Users/Joel/grim_tools/autorun
L="/c/GOG Games/GRIMDATA/grimdebug.log"
file="${1:-$AR/test_nav.lua}"
max="${2:-3000}"
copy="${3:-$AR/logs/orig_test_last.log}"
taskkill //F //IM GRIMFANDANGO.exe > /dev/null 2>&1
# (the log of the run before must not be taken for this one)
: > "$L"
# (a new game, no save: the intro is skipped by the autorun, F12 is sent ORIG_F12 seconds after the start; LOADSLOT=<n> keeps the old way, from a save)
if [ -n "$LOADSLOT" ]; then
	GRIMRUN="$GRIMRUN" GRIMTRACE_BP="$GRIMTRACE_BP" TESTFILE="$file" MSYSTEM=UCRT64 /c/msys64/usr/bin/bash.exe -l -c "cd $AR && sh resume_original.sh $LOADSLOT test" > "$AR/logs/orig_test.out" 2>&1 &
else
	GRIMRUN="$GRIMRUN" GRIMTRACE_BP="$GRIMTRACE_BP" TESTFILE="$file" MSYSTEM=UCRT64 /c/msys64/usr/bin/bash.exe -l -c "cd $AR && sh run_original.sh ${ORIG_F12:-2}" > "$AR/logs/orig_test.out" 2>&1 &
fi
# (which window has the focus every 5 s, next to the log of the run: a stall can be matched with the game in the background)
powershell -NoProfile -ExecutionPolicy Bypass -File "$AR/tools/focus_log.ps1" "$(cygpath -w "$copy").focus" 5 > /dev/null 2>&1 &
FOCUS_PID=$!
i=0
# (the log is emptied when the game starts: wait for the new one to have the injection before looking for the end)
until grep -aq "running autorun_all.lua" "$L" 2>/dev/null; do sleep 3; i=$((i + 3)); [ $i -ge 120 ] && break; done
until grep -aq "NAVTEST SUMMARY unit\|INJECTION FAILED\|AUTORUN RESULT" "$L" 2>/dev/null || [ $i -ge "$max" ]; do
	sleep 5; i=$((i + 5))
	tasklist | grep -qi GRIMFANDANGO || { echo "the game has gone"; break; }
done
cp "$L" "$copy"
[ -n "$FOCUS_PID" ] && kill "$FOCUS_PID" 2>/dev/null
taskkill //F //IM GRIMFANDANGO.exe > /dev/null 2>&1
echo "done after $i s, log in $copy"
