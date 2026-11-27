#!/bin/sh
# run_test.sh [ScummVM build dir]: ScummVM bug 11873 (Miss Rivers walks through Yangja's chair in the classroom). From the game's
# jump to Jambalaya (275) to the class and its tobacco part: logs Miss Rivers' walks and how close (x-z, centres) she comes to
# pta.chair2. The original (original.txt) walks to the trash can and back on the same lines, 0.683 m from the chair, and draws her
# over the chair the same way (scummvm_vs_original.png, left ScummVM, right the original): the overlap is the original's own.
# PASS when the two walks round the chair come within 1 cm of the original's closest distances.
EM=/c/Users/Joel/grim_tools/emi_autorun
T=$EM/tests/chair_walk
OUT=$EM/scratch/chair_walk_test
rm -rf "$OUT"; mkdir -p "$OUT"
cd $EM
EXTRA="emi_poke.lua emi_myst.lua act2_lib.lua" NOLOG=90 SVM_DIR=${1:-/home/Joel/scummvm/build-opt} SAVES=$OUT LOG=chair_walk ./run_emi.sh "$T/rivers_walk.lua" 900 > /dev/null 2>&1
grep -a -E 'RW walk [0-9]+ ends at -1[24]\.' logs/chair_walk.log | sed 's/.*AUTORUN //' | grep -E 'at -14.522|at -12.13 ' > "$OUT/all.txt"
tail -2 "$OUT/all.txt" > "$OUT/result.txt"
python -I - "$T/original.txt" "$OUT/result.txt" <<'PY'
import sys
o = [float(l.split()[-3]) for l in open(sys.argv[1]) if 'closest' in l]
r = [float(l.split()[-3]) for l in open(sys.argv[2]) if 'closest' in l]
if len(r) != 2:
    print('FAIL: the two walks round the chair were not seen'); sys.exit(1)
bad = [(a, b) for a, b in zip(o, r) if abs(a - b) > 0.01]
print('FAIL: closest to chair2 %s, original %s' % (r, o) if bad else 'PASS: closest to chair2 %s, original %s' % (r, o))
sys.exit(1 if bad else 0)
PY
