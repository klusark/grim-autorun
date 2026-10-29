#!/bin/sh
# run_ch.sh <last chapter prefix> : the chapters ch01.. up to that one, replayed from the new game, in one run
EM=/c/Users/Joel/grim_tools/emi_autorun
last="$1"; shift
list=""
for f in $(ls $EM/ch[0-9]*.lua | sort); do
	n=$(basename $f)
	list="$list $n"
	case "$n" in "$last"*) break;; esac
done
set -- $list
final="$EM/$(echo $list | awk '{print $NF}')"
extra=$(echo $list | awk '{ $NF=""; print }')
EXTRA="$extra" "$EM/run_emi.sh" "$final" ${LIMIT:-300}
