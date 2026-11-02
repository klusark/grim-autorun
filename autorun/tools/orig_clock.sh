#!/bin/sh
# Which clock the ORIGINAL runs on: sh tools/orig_clock.sh simtime | realtime     (the game must not be running)
#   simtime:  every frame is a frame of 17 ms (tools patches/grim/simtime.py), the machine's speed does not matter; GRIM_FPS=1000 runs it uncapped
#   realtime: the exe as it was (frame times of the wall clock)
G="/c/GOG Games/GRIMDATA"
tasklist | grep -qi GRIMFANDANGO && { echo "the game is running"; exit 1; }
case "$1" in
	simtime) cp "$G/GRIMFANDANGO.exe.simtime" "$G/GRIMFANDANGO.exe" ;;
	realtime) cp "$G/GRIMFANDANGO.exe.realtime" "$G/GRIMFANDANGO.exe" ;;
	*) echo "simtime | realtime"; exit 1 ;;
esac
cmp -s "$G/GRIMFANDANGO.exe" "$G/GRIMFANDANGO.exe.$1" && echo "the original now runs on: $1"
