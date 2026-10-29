#!/bin/sh
# run_act3.sh NN [timeout]: runs act3_NN_*.lua alone from the checkpoint of the chapter before it (slot 300+NN-1; NN=01 starts a new game).
# run_act3.sh file.lua [timeout] runs a scratch file (LOAD=slot loads that checkpoint first). POKE=1 loads emi_poke.lua.
# LOG=act3_<name>. Saves in saves_act3.
EM=/c/Users/Joel/grim_tools/emi_autorun
if [ -f "$1" ]; then f="$1"; tmp="$EM/generated/act3_scratch_$(basename $f)"; pre=""; [ -n "$LOAD" ] && pre="ar_load($LOAD)"
else
n=$(echo "$1" | sed 's/^0*//'); prev=$((n - 1))
f=$(ls $EM/act3_$(printf %02d $n)_*.lua | head -1)
tmp="$EM/generated/act3_one_$(printf %02d $n).lua"
pre=""; [ "$prev" -ge 1 ] && pre="ar_load($((300 + prev)))"
fi
{ [ -n "$pre" ] && echo "$pre"; cat "$f"; } > "$tmp"
export SAVES=C:/Users/Joel/grim_tools/emi_autorun/saves_act3
export EXTRA="act3_lib.lua $([ -n "$POKE" ] && echo emi_poke.lua)"
export NOLOG=${NOLOG:-40}
export LOG="${LOG:-$(basename $f .lua)}"
mkdir -p "$SAVES"
"$EM/run_emi.sh" "$tmp" ${2:-300}
