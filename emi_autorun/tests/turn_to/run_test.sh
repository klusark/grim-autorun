#!/bin/sh
# run_test.sh [ScummVM build dir]: TurnActorTo stepping (turn_probe.lua). The original's TurnActorTo (0x41a960) turns the heading by
# HeadingFrame_TurnToward (0x444cf0): the signed yaw delta (-180..180) when it is <= rate*dt, otherwise one step of rate*dt; true only
# when a whole step was taken. A negative turn therefore ends in one call; a positive one steps. ORIG=1: on the original Monkey4.exe.
# The body yaw then eases to the heading (Walker_UpdateYaw 0x42a530). Run with 17 ms frames (SIMMS), the original's simtime frame.
# PASS when every call's result and every frame's yaw are the original's (original.txt, 0.01 deg).
EM=/c/Users/Joel/grim_tools/emi_autorun
T=$EM/tests/turn_to
OUT=$EM/scratch/turn_to_test${ORIG:+_orig}
mkdir -p "$OUT"
cd $EM
if [ -n "$ORIG" ]; then
	: > orig/grimdebug.log
	LOG=turn_to_orig NOLOG=60 ./run_orig.sh "$T/turn_probe.lua" 300 > /dev/null 2>&1
	L=logs/turn_to_orig.log
else
	SIMMS=17 NOLOG=60 SVM_DIR=${1:-/home/Joel/scummvm/build-opt} SAVES=$OUT LOG=turn_to ./run_emi.sh "$T/turn_probe.lua" 300 > /dev/null 2>&1
	L=logs/turn_to.log
fi
grep -a 'TT ' $L | sed 's/.*AUTORUN //' > "$OUT/result.txt"
grep -q 'TT done' "$OUT/result.txt" || { echo "FAIL: the run did not finish"; exit 1; }
[ -f "$T/original.txt" ] || { cat "$OUT/result.txt"; exit 0; }
python -I - "$T/original.txt" "$OUT/result.txt" <<'PY'
import sys
def turns(p):
    t = {}
    for l in open(p):
        w = l.split()
        if len(w) > 4 and w[3] in ('call', 'after'):
            t.setdefault(w[2], []).append((w[3], w[4], w[5] if w[3] == 'call' else '', float(w[-1])))
    return t
o, r = turns(sys.argv[1]), turns(sys.argv[2])
bad = 0
for k in o:
    a, b = o[k], r.get(k, [])
    same = len(a) == len(b) and all(x[:3] == y[:3] and abs(x[3] - y[3]) <= 0.01 for x, y in zip(a, b))
    if not same:
        bad = 1
        print('FAIL: target %s' % k)
        print('  original: ' + '; '.join('%s %s %s %.2f' % x for x in a))
        print('  here:     ' + '; '.join('%s %s %s %.2f' % y for y in b))
if not bad:
    print('PASS: %d turns frame by frame as the original' % len(o))
sys.exit(bad)
PY
