#!/bin/sh
# Starts the ORIGINAL game, loads a checkpoint save and (with a chapter prefix) runs the autorun from that
# chapter on. Usage: resume_original.sh <slot> [chapter prefix]. With no chapter the autorun that the save
# holds in its Lua state goes on by itself (this is how a crash is recovered from).
AR=/c/Users/Joel/grim_tools/autorun
GD="/c/GOG Games/GRIMDATA"
L="$GD/grimdebug.log"
slot=$1
[ -n "$2" ] && sh "$AR/build_original.sh" "$2" > /dev/null
taskkill //F //IM GRIMFANDANGO.exe 2>/dev/null
powershell -NoProfile -Command "Remove-Item 'HKCU:\Software\Classes\VirtualStore\MACHINE\SOFTWARE\WOW6432Node\LucasArts Entertainment Company LLC' -Recurse -Force -ErrorAction SilentlyContinue"
: > "$L"
cd /c/Users/Joel/grim_tools/crashdbg
export GRIM_FPS="${GRIM_FPS:-60}"
(${GRIMRUN:-./grimrun2.exe} "C:\GOG Games\GRIMDATA\GRIMFANDANGO.exe" "C:\GOG Games\GRIMDATA" "GRIMFANDANGO.exe -w" 99999 > /tmp/run_orig.out 2>&1 &)
# (the game is up when its first set is entered, and the remote Lua answers a second later; at most 30 s)
i=0
until grep -aq "Switching to set" "$L" 2>/dev/null || [ $i -ge 120 ]; do sleep 0.25; i=$((i+1)); done
sleep 1
sh "$AR/orl.sh" "if system.override and system.override.is_active then call_override() end PrintDebug(\"ORL skipped\")" | tail -1
sleep 3
sh "$AR/orl.sh" "Load(format(\"grim%02d.gsv\", $slot)) PrintDebug(\"ORL loading\")" | tail -1
# the autorun the save holds goes on by itself and logs that it has saved: that is the moment the game is back
# The save's autorun waits 1.5 s after the load (ar_checkpoint) before it goes on: the chapter is injected as soon as the
# load has reloaded the scripts ("Won't reload service_release.lua"), which is when the old autorun is still asleep. A
# save that was made without that sleep (an older one) has an autorun that plays on at once and races the new one.
n=$(wc -l < "$L")
i=0
# (a save of an early part of the game does not print that line: then 0.4 s, the autorun of the save wakes up 1.5 s after the load)
until tail -n +$n "$L" | grep -aq "Won't reload service_release.lua" || [ $i -ge 8 ]; do sleep 0.05; i=$((i+1)); done
if [ -n "$2" ]; then
	python3 "$AR/mk_grimpatch.py"
	./postf12.exe > /dev/null
fi
# an error in the injected code (a parse error, too many locals) is silent otherwise: the save's old autorun goes on
sleep 3
if grep -a -A2 "running autorun_all.lua" "$L" | grep -aq "Error"; then echo "INJECTION FAILED:"; grep -a -A2 "running autorun_all.lua" "$L" | tail -3; fi
