#!/bin/sh
# A sampling profile of a run: every few seconds gdb attaches to scummvm.exe and writes the stack of its main thread to <out>.
#   sh tools/sample_prof.sh <out> [seconds between samples, default 4] [frames to keep, default 8]
# (the game stands still for the second or so that gdb takes; its clock is simulated, so the run itself is not changed)
out="$1"
every="${2:-4}"
frames="${3:-8}"
: > "$out"
n=0
seen=0
gone=0
while :; do
	pid=$(sh "$(dirname "$0")/svm_ps.sh" pid)
	case "$pid" in
		''|*[!0-9]*)
			if [ $seen -eq 1 ]; then
				gone=$((gone + 1))
				[ $gone -gt 5 ] && exit 0
			fi
			sleep 2
			continue;;
	esac
	seen=1
	gone=0
	n=$((n + 1))
	echo "=== sample $n" >> "$out"
	timeout 60 gdb -batch -p "$pid" -ex "thread 1" -ex "bt $frames" 2>/dev/null | grep "^#" >> "$out"
	sleep "$every"
done
