#!/bin/sh
# run_test.sh [ScummVM build dir]: ScummVM bug 11817 (Ozzie walks off the screen when he gets his cane). Plays Act 1 from a new game
# to ch16_cane (the framed Guybrush leaves the House of Sticks and Ozzie comes in for his cane: hos.ozzie_takes_stick) with Ozzie's
# walks traced (ow_watch.lua). ORIG=1: on the original Monkey4.exe (run_orig.sh) instead. The walks and the original's are in
# original.txt; PASS when every walk ends where the original's does and strays no more than 0.15 m further from its straight line.
EM=/c/Users/Joel/grim_tools/emi_autorun
T=$EM/tests/ozzie_cane
OUT=$EM/scratch/ozzie_cane_test${ORIG:+_orig}
rm -rf "$OUT"; mkdir -p "$OUT"
{
	echo "AR_CONTINUE = TRUE"
	echo "AR_TIMEOUT = 36000000"
	cat "$T/ow_watch.lua"; echo
	for f in $(ls $EM/ch[0-9]*.lua | sort | head -16); do echo "ar_log(\"=== file $(basename $f) ===\")"; cat "$f"; echo; done
	echo 'sleep_for(3000)'
} > "$OUT/ozzie_cane_run.lua"
cd $EM
if [ -n "$ORIG" ]; then
	LOG=ozzie_cane_orig NOLOG=150 ./run_orig.sh "$OUT/ozzie_cane_run.lua" 3600 > /dev/null 2>&1
	grep -a -E 'OW walk [0-9]+ (starts|ends)' orig/grimdebug.log | sed 's/.*AUTORUN //' > "$OUT/result.txt"
else
	EXTRA="emi_poke.lua emi_myst.lua" NOLOG=90 SVM_DIR=${1:-/home/Joel/scummvm/build-opt} SAVES=$OUT LOG=ozzie_cane ./run_emi.sh "$OUT/ozzie_cane_run.lua" 1800 > /dev/null 2>&1
	grep -a -E 'OW walk [0-9]+ (starts|ends)' logs/ozzie_cane.log | sed 's/.*AUTORUN //' > "$OUT/result.txt"
fi
cat "$OUT/result.txt"
[ -f "$T/original.txt" ] || exit 0
python -I - "$T/original.txt" "$OUT/result.txt" <<'PY'
import sys
def walks(p):
    return [l.split() for l in open(p) if ' ends at ' in l]
o, r = walks(sys.argv[1]), walks(sys.argv[2])
if len(o) != len(r):
    print('FAIL: %d walks, the original %d' % (len(r), len(o))); sys.exit(1)
bad = 0
for a, b in zip(o, r):
    ex = abs(float(a[5]) - float(b[5])) + abs(float(a[6]) - float(b[6]))
    if ex > 0.05 or float(b[8]) > float(a[8]) + 0.15:
        print('FAIL: %s / original %s' % (' '.join(b), ' '.join(a))); bad = 1
print('PASS: %d walks as the original' % len(r) if not bad else '')
sys.exit(bad)
PY
