#!/bin/sh
# run_test.sh [ScummVM build dir]: ScummVM bug 11822 (Guybrush walks through the tourist, Monty, at Tiny LaFeet's statue in
# Jambalaya town). From the game's jump to Jambalaya (250), Guybrush is put at 10 places round Monty and talks to him; the closest
# distance (x-z, centres) to Monty during the walk is logged, and whether the walk got stuck (no dialog after 20 s).
# The original (original.txt): never closer than 0.75 m; it slides round Monty, and from the front right (trial 4) it is blocked for
# good. Master walked through him (0.01 m).
# PASS when every trial keeps at least 0.7 m and the stuck trials are the original's.
EM=/c/Users/Joel/grim_tools/emi_autorun
T=$EM/tests/tourist_collision
OUT=$EM/scratch/tourist_collision_test
rm -rf "$OUT"; mkdir -p "$OUT"
cd $EM
NOLOG=60 SVM_DIR=${1:-/home/Joel/scummvm/build-opt} SAVES=$OUT LOG=tourist_collision ./run_emi.sh "$T/monty_walk.lua" 900 > /dev/null 2>&1
grep -a -E 'TM trial [0-9]+ (closest|STUCK)' logs/tourist_collision.log | sed 's/.*AUTORUN //' > "$OUT/result.txt"
n=$(grep -c closest "$OUT/result.txt")
[ "$n" = 10 ] || { echo "FAIL: $n of 10 trials ran (logs/tourist_collision.log)"; exit 1; }
bad=0
awk '/closest/ && $NF < 0.7 { print "FAIL: " $0; bad = 1 } END { exit bad }' "$OUT/result.txt" || bad=1
if [ "$(grep STUCK "$OUT/result.txt")" != "$(grep STUCK "$T/original.txt")" ]; then
	echo "FAIL: stuck trials differ from the original:"; grep STUCK "$OUT/result.txt"; echo "original:"; grep STUCK "$T/original.txt"; bad=1
fi
[ $bad = 0 ] && echo "PASS: 10 trials, never closer than 0.7 m, stuck as the original"
exit $bad
