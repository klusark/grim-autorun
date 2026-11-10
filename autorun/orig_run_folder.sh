#!/bin/sh
# Runs a test file on the ORIGINAL from a run folder of its own (autorun/origrun), not from the install: the install's DLLs with
# the patched exe of gfupd/v101_fl.exe (debuglog, TextAllowed, Backspace, no pause when unfocused, 60 fps limit). The game's data
# still come from GRIMDATA (GrimDataDir in the registry); nothing in GRIMDATA is changed except the autorun_all.lua and
# grimpatch.bin that build_original.sh writes there (copied to the run folder, which is the game's working folder).
#   orig_run_folder.sh <test file> [max seconds] [log copy]
# GRIMRUN / GRIMTRACE_* as for orig_test.sh; the tracer is told where the game's log is (GRIMTRACE_GAMELOG).
AR=/c/Users/Joel/grim_tools/autorun
GD="/c/GOG Games/GRIMDATA"
RUN="$AR/origrun"
file="$1"; max="${2:-1400}"; copy="${3:-$AR/logs/orig_run_last.log}"
tasklist | grep -qi GRIMFANDANGO && { echo "a GRIMFANDANGO.exe is running, not starting"; exit 1; }
mkdir -p "$RUN"
for f in LUA.DLL IMUSE.DLL CHORE.DLL NULLMUSE.DLL HMIFXFP.DLL HMIFXLIB.DLL HMILIBS.INI IMUSE.PSL grimdlg.dll; do
	[ -f "$RUN/$f" ] || cp "$GD/$f" "$RUN/$f"
done
cp /c/Users/Joel/grim_tools/gfupd/v101_fl.exe "$RUN/GRIMFANDANGO.exe"
TESTFILE="$file" sh "$AR/build_original.sh" > /dev/null
cp "$GD/autorun_all.lua" "$GD/grimpatch.bin" "$RUN/"
L="$RUN/grimdebug.log"
: > "$L"
# (good_times boots into GrimLastSet of the virtual store: removed so that the run starts the new game in Manny's office)
powershell -NoProfile -Command "Remove-Item 'HKCU:\Software\Classes\VirtualStore\MACHINE\SOFTWARE\WOW6432Node\LucasArts Entertainment Company LLC' -Recurse -Force -ErrorAction SilentlyContinue"
cd /c/Users/Joel/grim_tools/crashdbg
export GRIM_FPS="${GRIM_FPS:-60}" GRIMTRACE_GAMELOG="$(cygpath -m "$L")"
${GRIMRUN:-./grimrun2.exe} "$(cygpath -w "$RUN/GRIMFANDANGO.exe")" "$(cygpath -w "$RUN")" "GRIMFANDANGO.exe -w" 20 > "$AR/logs/orig_run_folder.out" 2>&1 &
i=0
until grep -aq "running autorun_all.lua" "$L" 2>/dev/null; do sleep 3; i=$((i + 3)); [ $i -ge 150 ] && break; done
until grep -aq "NAVTEST SUMMARY unit\|INJECTION FAILED\|AUTORUN RESULT" "$L" 2>/dev/null || [ $i -ge "$max" ]; do
	sleep 5; i=$((i + 5))
	tasklist | grep -qi GRIMFANDANGO || { echo "the game has gone"; break; }
done
cp "$L" "$copy"
taskkill //F //IM GRIMFANDANGO.exe > /dev/null 2>&1
echo "done after $i s, log in $copy"
