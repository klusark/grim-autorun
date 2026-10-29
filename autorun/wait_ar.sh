#!/bin/sh
# Waits (at most $2 seconds) for a new line of the original's log that matches the grep pattern $1, then prints the status
L="/c/GOG Games/GRIMDATA/grimdebug.log"
n=$(wc -l < "$L")
end=$(( $(date +%s) + ${2:-200} ))
until tail -n +$((n+1)) "$L" | grep -aq "$1" || [ $(date +%s) -gt $end ]; do sleep 3; done
sh /c/Users/Joel/grim_tools/autorun/orig_status.sh
