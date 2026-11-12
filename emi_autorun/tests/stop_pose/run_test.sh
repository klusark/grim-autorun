#!/bin/sh
# run_test.sh [ScummVM build dir]: a bone whose only animation is stopped keeps its pose, as in the original (compare.py).
# Real time; the frames come from the window itself (PrintWindow), other windows on top do not matter. Default build: ~/scummvm/build-opt.
T=/c/Users/Joel/grim_tools/emi_autorun/tests/stop_pose
EM=/c/Users/Joel/grim_tools/emi_autorun
OUT=$EM/scratch/stop_pose_test
rm -rf "$OUT"; mkdir -p "$OUT"
cd $EM
: > logs/stop_pose.log
# (the script name "stop_pose" is how cap.ps1 finds this run's window among other ScummVM windows)
(REALTIME=1 NOLOG=90 SVM_DIR=${1:-/home/Joel/scummvm/build-opt} SAVES=$OUT LOG=stop_pose ./run_emi.sh "$T/stop_pose.lua" 300 > /dev/null 2>&1 &)
for p in A B C; do
	for i in $(seq 1 600); do grep -a -q "POSE $p\|scummvm exit" logs/stop_pose.log 2>/dev/null && break; sleep 0.5; done
	if ! grep -a -q "POSE $p" logs/stop_pose.log; then echo "FAIL: pose $p was not reached (logs/stop_pose.log)"; exit 1; fi
	sleep 0.5
	powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(cygpath -w $T/cap.ps1)" -out "$(cygpath -w $OUT/$p)" -proc scummvm -match stop_pose -n 1 > /dev/null 2>&1
done
python -I "$T/compare.py" "$OUT"
