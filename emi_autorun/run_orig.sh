#!/bin/sh
# Runs an EMI autorun script on the ORIGINAL Monkey4.exe v1.1 (orig/: hard links to the GOG install's files), started through
# grimlaunch.exe (debuglog, datadir, nocd, simtime, nopause, f11, windowed). The script is built as run_emi.sh builds it, wrapped as
# ScummVM's --autorun wraps it (a task of its own), and put into orig/patch.m4b as grimpatch.bin (the original reads its Lua only from
# its archives); F11 (postkey.exe) runs it once the game is up (the only keys sent from outside: the run plays with the game's own). The game's PrintDebug lines go to orig/grimdebug.log, copied to
# logs/<name>.log. NOLOG real seconds without a new AUTORUN line: stuck, stopped. Only this folder's Monkey4.exe is ever stopped.
#   run_orig.sh <script.lua> [timeout seconds]
EM=/c/Users/Joel/grim_tools/emi_autorun
AR=/c/Users/Joel/grim_tools/autorun
OD="$EM/${ORIGDIR:-orig}"
script="$1"; limit="${2:-600}"
name=$(basename "$script" .lua)
EXTRA=${EXTRA-emi_poke.lua emi_myst.lua}
gen="$EM/generated/orig_${name}.lua"
python "$EM/emi_nav_gen.py" "$EM/generated/emi_nav_planner_orig.lua" || exit 1
{
	[ -n "$WALKTRACE" ] && echo "AR_WALK_TRACE = TRUE"
	echo "AR_CHAPTER = \"$name\""
	# (STAGE lines: the original prints no traceback for a Lua error, only the message; they also cut the run into parts)
	for f in "$EM/emi_prelude.lua" "${ARLIB:-$AR/ar_lib.lua}" "$EM/emi_floors.lua" "$EM/emi_floors_fn.lua" "$EM/generated/emi_nav_planner_orig.lua" "$EM/emi_nav_data.lua" "$EM/emi_nav.lua" "$EM/emi_lib.lua"; do
		echo "PrintDebug(\"STAGE $(basename $f)\")"; cat "$f"; echo
	done
	for e in $EXTRA; do echo "PrintDebug(\"STAGE $e\")"; cat "$EM/$e"; echo; done
	echo "PrintDebug(\"STAGE $name\")"
} > "$gen.head"
python "$EM/orig_parts.py" "$gen.head" "$script" > "$gen" || exit 1
mine() {
	# (the Monkey4.exe started from this run folder, by its path)
	powershell -NoProfile -Command "Get-CimInstance Win32_Process -Filter \"Name='Monkey4.exe'\" | Where-Object { \$_.ExecutablePath -eq '$(cygpath -w "$OD")\Monkey4.exe' } | ForEach-Object { \$_.ProcessId }" | tr -d '
'
}
for p in $(mine); do taskkill //F //PID $p > /dev/null 2>&1; done
sleep 1
ORIG_M4B="$(cygpath -w "$OD/patch.m4b")" python "$EM/orig_patch_m4b.py" "grimpatch.bin=$gen" > /dev/null || exit 1

for p in $(mine); do taskkill //F //PID $p > /dev/null 2>&1; done
log="$EM/logs/${LOG:-$name}.log"
cd "$OD" || exit 1
: > grimdebug.log
start=$(date +%s)
# (Direct3D by default, flat out at simtime's 17 ms a frame: it draws only the 2D (text, the inventory, the compass and clock, movies),
# the scene stays black. GL=1 for OpenGL, which draws the scene but waits for the screen's refresh (about real time at 17 ms) and on
# Nov 11 stopped every Lua script twice: at act2_13's inventory combine (17 ms) and after loading a checkpoint (50 ms). SIMTIME=n ms)
./grimlaunch.exe --simtime-ms ${SIMTIME:-17} Monkey4.exe ${GL:+-gl} > launch.out 2>&1 &
# (the game is up when its first set has loaded: the boot set cdt prints a line)
t=0
while [ $t -lt 120 ] && ! grep -a -q "Purged props\|default footsteps" grimdebug.log; do sleep 1; t=$((t + 1)); done
sleep 2
"$EM/../crashdbg/postkey.exe" pid:$(mine | head -1) > /dev/null
# (a resume: the first F11 loaded the save; once a set other than the boot one shows in the clock lines, F11 again)
if [ -n "$RESUME" ]; then
	t=0
	while [ $t -lt 1200 ] && ! grep -a "^CLOCK" grimdebug.log | grep -a -v " cdt.$\| cdt$" | grep -a -q .; do sleep 0.1; t=$((t + 1)); done
	"$EM/../crashdbg/postkey.exe" pid:$(mine | head -1) > /dev/null
fi
nolog=${NOLOG:-30}
last=-1; quiet=0
while [ -n "$(mine)" ]; do
	sleep 1
	now=$(date +%s)
	cur=$(grep -a "AUTORUN" grimdebug.log | grep -a -v "Starting wait\|Waited" | sort -u | wc -l)
	if [ "$cur" != "$last" ]; then last=$cur; quiet=0; else quiet=$((quiet + 1)); fi
	if [ $quiet -ge $nolog ]; then echo "NOLOG: no progress line for $nolog s, stopping" >> grimdebug.log; break; fi
	if [ $((now - start)) -ge $limit ]; then echo "TIMEOUT: $limit s, stopping" >> grimdebug.log; break; fi
	grep -a -q "AUTORUN RESULT" grimdebug.log && sleep 3 && break
done
for p in $(mine); do taskkill //F //PID $p > /dev/null 2>&1; done
echo "original exit after $(( $(date +%s) - start )) s" >> grimdebug.log
cp grimdebug.log "$log"
grep -a -E 'AUTORUN|rror|NOLOG|TIMEOUT|original exit' "$log" | grep -a -v 'Starting wait\|Waited' | tail -${TAIL:-40}
