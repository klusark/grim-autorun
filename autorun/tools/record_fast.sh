#!/bin/sh
# A video of a run in simulated time at the speed of the game, every frame once, made while the run goes faster than real time: the engine holds the run to
# WALLFPS pictures a second (default 240, so 4 times faster than the game) and writes the number of the frame along the bottom of each picture (frame_marker),
# OBS records the window at FPS (default 480, more than the run draws, so it sees every picture) with Game Capture, and fastvideo.py puts the recording back in
# order by the numbers: duplicates out, 60 frames a second. No sound.
#   record_fast.sh [name, default fastrun]    UPTO=<n> and the rest as for run_all.sh; CHAPTER=<file.lua> records one chapter from its save (run_chapter.sh)
#   WALLFPS=240 FPS=480 (keep FPS at twice WALLFPS: at 1.2 times a few frames were missed), VIDEOENC="-c:v libx264 -preset veryfast -crf 18" for the final encode
# The profile and the scene "grimfast" (tools/obs_fast/) are copied into OBS's folder; the profile and scenes of the user are not touched.
AR=/c/Users/Joel/grim_tools/autorun
OBS="/c/Program Files/obs-studio/bin/64bit"
CFG="$APPDATA/obs-studio"
name="${1:-fastrun}"
outdir="${RECDIR:-$AR/recordings}"
FPS="${FPS:-480}"; WALLFPS="${WALLFPS:-240}"
# (OBS saves its scenes when it ends: it must be gone before the files are put in place, or it writes its own over them)
taskkill //IM obs64.exe //F >/dev/null 2>&1
n=0; while tasklist 2>/dev/null | grep -q obs64.exe && [ $n -lt 20 ]; do sleep 1; n=$((n + 1)); done
rm -f "$CFG"/.sentinel/run_*   # (a killed OBS leaves a crash marker, and its next start would ask about it)
mkdir -p "$outdir" "$CFG/basic/profiles/grimfast" "$CFG/basic/scenes"
win_outdir=$(cygpath -m "$outdir")
sed "s|@NAME@|$name.cap|; s|@DIR@|$win_outdir|; s|@FPS@|$FPS|g" "$AR/tools/obs_fast/basic.ini" > "$CFG/basic/profiles/grimfast/basic.ini"
cp "$AR/tools/obs_fast/recordEncoder.json" "$CFG/basic/profiles/grimfast/recordEncoder.json"
cp "$AR/tools/obs_fast/grim.json" "$CFG/basic/scenes/grimfast.json"
sed -i 's/^ConfirmOnExit=.*/ConfirmOnExit=false/' "$CFG/user.ini"
rm -f "$outdir/$name.cap.mkv" "$outdir/$name.mp4"
# (started by Windows, detached: a child of this shell keeps the shell, and whatever waits for it, from finishing)
powershell -NoProfile -Command "Start-Process -FilePath '$(cygpath -w "$OBS/obs64.exe")' -WorkingDirectory '$(cygpath -w "$OBS")' -ArgumentList '--profile grimfast --collection grimfast --startrecording --disable-updater' -WindowStyle Minimized"
sleep 4
HOLDMS="${HOLDMS:-8000}"
export WALLFPS HOLDMS MARKER=1 RENDEREVERY=1 WIN=640x480 NOSCREEN=1 NOFPS=1 LOG="$name"
if [ -n "$CHAPTER" ]; then
	sh "$AR/run_chapter.sh" "$CHAPTER" "${LIMIT:-1800}"
else
	sh "$AR/run_all.sh" ${LIMIT:+"$LIMIT"}
fi
sleep 2
powershell -NoProfile -Command "Get-Process obs64 -ErrorAction SilentlyContinue | ForEach-Object { \$_.CloseMainWindow() | Out-Null }"
n=0; while tasklist 2>/dev/null | grep -q obs64.exe && [ $n -lt 60 ]; do sleep 1; n=$((n + 1)); done
ls -la "$outdir/$name.cap.mkv" || exit 1
python "$AR/tools/fastvideo.py" "$(cygpath -m "$outdir/$name.cap.mkv")" "$(cygpath -m "$outdir/$name.mp4")" $VIDEOENC
ls -la "$outdir/$name.mp4"
