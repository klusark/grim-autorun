#!/bin/sh
# Watches the iMuse heartbeat of the ORIGINAL (tools/audio_hb.py) and, when it has not run for 10 s, takes a tools/audio_snap.py snapshot into
# logs/audio_snap_<time>.txt (at most one every 2 minutes). A frozen iMuse (a leaked guard counter) hangs every wait for a sound; the log may keep
# growing (the autorun logs its waits), so the log is no sign of it.
AR=/c/Users/Joel/grim_tools/autorun
L="/c/GOG Games/GRIMDATA/grimdebug.log"
lastsnap=0
while true; do
	sleep 5
	tasklist | grep -qi GRIMFANDANGO || continue
	r=$(python3 "$AR/tools/audio_hb.py" 2>/dev/null)
	[ -z "$r" ] && continue
	age=${r% *}
	now=$(date +%s)
	if [ "$age" -gt 10000 ] && [ $(( now - lastsnap )) -gt 120 ]; then
		lastsnap=$now
		f="$AR/logs/audio_snap_$(date +%H%M%S).txt"
		{ echo "heartbeat age ${age} ms (counter ${r#* }), last chapter: $(grep -a '=== chapter' "$L" | tail -1 | cut -c1-80)"; echo "last log lines:"; grep -av "  wait:\|AUTORUN   follow" "$L" | tail -6 | cut -c1-200; python3 "$AR/tools/audio_snap.py"; } > "$f" 2>&1
		echo "snapshot $f"
	fi
done
