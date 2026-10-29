#!/bin/sh
# Act 1 in pieces, each in its own process (the EMI engine and a few waits are flaky enough that one long process rarely gets through all
# of it), a failed piece tried again (TRIES times, default 3). ch01..ch08 have one checkpoint, at the end of ch08 (run_ch.sh ch08 replays
# them from a new game); every later chapter starts from the checkpoint of the one before it (run_one.sh).
EM=/c/Users/Joel/grim_tools/emi_autorun
TRIES=${TRIES:-3}
export EXTRA="emi_poke.lua emi_myst.lua"
FROM=${1:-1}
if [ "$FROM" -le 8 ]; then
	t=1; ok=
	while [ $t -le $TRIES ]; do
		LOG=act1_ch01_08 "$EM/run_ch.sh" ch08 > /dev/null 2>&1
		if grep -aq "RESULT PASSED" "$EM/logs/act1_ch01_08.log" && grep -aq "saved checkpoint grim08" "$EM/logs/act1_ch01_08.log"; then ok=1; break; fi
		echo "ch01-08 try $t failed"; t=$((t + 1))
	done
	if [ -z "$ok" ]; then echo "ch01-08 FAILED after $TRIES tries"; exit 1; fi
	echo "ch01-08 passed (try $t)"
fi
for f in $(ls $EM/ch[0-9]*.lua | sort); do
	b=$(basename $f .lua); ch=$(echo $b | sed 's/_.*//')
	n=$(echo $ch | sed 's/^ch0*//')
	[ "$n" -le 8 ] && continue
	[ "$n" -lt "$FROM" ] && continue
	t=1; ok=
	while [ $t -le $TRIES ]; do
		"$EM/run_one.sh" $ch 600 > /dev/null 2>&1
		if grep -aq "RESULT PASSED" "$EM/logs/$b.log"; then ok=1; break; fi
		echo "$ch try $t failed"; t=$((t + 1))
	done
	if [ -z "$ok" ]; then echo "$ch FAILED after $TRIES tries"; exit 1; fi
	echo "$ch passed (try $t)"
done
echo "ACT 1 DONE"
