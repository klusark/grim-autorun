#!/bin/sh
# Plays the autorun on the ORIGINAL exe through grimlaunch (not a patched exe, no debugger): the clean GRIMFANDANGO.exe of the
# install, in a run folder of its own (autorun/origlaunch), started with grimlaunch's f12 (F12 alone runs grimpatch.bin), nopause,
# multi, smushtime and imusetime patches (simtime, debuglog, config and windowed are on by default), on a desktop of its own
# (cleanroom/run/offscreen.exe) unless VISIBLE=1. The game's data come from GRIMDATA (GrimDataDir of the run folder's grim.ini);
# nothing in GRIMDATA is written. build_original.sh writes autorun_all.lua and grimpatch.bin into the run folder, which is the
# game's working folder; F12 is posted to the game's windows until the log says the script runs.
#   orig_launch_run.sh [max seconds, default 1800] [log copy, default logs/orig_launch_last.log]
# build_original.sh's variables pass through (UPTO, NOSAVE, SKIPMS, TRICKS, BLAMLEARN, MODE, ...); NOSAVE defaults to 1.
AR=/c/Users/Joel/grim_tools/autorun
GD="/c/GOG Games/GRIMDATA"
RUN="$AR/origlaunch"
OFF=/c/Users/Joel/grim_tools/cleanroom/run/offscreen.exe
POST=/c/Users/Joel/grim_tools/crashdbg/postkey.exe
max="${1:-1800}"; copy="$(realpath -m "${2:-$AR/logs/orig_launch_last.log}")"
# (the game of a run that just ended can take a few seconds to go)
w=0; while tasklist | grep -qi GRIMFANDANGO && [ $w -lt 30 ]; do sleep 2; w=$((w + 2)); done
tasklist | grep -qi GRIMFANDANGO && { echo "a GRIMFANDANGO.exe is running, not starting"; exit 1; }
mkdir -p "$RUN" "$AR/logs"
for f in GRIMFANDANGO.exe LUA.DLL IMUSE.DLL CHORE.DLL NULLMUSE.DLL HMIFXFP.DLL HMIFXLIB.DLL HMILIBS.INI IMUSE.PSL grimdlg.dll; do
	[ -f "$RUN/$f" ] || cp "$GD/$f" "$RUN/$f"
done
cmp -s "$RUN/GRIMFANDANGO.exe" /c/Users/Joel/grim_tools/gfupd/v101_clean.exe || { echo "the run folder's exe is not the clean v1.01"; exit 1; }
# (grimlaunch and patch.dll built from launcher/ when older than its sources)
L=/c/Users/Joel/grim_tools/launcher
[ "$RUN/grimlaunch.exe" -nt "$L/grimlaunch.cpp" ] || g++ -O2 -static -o "$RUN/grimlaunch.exe" "$L/grimlaunch.cpp" || exit 1
[ "$RUN/patch.dll" -nt "$L/patch.c" ] && [ "$RUN/patch.dll" -nt "$L/config.c" ] || \
	PATH=/c/msys64/mingw32/bin:$PATH i686-w64-mingw32-gcc -shared -O2 -static-libgcc -o "$RUN/patch.dll" "$L/patch.c" "$L/config.c" -luser32 -lgdi32 -lwinmm || exit 1
# (a new game: a fresh grim.ini each run, no GrimLastSet to boot into)
printf '[Grim]\r\nGrimDataDir=C:\\GOG Games\\GRIMDATA\\\r\ngood_times=TRUE\r\nTextAllowed=true\r\nExperimentalDisplay=0\r\nLast3DDevice=hex:00000000000000000000000000000000\r\nLastDisplayDevice=hex:009fa692fa13d11197c000a024293005\r\n' > "$RUN/grim.ini"
ONCE=1 NOSAVE="${NOSAVE-1}" OUTDIR="$RUN" sh "$AR/build_original.sh" > /dev/null || exit 1
G="$RUN/grimdebug.log"
: > "$G"
cd "$RUN"
if [ -n "$VISIBLE" ]; then
	GRIM_INI="$(cygpath -w "$RUN/grim.ini")" ./grimlaunch.exe --with f12,nopause,multi,smushtime,imusetime GRIMFANDANGO.exe > "$AR/logs/orig_launch.out" 2>&1 &
	post() { "$POST" GRIMFANDANGO.exe 7b > /dev/null 2>&1; }
else
	GRIM_INI="$(cygpath -w "$RUN/grim.ini")" "$OFF" ./grimlaunch.exe --with f12,nopause,multi,smushtime,imusetime GRIMFANDANGO.exe > "$AR/logs/orig_launch.out" 2>&1 &
	# (postkey on the same desktop: EnumWindows sees only the windows of its own desktop)
	post() { "$OFF" "$POST" GRIMFANDANGO.exe 7b > /dev/null 2>&1; }
fi
i=0
sleep 15
until grep -aq "running autorun_all.lua" "$G" 2>/dev/null; do
	post; sleep 10; i=$((i + 10))
	[ $i -ge 150 ] && { echo "the script did not start"; break; }
	tasklist | grep -qi GRIMFANDANGO || { echo "the game has gone before the script started"; break; }
done
last=$(wc -c < "$G"); still=0
until grep -aq "AUTORUN RESULT\|AUTORUN FAILED\|frames: [0-9]" "$G" 2>/dev/null || [ $i -ge "$max" ]; do
	sleep 5; i=$((i + 5))
	tasklist | grep -qi GRIMFANDANGO || { echo "the game has gone"; break; }
	now=$(wc -c < "$G")
	if [ "$now" = "$last" ]; then still=$((still + 5)); else still=0; last=$now; fi
	[ $still -ge "${STALL:-120}" ] && { echo "no new log line for $still s"; break; }
done
cp "$G" "$copy"
taskkill //F //IM GRIMFANDANGO.exe > /dev/null 2>&1
w=0; while tasklist | grep -qi GRIMFANDANGO && [ $w -lt 30 ]; do sleep 2; w=$((w + 2)); done
echo "done after $i s, log in $copy"
