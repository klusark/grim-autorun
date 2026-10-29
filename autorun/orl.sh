#!/bin/sh
# Runs Lua in the running original game: the code goes to grimpatch.bin, F12 runs it, what it logged with
# PrintDebug("ORL ...") is printed. Usage: orl.sh 'lua code'   (or orl.sh -f file.lua)
AR=/c/Users/Joel/grim_tools/autorun
GD="/c/GOG Games/GRIMDATA"
L="$GD/grimdebug.log"
n=$(wc -l < "$L")
if [ "$1" = "-f" ]; then cp "$2" "$AR/_orl.lua"; else printf '%s\n' "$1" > "$AR/_orl.lua"; fi
python3 "$AR/mk_cmd.py" "$AR/_orl.lua"
/c/Users/Joel/grim_tools/crashdbg/postf12.exe > /dev/null
i=0
until tail -n +$((n+1)) "$L" | grep -a -q "ORL done"; do sleep 1; i=$((i+1)); [ $i -gt 20 ] && echo "(no answer)" && break; done
tail -n +$((n+1)) "$L" | grep -a "ORL" | grep -v "ORL done" | cut -c1-400
