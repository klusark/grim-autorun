#!/bin/sh
# Plays every act2_NN_*.lua chapter in one run from a new game (AR_CONTINUE: each ar_load does nothing, each ar_checkpoint saves and the run
# goes on): the jump to Act 2 up to the start of Act 3. Checkpoints go to ./saves_act2. Each chapter is a do ... end block of its own (locals).
EM=/c/Users/Joel/grim_tools/emi_autorun
{ echo "AR_CONTINUE = TRUE"; for f in $(ls $EM/act2_[0-9]*.lua | sort); do echo "ar_log(\"=== file $(basename $f) ===\")"; echo "do"; cat "$f"; echo; echo "end"; done; } > "$EM/generated/act2_all.lua"
export SAVES=$EM/saves_act2
export EXTRA="emi_poke.lua $EXTRA act2_lib.lua"
LOG=act2_all "$EM/run_emi.sh" "$EM/generated/act2_all.lua" ${1:-1800}
