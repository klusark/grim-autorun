#!/bin/sh
# run_test.sh [ScummVM build dir]: ScummVM bug 11789 (wood footsteps on Jambalaya's beach). fs_gpt.lua puts Guybrush at five places
# of the town and logs the footstep sector the game finds. gpt.setb's first footstep_dock repeats its first corner, so its normal is
# zero: master took every point of the plane as inside it (the beach got the dock's wood); the original tests the edges in x-z and
# the beach is outside (original.txt). PASS when the lines are the original's.
EM=/c/Users/Joel/grim_tools/emi_autorun
T=$EM/tests/footsteps
OUT=$EM/scratch/footsteps_test
mkdir -p "$OUT"
cd $EM
NOLOG=60 SVM_DIR=${1:-/home/Joel/scummvm/build-opt} SAVES=$OUT LOG=footsteps ./run_emi.sh "$T/fs_gpt.lua" 300 > /dev/null 2>&1
grep -a 'FSG' logs/footsteps.log | sed 's/.*AUTORUN //' > "$OUT/result.txt"
if diff "$T/original.txt" "$OUT/result.txt" > "$OUT/diff.txt"; then echo "PASS: footstep sectors as the original"; exit 0; fi
echo "FAIL: footstep sectors differ from the original:"; cat "$OUT/diff.txt"; exit 1
