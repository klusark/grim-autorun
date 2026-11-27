#!/bin/sh
# run_test.sh [ScummVM build dir]: ScummVM bug 11849 (after a set change the first setup shows for a moment). Plays ch01-ch03 with a
# per-frame watcher of the set and its setup (setup_watch.lua) and compares the changes with the original's (original.txt): the same
# order of sets and setups (the boot set cdt left out: it starts in setup 0 here, 1 on the original), and the frames each one lasted before the next within 2 frames when it lasted under 30 (the brief ones:
# Melee town shows setup 0 for 2 frames before setup 3 on the original too). Drawing of those frames is not checked.
EM=/c/Users/Joel/grim_tools/emi_autorun
T=$EM/tests/setup_switch
OUT=$EM/scratch/setup_switch_test
mkdir -p "$OUT"
cd $EM
EXTRA="emi_poke.lua emi_myst.lua" NOLOG=90 SVM_DIR=${1:-/home/Joel/scummvm/build-opt} SAVES=$OUT LOG=setup_switch ./run_emi.sh "$T/setup_run.lua" 900 > /dev/null 2>&1
grep -a -E 'SW ' logs/setup_switch.log | sed 's/.*AUTORUN //' > "$OUT/result.txt"
python -I - "$T/original.txt" "$OUT/result.txt" <<'PY'
import sys
def rd(p):
    r = [l.split() for l in open(p) if l.startswith('SW ') and 'cdt.set' not in l]
    return [(a[2], a[3], int(b[1]) - int(a[1])) for a, b in zip(r, r[1:])]
o, s = rd(sys.argv[1]), rd(sys.argv[2])
if [x[:2] for x in o] != [x[:2] for x in s]:
    print('FAIL: the sets and setups change in another order'); sys.exit(1)
bad = [(a, b) for a, b in zip(o, s) if min(a[2], b[2]) < 30 and abs(a[2] - b[2]) > 2]
for a, b in bad: print('FAIL: %s %s lasted %d frames, the original %d' % (b[0], b[1], b[2], a[2]))
if not bad: print('PASS: %d set/setup changes as the original' % len(s))
sys.exit(1 if bad else 0)
PY
