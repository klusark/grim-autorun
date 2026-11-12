#!/bin/sh
# run_test.sh [ScummVM build dir]: the kitchen lever regression test (ScummVM bug 11794). Plays to the stove close-up in real time
# (the window must be visible: the frames are captured from the screen), captures 16 frames 0.5 s apart, compares them with the
# original's (compare.py). Default build: ~/scummvm/build-opt.
T=/c/Users/Joel/grim_tools/emi_autorun/tests/kitchen_lever
EM=/c/Users/Joel/grim_tools/emi_autorun
OUT=$EM/scratch/kitlever_test
rm -rf "$OUT"; mkdir -p "$OUT"
cd $EM
: > logs/kitlever.log
# (the log name "kitlever" is also how cap.ps1 finds this run's window among other ScummVM windows)
(REALTIME=1 NOLOG=90 SVM_DIR=${1:-/home/Joel/scummvm/build-opt} SAVES=$OUT LOG=kitlever ./run_emi.sh "$T/kitlever.lua" 300 > /dev/null 2>&1 &)
for i in $(seq 1 300); do grep -a -q "KITCHEN READY\|scummvm exit" logs/kitlever.log 2>/dev/null && break; sleep 1; done
if ! grep -a -q "KITCHEN READY" logs/kitlever.log; then echo "FAIL: the kitchen was not reached (logs/kitlever.log)"; exit 1; fi
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(cygpath -w $T/cap.ps1)" -out "$(cygpath -w $OUT/s)" -proc scummvm -match kitlever -n 16 -gap 500 > /dev/null 2>&1
python -I "$T/compare.py" "$OUT"
