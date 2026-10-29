#!/bin/sh
# run_act2.sh <name|list> [timeout]: runs act2_<name>.lua. Without ACT2_LOAD the chapter must start itself; with it, ar_load(slot) is put first.
# run_act2.sh 01 : first chapter (new game + jump). run_act2.sh 02 : from checkpoint 201 (chapter NN loads slot 200+NN-1).
EM=/c/Users/Joel/grim_tools/emi_autorun
n="$1"
f=$(ls $EM/act2_${n}_*.lua | head -1)
export SAVES=$EM/saves_act2
export EXTRA="emi_poke.lua $EXTRA act2_lib.lua"
LOG="act2_$(basename $f .lua | sed 's/^act2_//')" "$EM/run_emi.sh" "$f" ${2:-400}
