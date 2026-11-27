#!/bin/sh
# run_test.sh [ScummVM build dir]: ScummVM bug 11870 (sawdust piles turned at weird angles). Real time: the window must be on the
# screen. Lays out the piles in the forest (sawdust_snap.lua), captures the window, compares the path with the original (compare.py).
EM=/c/Users/Joel/grim_tools/emi_autorun
T=$EM/tests/sawdust
OUT=$EM/scratch/sawdust_test
rm -rf "$OUT"; mkdir -p "$OUT"
cd $EM
: > logs/sawdust_snap.log
(REALTIME=1 EXTRA="emi_poke.lua emi_myst.lua" NOLOG=120 SVM_DIR=${1:-/home/Joel/scummvm/build-opt} SAVES=$OUT LOG=sawdust_snap ./run_emi.sh "$T/sawdust_snap.lua" 300 > /dev/null 2>&1 &)
for i in $(seq 1 200); do grep -a -q "SAWDUST SNAP READY\|scummvm exit" logs/sawdust_snap.log 2>/dev/null && break; sleep 1; done
grep -a -q "SAWDUST SNAP READY" logs/sawdust_snap.log || { echo "FAIL: the forest was not reached (logs/sawdust_snap.log)"; exit 1; }
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(cygpath -w $EM/tests/kitchen_lever/cap.ps1)" -out "$(cygpath -w $OUT/s)" -proc scummvm -match sawdust_snap -n 1 -gap 100 > /dev/null 2>&1
python -I "$T/compare.py" "$OUT/s0.png"
