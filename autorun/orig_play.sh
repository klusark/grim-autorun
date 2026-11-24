#!/bin/sh
# Starts the ORIGINAL game for a player, with no autorun: the clean v1.01 exe in the run folder of orig_launch_run.sh (autorun/origlaunch, where a
# MANUALSAVES=1 run keeps its checkpoint saves grimNN.gsv), through grimlaunch, windowed, in real time at 60 frames a second (framelimit, no
# simtime), with ScummVM's script patches (orig_patchlab.sh). Load a save from the game's menu: the autorun that a MANUALSAVES save holds stops
# itself after the load and the game is yours. The patch lab is taken out of GRIMDATA when the game is closed, so keep this script running.
#   sh orig_play.sh
AR=/c/Users/Joel/grim_tools/autorun
RUN="$AR/origlaunch"
tasklist | grep -qi GRIMFANDANGO && { echo "a GRIMFANDANGO.exe is running, not starting"; exit 1; }
[ -f "$RUN/GRIMFANDANGO.exe" ] && [ -f "$RUN/grimlaunch.exe" ] && [ -f "$RUN/grim.ini" ] || { echo "no run folder yet: play one run with orig_launch_run.sh first"; exit 1; }
# (grim.tab, the game's text: the exe reads it from its own folder, and without it no text is drawn, the menus blank)
[ -f "$RUN/GRIM.TAB" ] || cp "/c/GOG Games/GRIMDATA/GRIM.TAB" "$RUN/GRIM.TAB"
. "$AR/orig_patchlab.sh"
patchlab_install
trap 'patchlab_remove' EXIT
cd "$RUN"
GRIM_INI="$(cygpath -w "$RUN/grim.ini")" ./grimlaunch.exe --with framelimit --skip simtime GRIMFANDANGO.exe > "$AR/logs/orig_play.out" 2>&1
# (grimlaunch may return before the game ends)
while tasklist | grep -qi GRIMFANDANGO; do sleep 5; done
echo "the game has closed"
