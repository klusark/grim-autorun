#!/bin/sh
# Plays every act3_NN_*.lua chapter in one run from a new game (AR_CONTINUE: each ar_checkpoint saves and the run goes on).
# Checkpoints land in ./saves_act3 (slots 301..); run_act3.sh NN replays one chapter from the save of the one before it.
EM=/c/Users/Joel/grim_tools/emi_autorun
{ echo "AR_CONTINUE = TRUE"; for f in $(ls $EM/act3_[0-9][0-9]_*.lua | sort); do echo "ar_log(\"=== file $(basename $f) ===\")"; cat "$f"; echo; done; } > "$EM/generated/all_act3.lua"
export SAVES=C:/Users/Joel/grim_tools/emi_autorun/saves_act3
export EXTRA="act3_lib.lua"
export NOLOG=${NOLOG:-90}
mkdir -p "$SAVES"
LOG=all_act3 "$EM/run_emi.sh" "$EM/generated/all_act3.lua" ${1:-3000}
