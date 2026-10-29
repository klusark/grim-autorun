#!/bin/sh
# Plays the whole game on the ORIGINAL exe (see PROGRESS.md): builds the script, starts the game under
# grimrun (a debugger that keeps the exe's software-blitter heap overrun from crashing it and presses F12
# once the game is up) and leaves the AUTORUN lines in GRIMDATA/grimdebug.log.
AR=/c/Users/Joel/grim_tools/autorun
[ -z "$NOBUILD" ] && sh "$AR/build_original.sh" > /dev/null
taskkill //F //IM GRIMFANDANGO.exe 2>/dev/null
# the game saves GrimLastSet etc. into the user's registry virtual store and, with good_times set, boots
# into that set: remove it so that every run starts the new game in Manny's office
powershell -NoProfile -Command "Remove-Item 'HKCU:\Software\Classes\VirtualStore\MACHINE\SOFTWARE\WOW6432Node\LucasArts Entertainment Company LLC' -Recurse -Force -ErrorAction SilentlyContinue"
: > "/c/GOG Games/GRIMDATA/grimdebug.log"
cd /c/Users/Joel/grim_tools/crashdbg
export GRIM_FPS="${GRIM_FPS:-60}"
${GRIMRUN:-./grimrun2.exe} "C:\GOG Games\GRIMDATA\GRIMFANDANGO.exe" "C:\GOG Games\GRIMDATA" "GRIMFANDANGO.exe -w" ${1:-20}
