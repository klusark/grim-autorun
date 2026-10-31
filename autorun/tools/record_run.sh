#!/bin/sh
# Plays the whole game in real time, in a 1920x1080 window, and records it: the picture at 60 frames a second (record_window.ps1, h264_nvenc), the sound from
# ScummVM's disk audio driver, then put together (record_mux.sh).
#   record_run.sh [name, default fullrun] [qp, default 20: 10 is near lossless and a run of hours would take hundreds of GB]
# No time limit and no stall watch (REALTIME=1): it goes on until it ends or is killed; LIMIT=<seconds> and STALL=<seconds> bring them back.
# Mode MODE (default full: nothing skipped, voices on). Leave the machine alone while it records: the window is on top and the picture is the screen.
AR=/c/Users/Joel/grim_tools/autorun
name="${1:-fullrun}"
qp="${2:-20}"
outdir="${RECDIR:-$AR/recordings}"
mkdir -p "$outdir"
video="$outdir/$name.mkv"
audio="$outdir/$name.raw"
rm -f "$video" "$video.start" "$audio"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(cygpath -w "$AR/tools/record_window.ps1")" "$(cygpath -w "$video")" -Qp "$qp" > "$outdir/$name.rec.log" 2>&1 &
recpid=$!
export SDL_AUDIODRIVER=disk
export SDL_DISKAUDIOFILE="$(cygpath -w "$audio")"
MODE="${MODE:-full}" REALTIME=1 WIN=1920x1080 NOSCREEN=1 NOFPS=1 LOG="$name" sh "$AR/run_all.sh" ${LIMIT:+"$LIMIT"}
wait $recpid
sh "$AR/tools/record_mux.sh" "$video" "$audio" "$outdir/$name.mp4"
