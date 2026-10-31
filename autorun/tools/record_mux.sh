#!/bin/sh
# Puts the video of record_window.ps1 and the audio that ScummVM wrote with SDL_AUDIODRIVER=disk (raw signed 16 bit stereo, 44100 Hz, SDL_DISKAUDIOFILE) together.
#   record_mux.sh <video.mkv> <audio.raw> <out.mp4>
# The video started at the time in <video.mkv>.start (ms); the audio file starts when ScummVM opens its audio device, its creation time is taken for that.
v="$1"; a="$2"; out="$3"
vs=$(cat "$v.start")
as=$(( $(stat -c %W "$a") * 1000 ))
off=$(( as - vs ))
echo "audio starts $off ms after the video"
if [ $off -ge 0 ]; then
	ffmpeg -hide_banner -y -i "$v" -itsoffset "$(echo "$off" | awk '{printf "%.3f", $1/1000}')" -f s16le -ar 44100 -ac 2 -i "$a" -map 0:v -map 1:a -c:v copy -c:a aac -b:a 256k -shortest "$out"
else
	ffmpeg -hide_banner -y -i "$v" -ss "$(echo "$off" | awk '{printf "%.3f", -$1/1000}')" -f s16le -ar 44100 -ac 2 -i "$a" -map 0:v -map 1:a -c:v copy -c:a aac -b:a 256k -shortest "$out"
fi
