#!/bin/sh
# One try of a chapter of the ORIGINAL at a frame-rate cap: sh tools/orig_try.sh <GRIM_FPS> <chapter prefix, e.g. ch13> [max seconds, default 300]
# (resumes from the checkpoint the chapter loads itself, stops at the next chapter's mark, a failure or the time limit; prints the result and the time)
AR=/c/Users/Joel/grim_tools/autorun
L="/c/GOG Games/GRIMDATA/grimdebug.log"
fps="$1"; ch="$2"; max="${3:-300}"
slot=$(grep -h -m1 -o 'ar_load([0-9]*)' "$AR"/$ch*.lua | head -1 | sed 's/[^0-9]//g')
next=$(ls "$AR"/ch*.lua | sed 's|.*/\(ch[0-9]*\).*|\1|' | sort -u | awk -v c="$ch" '$0 > c { print; exit }')
taskkill //F //IM GRIMFANDANGO.exe > /dev/null 2>&1
start=$(date +%s)
(GRIM_FPS=$fps sh "$AR/resume_original.sh" "$slot" "$ch" > "$AR/logs/orig_try.out" 2>&1 &)
# (the log of the run before is emptied when the game starts: look only after the injection of this one)
: > "$L"
until grep -aq "running autorun_all.lua" "$L" 2>/dev/null || [ $(( $(date +%s) - start )) -ge 120 ]; do sleep 2; done
start=$(date +%s)
res="time limit"
while [ $(( $(date +%s) - start )) -lt "$max" ]; do
	sleep 3
	if grep -aq "=== chapter $next" "$L" 2>/dev/null; then res="PASSED"; break; fi
	if grep -aq "AUTORUN FAIL" "$L" 2>/dev/null; then res="FAILED: $(grep -a 'AUTORUN FAIL' "$L" | head -1 | cut -c1-120)"; break; fi
done
echo "fps $fps $ch: $res after $(( $(date +%s) - start )) s"
cp "$L" "$AR/logs/orig_try_${ch}_$fps.log"
taskkill //F //IM GRIMFANDANGO.exe > /dev/null 2>&1
