#!/bin/sh
# Continues a speed100 run from the checkpoints of an earlier one (SAVE=1 MODE=speed100 sh run_all.sh), chapter by chapter with run_chapter.sh: a chapter that
# fails after a sweep puts the set of the sweep into ex00_sweep.lua (AR_NO_SWEEP) and is run again from the same save. Each chapter that passes writes the
# save for the next. Stops when a chapter fails without a sweep before the failure, or after 3 tries.
#   sweep_chapters.sh <first chapter, such as ch54> [last chapter]
AR=/c/Users/Joel/grim_tools/autorun
cd "$AR" || exit 1
first="$1"; last="${2:-ch99}"
started=""
for c in ch*.lua; do
	name=${c%.lua}
	[ -z "$started" ] && case "$name" in "$first"*) started=1 ;; esac
	[ -z "$started" ] && continue
	tries=0
	while :; do
		tries=$((tries + 1))
		MODE=speed100 LOGTAG=_s100 sh run_chapter.sh "$c" 900 > /tmp/sweep_ch.out 2>&1
		r=$(python tools/sweep_blame.py "logs/${name}_s100.log")
		echo "$name try $tries: $r"
		[ "$r" = "PASSED" ] && break
		set_name=${r%%|*}; why=${r#*|}
		if [ "$set_name" = "?" ] || [ $tries -ge 3 ] || grep -q "AR_NO_SWEEP\[\"$set_name\"\]" ex00_sweep.lua; then
			echo "stopped at $name"; exit 1
		fi
		printf 'AR_NO_SWEEP["%s"] = "a chapter failed after the sweep: %s"\n' "$set_name" "$(echo "$why" | tr -d '"')" >> ex00_sweep.lua
	done
	case "$name" in "$last"*) break ;; esac
done
