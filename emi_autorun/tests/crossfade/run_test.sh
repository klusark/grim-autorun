#!/bin/sh
# run_test.sh [ScummVM build dir]: two chores of one priority on Guybrush at once, compared with the original (compare.py).
# Real time, the window must be visible (frames captured from the screen). Default build: ~/scummvm/build-opt.
T=/c/Users/Joel/grim_tools/emi_autorun/tests/crossfade
EM=/c/Users/Joel/grim_tools/emi_autorun
OUT=$EM/scratch/crossfade_test
rm -rf "$OUT"; mkdir -p "$OUT"
cd $EM
: > logs/crossfade.log
# (the script name "crossfade" is how cap.ps1 finds this run's window among other ScummVM windows)
(REALTIME=1 NOLOG=90 SVM_DIR=${1:-/home/Joel/scummvm/build-opt} SAVES=$OUT LOG=crossfade ./run_emi.sh "$T/crossfade.lua" 300 > /dev/null 2>&1 &)
for p in A B C; do
	for i in $(seq 1 600); do grep -a -q "POSE $p\|scummvm exit" logs/crossfade.log 2>/dev/null && break; sleep 0.5; done
	if ! grep -a -q "POSE $p" logs/crossfade.log; then echo "FAIL: pose $p was not reached (logs/crossfade.log)"; exit 1; fi
	sleep 0.5
	powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(cygpath -w $T/cap.ps1)" -out "$(cygpath -w $OUT/$p)" -proc scummvm -match crossfade -n 1 > /dev/null 2>&1
done
python -I "$T/compare.py" "$OUT"
