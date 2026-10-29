#!/bin/sh
# Plays the whole game under ScummVM (simulated time, as fast as it goes) again and again until it has passed N times
# in a row (default 3), and stops at the first failure.   run_repeat.sh [N]
# The log of each pass is kept as logs/all_passK.log, that of the failure is logs/all.log.
AR=/c/Users/Joel/grim_tools/autorun
N="${1:-3}"
passes=0
while [ "$passes" -lt "$N" ]; do
	rm -f "$AR/logs/all.log"
	MSYSTEM=UCRT64 /c/msys64/usr/bin/bash.exe -l -c "cd $AR && ./run_all.sh 800" > /tmp/w/runall.out 2>&1
	if grep -aq "AUTORUN RESULT PASSED" "$AR/logs/all.log"; then
		passes=$((passes + 1))
		cp "$AR/logs/all.log" "$AR/logs/all_pass$passes.log"
		echo "PASS $passes of $N: $(tail -1 /tmp/w/runall.out)"
	else
		echo "FAILED after $passes passes:"
		grep -a "AUTORUN FAIL\|Error:\|failed to load" "$AR/logs/all.log" | grep -av "cannot set object state type" | head -3 | cut -c1-250
		exit 1
	fi
done
echo "$N PASSES IN A ROW"
