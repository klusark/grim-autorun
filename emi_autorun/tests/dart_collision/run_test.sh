#!/bin/sh
# run_test.sh [ScummVM build dir]: ScummVM bug 11787 (Guybrush walks through the dart players). From a new game to the SCUMM Bar,
# 16 times: into the dart lane (the "stay out of my way" box sends Guybrush to its corner), then talk to the tall dart player at
# another moment of the darts game. Logs the closest distance (x-z, centres) from Guybrush to each dart player during the walk.
# The original (original.txt) keeps 0.77 m from George and 0.87 m from Ned; master before the path walk collision fix: 0.47 m.
# PASS when every distance under 1.5 m is at least 0.7 m.
EM=/c/Users/Joel/grim_tools/emi_autorun
T=$EM/tests/dart_collision
OUT=$EM/scratch/dart_collision_test
rm -rf "$OUT"; mkdir -p "$OUT"
cat "$EM/ch01_wed.lua" "$T/dart_walk.lua" > "$OUT/dart_walk_run.lua"
cd $EM
NOLOG=60 SVM_DIR=${1:-/home/Joel/scummvm/build-opt} SAVES=$OUT LOG=dart_collision ./run_emi.sh "$OUT/dart_walk_run.lua" 900 > /dev/null 2>&1
grep -a 'T87 trial .* closest' logs/dart_collision.log | sed 's/.*AUTORUN //' > "$OUT/result.txt"
n=$(wc -l < "$OUT/result.txt")
[ "$n" = 16 ] || { echo "FAIL: $n of 16 trials ran (logs/dart_collision.log)"; exit 1; }
awk '{ for (i = 1; i <= NF; i++) if ($i == "george" || $i == "ned") { d = $(i + 1); if (d < 1.5 && d < 0.7) { print "FAIL: " $0; bad = 1 } } } END { if (!bad) print "PASS: 16 trials, no dart player passed closer than 0.7 m" ; exit bad }' "$OUT/result.txt"
