#!/bin/sh
# run_one.sh chNN [timeout]: runs that chapter alone from the checkpoint of the chapter before it (ar_load(NN-1), the save made at its end);
# the chapter ends with its own ar_checkpoint(NN). (run_ch.sh <chNN> still replays everything from a new game.)
EM=/c/Users/Joel/grim_tools/emi_autorun
ch="$1"; n=$(echo "$ch" | sed 's/^ch0*\([0-9]*\).*/\1/'); prev=$((n - 1))
f=$(ls $EM/${ch}_*.lua | head -1)
tmp="$EM/generated/one_${ch}.lua"
{ [ "$prev" -ge 1 ] && echo "ar_load($prev)"; cat "$f"; } > "$tmp"
LOG="$(basename $f .lua)" "$EM/run_emi.sh" "$tmp" ${2:-300}
