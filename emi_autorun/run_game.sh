#!/bin/sh
# The whole game in one run: the chapters of Act 1 played from a new game (ch01..), then Acts 2, 3 and 4 (act2_NN_*, act3_NN_*, act4_NN_*).
# Where a part is not played yet the next part starts with the game's own milestone jump (act2_01, act3_01 and act4_01 jump_script to their
# acts), so the chain is complete even where Act 1's Lucre Island puzzles (Mysts o' Tyme, Pegnose, Ozzie) are still bridged by that jump.
# Checkpoints go to ./saves_game. AR_CONTINUE: the ar_load lines do nothing, each ar_checkpoint saves and the run goes on.
EM=/c/Users/Joel/grim_tools/emi_autorun
{
	echo "AR_CONTINUE = TRUE"
	for pat in 'ch[0-9]*.lua' 'act2_[0-9][0-9]_*.lua' 'act3_[0-9][0-9]_*.lua' 'act4_[0-9][0-9]_*.lua'; do
		for f in $(ls $EM/$pat 2>/dev/null | sort); do
			echo "ar_log(\"=== file $(basename $f) ===\")"; cat "$f"; echo
		done
	done
} > "$EM/generated/all_game.lua"
extra=""
for l in act2_lib.lua act3_lib.lua act4_lib.lua emi_poke.lua; do [ -f "$EM/$l" ] && extra="$extra $l"; done
SAVES="$EM/saves_game" EXTRA="$extra" LOG=game "$EM/run_emi.sh" "$EM/generated/all_game.lua" ${1:-7200}
