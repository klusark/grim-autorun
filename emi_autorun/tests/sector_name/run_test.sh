#!/bin/sh
# run_test.sh [ScummVM build dir]: GetSectorName(x, y, z) on Jambalaya (sn_gpt.lua: the tourist waypoints, with their boxes on and
# off, and a grid at two heights). The original's Lua GetSectorName (0x419780) names the first sector of any type that holds the
# point (Set_FindSectorOfType 0x446490, mask -1) and nil when none does; master asked for type 0 and never named one, so gpt's and
# luc's tourist scripts turned their waypoint box off at once. ORIG=1: on the original Monkey4.exe (run_orig.sh) instead.
# PASS when the lines are the original's (original.txt).
EM=/c/Users/Joel/grim_tools/emi_autorun
T=$EM/tests/sector_name
OUT=$EM/scratch/sector_name_test${ORIG:+_orig}
mkdir -p "$OUT"
cd $EM
if [ -n "$ORIG" ]; then
	: > orig/grimdebug.log
	LOG=sector_name_orig NOLOG=60 ./run_orig.sh "$T/sn_gpt.lua" 300 > /dev/null 2>&1
	grep -a 'SN ' logs/sector_name_orig.log | sed 's/.*AUTORUN //' > "$OUT/result.txt"
else
	NOLOG=60 SVM_DIR=${1:-/home/Joel/scummvm/build-opt} SAVES=$OUT LOG=sector_name ./run_emi.sh "$T/sn_gpt.lua" 300 > /dev/null 2>&1
	grep -a 'SN ' logs/sector_name.log | sed 's/.*AUTORUN //' > "$OUT/result.txt"
fi
grep -q 'SN done' "$OUT/result.txt" || { echo "FAIL: the run did not finish"; exit 1; }
[ -f "$T/original.txt" ] || { cat "$OUT/result.txt"; exit 0; }
if diff "$T/original.txt" "$OUT/result.txt" > "$OUT/diff.txt"; then echo "PASS: $(wc -l < "$OUT/result.txt") sector names as the original"; exit 0; fi
echo "FAIL: sector names differ from the original:"; cat "$OUT/diff.txt"; exit 1
