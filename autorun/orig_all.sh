#!/bin/sh
# Plays the whole game on the ORIGINAL and does not give up at the first failure of a step: when the autorun fails (or nothing is logged for
# 10 minutes) the game is started again from the checkpoint save of the chapter that failed (resume_original.sh <chapter - 1> <chapter>), up to
# three times for each chapter. The log of every attempt is kept in logs/orig_all_<n>.log, the story in logs/orig_all.txt.
#   sh orig_all.sh [first chapter prefix, default none: a new game]       (FRAMES=0 etc. as for build_original.sh)
AR=/c/Users/Joel/grim_tools/autorun
L="/c/GOG Games/GRIMDATA/grimdebug.log"
STORY="$AR/logs/orig_all.txt"
say() { echo "$(date '+%m-%d %H:%M:%S') $*" | tee -a "$STORY"; }

start_game() {
	# $1 = chapter prefix or empty for a new game
	taskkill //F //IM GRIMFANDANGO.exe > /dev/null 2>&1
	taskkill //F //IM grimrun2.exe > /dev/null 2>&1
	sleep 2
	STARTED=$(date +%s)
	if [ -z "$1" ]; then
		(sh "$AR/run_original.sh" ${ORIG_F12:-2} > "$AR/logs/orig_run.out" 2>&1 &)
	else
		# (the slot is the one the chapter loads itself: ar_load(N) in its file, a chapter in two parts has one more than its number)
		slot=$(grep -h -m1 -o 'ar_load([0-9]*)' "$AR"/$1*.lua | head -1 | sed 's/[^0-9]//g')
		if [ -z "$slot" ]; then
			n=$(echo "$1" | sed 's/^ch0*\([0-9]*\).*/\1/')
			slot=$((n - 1))
		fi
		(sh "$AR/resume_original.sh" "$slot" "$1" > "$AR/logs/orig_run.out" 2>&1 &)
	fi
}

prefix="$1"
attempt=0
declare_tries=""
say "start, from ${prefix:-the new game}"
start_game "$prefix"
while true; do
	sleep 20
	# (the original is silent: the recording of ScummVM next to it must not hear it; Windows keeps the setting only for the session of the process)
	powershell -NoProfile -ExecutionPolicy Bypass -File "$AR/tools/mute_app.ps1" GRIMFANDANGO > /dev/null 2>&1
	last=$(grep -a "=== chapter" "$L" 2>/dev/null | tail -1 | sed 's/.*=== chapter \(ch[0-9]*\).*/\1/')
	if grep -aq "AUTORUN RESULT PASSED" "$L" 2>/dev/null; then
		say "PASSED the whole game"
		cp "$L" "$AR/logs/orig_all_$attempt.log"
		taskkill //F //IM GRIMFANDANGO.exe > /dev/null 2>&1
		exit 0
	fi
	why=""
	if grep -aq "AUTORUN RESULT FAILED" "$L" 2>/dev/null; then
		why="failed: $(grep -a 'AUTORUN FAIL' "$L" | tail -1 | cut -c1-160)"
	elif ! tasklist | grep -qi GRIMFANDANGO; then
		# (the game has gone: crashed or closed)
		if [ -n "$last" ] && [ "$(wc -c < "$L")" -gt 20000 ]; then why="the game has gone"; fi
		# (a game that is not there 90 s after it was started did not come up, or went before the log was long)
		[ -z "$why" ] && [ $(( $(date +%s) - STARTED )) -gt 90 ] && why="the game has gone (or did not come up)"
	else
		age=$(( $(date +%s) - $(date -r "$L" +%s) ))
		[ "$age" -gt 600 ] && why="nothing logged for $age s"
	fi
	[ -z "$why" ] && continue
	say "chapter ${last:-none}: $why"
	cp "$L" "$AR/logs/orig_all_$attempt.log"
	attempt=$((attempt + 1))
	[ -z "$last" ] && { say "no chapter to resume from, giving up"; exit 1; }
	tries=$(grep -c "resume $last\$" "$STORY")
	if [ "$tries" -ge 3 ]; then
		# (a chapter that fails three times is a failure that is known: the game goes on with the next chapter, from the checkpoint save of the end of
		# the one before it, which is one of an earlier run; the failures are listed at the end of the story)
		next=$(ls "$AR"/ch*.lua | sed 's|.*/\(ch[0-9]*\).*|\1|' | sort -u | awk -v c="$last" '$0 > c { print; exit }')
		if [ -z "$next" ]; then
			say "chapter $last failed 3 times and is the last one: the end"
			exit 1
		fi
		say "KNOWN FAILURE chapter $last (3 times): on with $next"
		say "resume $next"
		start_game "$next"
		sleep 60
		continue
	fi
	say "resume $last"
	start_game "$last"
	sleep 60
done
