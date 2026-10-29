#!/bin/sh
# Plays every ch*.lua chapter in one run from a new game (AR_CONTINUE: the ar_load of a chapter does nothing, each ar_checkpoint saves and
# the run goes on). The checkpoints land in ./saves; run_one.sh chNN replays one chapter from the save of the one before it.
EM=/c/Users/Joel/grim_tools/emi_autorun
{ echo "AR_CONTINUE = TRUE"; for f in $(ls $EM/ch[0-9]*.lua | sort); do echo "ar_log(\"=== file $(basename $f) ===\")"; cat "$f"; echo; done; } > "$EM/generated/all_emi.lua"
LOG=all_emi "$EM/run_emi.sh" "$EM/generated/all_emi.lua" ${1:-1800}
