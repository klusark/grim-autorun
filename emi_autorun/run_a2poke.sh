#!/bin/sh
# run_a2poke.sh <file in tmp_a2> [timeout]: a throw-away exploration script (poker), with the act2 helpers; log act2_poke_<name>
EM=/c/Users/Joel/grim_tools/emi_autorun
export SAVES=$EM/saves_act2
export EXTRA="emi_poke.lua $EXTRA act2_lib.lua"
n=$(basename $1 .lua)
LOG="act2_poke_$n" "$EM/run_emi.sh" "$EM/tmp_a2/$n.lua" ${2:-600}
