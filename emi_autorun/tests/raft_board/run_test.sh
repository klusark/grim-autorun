#!/bin/sh
# run_test.sh [ScummVM build dir]: ScummVM bug 11819 (Guybrush lies tilted when he gets on the raft at the Mysts o' Tyme). Boards the
# raft (raft_board.lua) and checks that Guybrush is never pitched or rolled (his rotation x and z stay 0, as the scripts set them).
# Not reproducible on master 2026-11-26: scummvm_boarding.png (40 frames of the boarding, upright throughout).
EM=/c/Users/Joel/grim_tools/emi_autorun
T=$EM/tests/raft_board
OUT=$EM/scratch/raft_board_test
mkdir -p "$OUT"
cd $EM
EXTRA="emi_poke.lua emi_myst.lua" NOLOG=90 SVM_DIR=${1:-/home/Joel/scummvm/build-opt} SAVES=$OUT LOG=raft_board ./run_emi.sh "$T/raft_board.lua" 300 > /dev/null 2>&1
r=$(grep -a 'RB largest' logs/raft_board.log | sed 's/.*AUTORUN //')
case "$r" in
	"RB largest pitch 0 roll 0") echo "PASS: $r" ;;
	"") echo "FAIL: the boarding did not end (logs/raft_board.log)"; exit 1 ;;
	*) echo "FAIL: $r"; exit 1 ;;
esac
