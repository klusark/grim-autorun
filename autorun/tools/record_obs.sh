#!/bin/sh
# Plays the whole game in real time in a 1440x1080 window (4:3, the shape of the game) and records it with OBS: the window by Windows Graphics Capture,
# the sound of scummvm.exe alone (application audio capture), 60 frames a second, NVENC, to recordings/<name>.mkv. The profile and the scene collection
# "grim" (tools/obs/) are copied into OBS's folder at the start; the profile and scenes of the user are not touched.
#   record_obs.sh [name, default fullrun]       MODE (default full: nothing skipped, voices on), LIMIT=<seconds>, UPTO=<n> as for run_all.sh. Real time with the real clock (a SIMMS=16
#   frame step makes the engine simulate the sound too, and nothing is heard)
# OBS asks nothing when it is closed (ConfirmOnExit is turned off in user.ini).
AR=/c/Users/Joel/grim_tools/autorun
OBS="/c/Program Files/obs-studio/bin/64bit"
CFG="$APPDATA/obs-studio"
name="${1:-fullrun}"
outdir="${RECDIR:-$AR/recordings}"
# (OBS saves its scenes when it ends: it must be gone before the files are put in place, and a killed OBS leaves a crash marker that makes its next start ask)
taskkill //IM obs64.exe //F >/dev/null 2>&1
n=0; while tasklist 2>/dev/null | grep -q obs64.exe && [ $n -lt 20 ]; do sleep 1; n=$((n + 1)); done
rm -f "$CFG"/.sentinel/run_*
mkdir -p "$outdir" "$CFG/basic/profiles/grim" "$CFG/basic/scenes"
win_outdir=$(cygpath -m "$outdir")
sed "s|@NAME@|$name|; s|@DIR@|$win_outdir|" "$AR/tools/obs/basic.ini" > "$CFG/basic/profiles/grim/basic.ini"
cp "$AR/tools/obs/recordEncoder.json" "$CFG/basic/profiles/grim/recordEncoder.json"
cp "$AR/tools/obs/grim.json" "$CFG/basic/scenes/grim.json"
sed -i 's/^ConfirmOnExit=.*/ConfirmOnExit=false/' "$CFG/user.ini"
rm -f "$outdir/$name.mkv"
# OBS first (it records from its start, the window is taken as soon as there is one), then the game. OBS is started by Windows, detached: a child of this shell keeps
# the shell, and whatever waits for it, from finishing.
powershell -NoProfile -Command "Start-Process -FilePath '$(cygpath -w "$OBS/obs64.exe")' -WorkingDirectory '$(cygpath -w "$OBS")' -ArgumentList '--profile grim --collection grim --startrecording --disable-updater' -WindowStyle Minimized"
sleep 5
MODE="${MODE:-full}" REALTIME=1 WIN=640x480 NOSCREEN=1 NOFPS=1 LOG="$name" STALL="${STALL:-0}" sh "$AR/run_all.sh" ${LIMIT:+"$LIMIT"}
sleep 3
# (taskkill does not reach the window of OBS when it sits in the tray: CloseMainWindow does) closing OBS stops and finishes the recording
powershell -NoProfile -Command "Get-Process obs64 -ErrorAction SilentlyContinue | ForEach-Object { \$_.CloseMainWindow() | Out-Null }"
n=0; while tasklist 2>/dev/null | grep -q obs64.exe && [ $n -lt 60 ]; do sleep 1; n=$((n + 1)); done
ls -la "$outdir/$name.mkv"
