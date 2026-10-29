#!/bin/sh
# Prints the chapter starts, the failures and the end of a ScummVM run_all.sh run (logs/all.log, logs/all_times.txt)
AR=/c/Users/Joel/grim_tools/autorun
tail -n 0 -F "$AR/logs/all_times.txt" "$AR/logs/all.log" 2>/dev/null | grep -a --line-buffered -E "=== chapter|AUTORUN FAIL|RESULT|scummvm exit"
