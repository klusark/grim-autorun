#!/bin/sh
# Plays the whole game under ScummVM in real time (60 simulated frames a second, no speed up), in a 640x480 window with
# no fps counter and no progress text, and records the window to videos/scummvm_full.mp4.
# The window is put on top at a fixed place and the screen region under it is recorded (the OpenGL window cannot be
# recorded by its title). The mp4 is written in fragments, so that it plays even though ffmpeg is killed at the end.
AR=/c/Users/Joel/grim_tools/autorun
OUT="$AR/videos/scummvm_full.mp4"
mkdir -p "$AR/videos"
taskkill //F //IM scummvm.exe >/dev/null 2>&1
rm -f /tmp/w/runall.out
(MSYSTEM=UCRT64 ES=60 SIMFPS=60 WIN=640x480 NOFPS=1 NOSCREEN=1 /c/msys64/usr/bin/bash.exe -l -c "cd $AR && ./run_all.sh 14000 --sim-render-every=1" > /tmp/w/runall.out 2>&1; echo FINISHED >> /tmp/w/runall.out) &
geom=""
n=0
while [ -z "$geom" ] && [ $n -lt 90 ]; do
	sleep 1
	n=$((n + 1))
	geom=$(powershell -NoProfile -ExecutionPolicy Bypass -File "$(cygpath -w $AR/placewin.ps1)" scummvm 40 40 2>/dev/null | tr -d '\r' | grep -E '^[0-9]+ [0-9]+ [0-9]+ [0-9]+$')
done
echo "window client: $geom" > /tmp/w/record.out
set -- $geom
ffmpeg -y -v error -f gdigrab -framerate 60 -offset_x $1 -offset_y $2 -video_size ${3}x${4} -i desktop -c:v libx264 -preset veryfast -crf 26 -pix_fmt yuv420p -movflags frag_keyframe+empty_moov+default_base_moof "$OUT" 2>> /tmp/w/record.out &
FF=$!
until grep -q FINISHED /tmp/w/runall.out 2>/dev/null; do sleep 5; done
sleep 3
taskkill //F //IM ffmpeg.exe >/dev/null 2>&1
echo "recording done" >> /tmp/w/record.out
