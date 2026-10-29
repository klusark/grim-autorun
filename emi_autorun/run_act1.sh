#!/bin/sh
# The whole of Act 1 (ch01..) in one run from a new game; AR_CONTINUE so each ar_checkpoint saves and the run goes on. Log logs/act1_all.log.
EM=/c/Users/Joel/grim_tools/emi_autorun
{
	echo "AR_CONTINUE = TRUE"
	for f in $(ls $EM/ch[0-9]*.lua | sort); do
		echo "ar_log(\"=== file $(basename $f) ===\")"; cat "$f"; echo
	done
} > "$EM/generated/all_act1.lua"
SAVES="$EM/saves_act1" EXTRA="emi_poke.lua" LOG=act1_all "$EM/run_emi.sh" "$EM/generated/all_act1.lua" ${1:-3600}
