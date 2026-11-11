#!/bin/sh
# The whole game in ONE run from a new game to the end of the credits (AR_CONTINUE: the ar_load lines do nothing, each ar_checkpoint saves and
# the run goes on). The acts follow each other as the game does: Act 1 (ch01..ch31), Act 2 without its jump (act2_02..25), Act 3 without its jump
# (act3_02..14, ends in Ozzie's tower), the tower and the fight of Act 4 (act4_26, 27).
# The act libraries replace parts of emi_lib.lua (the walking, the grid, ar_do ...) each in its own way: each act's library is put into the run just
# before the act, on top of a fresh copy of emi_lib.lua, poke and myst.
#   run_single.sh [timeout seconds]
#   RESUME="<slot> <first file>" run_single.sh   continues from a checkpoint of the last run's saves, with the files from <first file> on
# Checkpoints go to ./saves_single, the log is logs/single.log.
EM=/c/Users/Joel/grim_tools/emi_autorun
# the list: "file" lines are chapters, "lib" lines are libraries put into the run
LIST=""
for f in $(ls $EM/ch[0-9]*.lua | sort); do LIST="$LIST file:$f"; done
LIST="$LIST lib:emi_lib.lua lib:emi_poke.lua lib:emi_myst.lua lib:act2_lib.lua lib:emi_ribbon.lua"
for f in $(ls $EM/act2_[0-9][0-9]_*.lua | sort); do case $(basename $f) in act2_01_*) ;; *) LIST="$LIST file:$f";; esac; done
LIST="$LIST lib:emi_lib.lua lib:emi_poke.lua lib:emi_myst.lua lib:act3_lib.lua lib:emi_ribbon.lua"
# (the order a player has to play them in: the town (06) is reached through the gold mine (10), the canyon's other door; the pachinko rocks (11)
# and the weeds (12) come after the town)
for n in 02 03 04 05 10 11 12 06 07 08 09 13 14; do LIST="$LIST file:$(ls $EM/act3_${n}_*.lua)"; done
LIST="$LIST lib:emi_lib.lua lib:emi_poke.lua lib:emi_myst.lua lib:act4_lib.lua file:$EM/act4_26_tower.lua file:$EM/act4_27_fight.lua"
first=""
if [ -n "$RESUME" ]; then
	slot=$(echo $RESUME | awk '{print $1}'); first=$(echo $RESUME | awk '{print $2}')
fi
{
	# (the original brings back, with a save, the task that made it, the old run's code: the first F11 at the boot set loads the save,
	# the second runs this script again, which stops that task and goes on from the checkpoint; run_orig.sh presses it with RESUME set)
	[ -n "$first" ] && [ -n "$ORIG" ] && echo "if system.currentSet and system.currentSet.setFile and strlower(system.currentSet.setFile) == \"cdt.set\" then ar_load($slot) end"
	[ -n "$first" ] && [ -z "$ORIG" ] && echo "ar_load($slot)"
	echo "AR_CONTINUE = TRUE"
	echo "AR_TIMEOUT = 36000000"
	on=1; [ -n "$first" ] && on=0
	pending=""; lastkind=file
	for item in $LIST; do
		kind=${item%%:*}; f=${item#*:}
		b=$(basename $f)
		if [ "$on" = 0 ] && [ "$kind" = file ] && [ "$b" = "$first" ]; then
			on=1
			# (the libraries before the first chapter of the resume: those since the last file; in Act 1, which has no library lines,
			# the base ones: a checkpoint carries the functions as they were when it was saved, and a fix to them would not be seen)
			[ -z "$pending" ] && pending="emi_lib.lua emi_poke.lua emi_myst.lua"
			for l in $pending; do echo "ar_log(\"=== lib $l ===\")"; cat "$EM/$l"; echo; done
		fi
		if [ "$kind" = lib ]; then
			[ "$lastkind" = file ] && pending=""
			if [ "$on" = 1 ]; then echo "ar_log(\"=== lib $b ===\")"; cat "$EM/$b"; echo; else pending="$pending $b"; fi
			lastkind=lib
		else
			[ "$on" = 1 ] || { lastkind=file; continue; }
			echo "ar_log(\"=== file $b ===\")"; cat "$f"; echo
			lastkind=file
		fi
	done
	echo 'ar_log("=== THE WHOLE GAME DONE ===")'
	echo 'ar_finish()'
} > "$EM/generated/all_single${ORIG:+_orig}.lua"
export SAVES="$EM/saves_single"
mkdir -p "$SAVES"
export EXTRA="emi_poke.lua emi_myst.lua"
export NOLOG=${NOLOG:-90}
# ORIG=1: on the original Monkey4.exe (run_orig.sh) instead of ScummVM
if [ -n "$ORIG" ]; then
	LOG=${LOGNAME_OVERRIDE:-single_orig} "$EM/run_orig.sh" "$EM/generated/all_single${ORIG:+_orig}.lua" ${1:-20000}
else
	LOG=${LOGNAME_OVERRIDE:-single} "$EM/run_emi.sh" "$EM/generated/all_single${ORIG:+_orig}.lua" ${1:-20000}
fi
