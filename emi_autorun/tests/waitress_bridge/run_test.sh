#!/bin/sh
# run_test.sh [ScummVM build dir]: ScummVM bug 11886 (Guybrush stuck after bumping into the Lua Bar waitress on the bridge).
# 40 walks across the bridge (bridge_walk.lua). The original (original.txt): 11 bumps, never stuck. Master before the path walk
# collision fix: Guybrush walked into her, lua.ensurewalk never reached its point and the run was stuck for good.
# PASS when all 40 walks end and no bump cutscene lasts 20 s.
EM=/c/Users/Joel/grim_tools/emi_autorun
T=$EM/tests/waitress_bridge
OUT=$EM/scratch/waitress_bridge_test
rm -rf "$OUT"; mkdir -p "$OUT"
cd $EM
EXTRA="emi_poke.lua emi_myst.lua" NOLOG=90 SVM_DIR=${1:-/home/Joel/scummvm/build-opt} SAVES=$OUT LOG=waitress_bridge ./run_emi.sh "$T/bridge_walk.lua" 1500 > /dev/null 2>&1
done=$(grep -a 'WB done' logs/waitress_bridge.log | sed 's/.*AUTORUN //')
stuck=$(grep -a -c 'WB STUCK' logs/waitress_bridge.log)
if [ -n "$done" ] && [ "$stuck" = 0 ]; then echo "PASS: $done (original: $(grep 'WB done' $T/original.txt))"; exit 0; fi
echo "FAIL: ${done:-the walks never ended}, $stuck stuck (logs/waitress_bridge.log)"; exit 1
