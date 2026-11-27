#!/bin/sh
# run_test.sh [ScummVM build dir]: ScummVM bug 11824 (lava ride boats float back facing one way after a bump). Plays Act 3 from the
# game's jump (act3_01) to the church's rides (act3_04, which rides until the milk bottle, bumping boats on the way), with the empty
# boats watched (boat_watch.lua). ORIG=1: on the original Monkey4.exe. Prints the rest yaws; with original.txt there, compares.
EM=/c/Users/Joel/grim_tools/emi_autorun
T=$EM/tests/lava_boats
OUT=$EM/scratch/lava_boats_test${ORIG:+_orig}
mkdir -p "$OUT"
{
	echo "AR_CONTINUE = TRUE"
	echo "AR_TIMEOUT = 36000000"
	for l in generated/emi_nav_planner.lua emi_nav_data.lua emi_nav.lua emi_lib.lua emi_poke.lua emi_myst.lua act3_lib.lua emi_ribbon.lua; do cat "$EM/$l"; echo; done
	cat "$T/boat_watch.lua"; echo
	for n in 01 02 03 04; do f=$(ls $EM/act3_${n}_*.lua); echo "ar_log(\"=== file $(basename $f) ===\")"; cat "$f"; echo; done
	echo 'ar_log("LB done")'
} > "$OUT/lava_boats_run.lua"
python "$EM/emi_nav_gen.py" "$EM/generated/emi_nav_planner.lua" || exit 1
cd $EM
if [ -n "$ORIG" ]; then
	: > orig/grimdebug.log
	LOG=lava_boats_orig NOLOG=200 ./run_orig.sh "$OUT/lava_boats_run.lua" 5400 > /dev/null 2>&1
	grep -a -E 'LB (rest|done)' orig/grimdebug.log | sed 's/.*AUTORUN //' | tr -d '\r' > "$OUT/result.txt"
else
	NOLOG=120 SVM_DIR=${1:-/home/Joel/scummvm/build-opt} SAVES=$OUT LOG=lava_boats ./run_emi.sh "$OUT/lava_boats_run.lua" 3600 > /dev/null 2>&1
	grep -a -E 'LB (rest|done)' logs/lava_boats.log | sed 's/.*AUTORUN //' > "$OUT/result.txt"
fi
cat "$OUT/result.txt"
# Result 2026-11-26 (original.txt): the original's bumped boats also float back to their home nodes facing about -145..-172 (one
# way, the ticket's "upper left"), and the boats at rest before any bump have the same yaws on both engines: the ride's own behaviour.
# PASS when the first 8 rests (the boats before the ride) have the original's yaws.
[ -f "$T/original.txt" ] || exit 0
key() { head -8 "$1" | awk '{ printf "%s %.2f\n", $5, $7 }' | sort; }
[ "$(key "$OUT/result.txt")" = "$(key "$T/original.txt")" ] && { echo "PASS: the boats rest as the original's"; exit 0; }
echo "FAIL: the boats' rests differ from the original's"; exit 1
