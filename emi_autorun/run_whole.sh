#!/bin/sh
# The whole game, start to finish, with one command. It is run_single.sh (one process, all four acts, the credits at the end); when a chapter
# fails (the engine, the random puzzles and some waits are flaky) the run is started again from the checkpoint before that chapter (the Lua state
# and the game state come back with the save), up to TRIES times for the same chapter. Logs: logs/whole_N.log, summary logs/whole.txt.
EM=/c/Users/Joel/grim_tools/emi_autorun
TRIES=${TRIES:-5}
cd "$EM" || exit 1
: > logs/whole.txt
n=0; same=0; lastfile=""; resume=""
while [ $n -lt 30 ]; do
	n=$((n + 1))
	LOGNAME_OVERRIDE=whole_$n RESUME="$resume" ./run_single.sh ${1:-20000} > /dev/null 2>&1
	log=logs/whole_$n.log
	if grep -aq "THE WHOLE GAME DONE" $log && grep -aq "RESULT PASSED" $log; then
		echo "attempt $n: THE WHOLE GAME DONE" >> logs/whole.txt; echo "THE WHOLE GAME DONE"; exit 0
	fi
	if grep -aq "failed to load" $log; then echo "the script does not load: $(grep -a "Error:" $log | head -1)"; echo "attempt $n: the script does not load" >> logs/whole.txt; exit 2; fi
	file=$(grep -a "AUTORUN === file " $log | tail -1 | sed 's/.*=== file \(.*\) ===.*/\1/')
	slot=$(grep -a "AUTORUN saved checkpoint grim" $log | tail -1 | sed 's/.*grim\([0-9]*\)\.gsv.*/\1/')
	echo "attempt $n failed in $file (last checkpoint ${slot:-none}, $(grep -a "scummvm exit status" $log | tail -1)): $(grep -a "AUTORUN FAIL" $log | tail -1 | cut -c1-120)" >> logs/whole.txt
	if [ "$file" = "$lastfile" ]; then same=$((same + 1)); else same=1; lastfile="$file"; fi
	if [ $same -ge $TRIES ]; then echo "giving up in $file"; exit 1; fi
	if [ -z "$slot" ]; then :; else
		# the file after the checkpoint that was saved last: the chapter that failed (a chapter that failed after its own checkpoint cannot happen: it ends with it)
		resume="$slot $file"
	fi

done
echo "too many attempts"; exit 1
