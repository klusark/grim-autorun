#!/bin/sh
# Runs the autorun from a chapter on in the ALREADY RUNNING original game (no restart): inject_original.sh <chapter prefix>
AR=/c/Users/Joel/grim_tools/autorun
sh "$AR/build_original.sh" "$1" > /dev/null
/c/Users/Joel/grim_tools/crashdbg/postf12.exe
