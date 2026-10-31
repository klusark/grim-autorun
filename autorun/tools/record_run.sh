#!/bin/sh
# Plays the whole game in real time, in a 1920x1080 window, and records it: the picture at 60 frames a second (record_window.ps1, h264_nvenc) and the sound
# from the loopback device of the sound card (AUDIO, default "Stereo Mix (ASUS Xonar Essence STX Audio Device)": what the card plays; the sound is heard
# while it records), both by one ffmpeg in one clock. AUDIO=disk takes the sound from ScummVM's disk audio driver instead, put together afterwards (record_mux.sh).
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
AUDIO="${AUDIO:-Stereo Mix (ASUS Xonar Essence STX Audio Device)}"
if [ "$AUDIO" = disk ]; then
	powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(cygpath -w "$AR/tools/record_window.ps1")" "$(cygpath -w "$video")" -Qp "$qp" > "$outdir/$name.rec.log" 2>&1 &
	export SDL_AUDIODRIVER=disk
	export SDL_DISKAUDIOFILE="$(cygpath -w "$audio")"
else
	powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(cygpath -w "$AR/tools/record_window.ps1")" "$(cygpath -w "$video")" -Qp "$qp" -Audio "$AUDIO" > "$outdir/$name.rec.log" 2>&1 &
fi
recpid=$!
MODE="${MODE:-full}" REALTIME=1 WIN=1920x1080 NOSCREEN=1 NOFPS=1 LOG="$name" sh "$AR/run_all.sh" ${LIMIT:+"$LIMIT"}
wait $recpid
if [ "$AUDIO" = disk ]; then
	sh "$AR/tools/record_mux.sh" "$video" "$audio" "$outdir/$name.mp4"
else
	ffmpeg -hide_banner -y -i "$video" -c copy -movflags +faststart "$outdir/$name.mp4"
fi
