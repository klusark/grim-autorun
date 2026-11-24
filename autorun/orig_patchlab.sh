# Sourced by every script that starts the ORIGINAL game (or the rebuilt one): the original always plays ScummVM's script patches.
# patchlab/DATAUSR.LAB (tools/mk_patchlab.py: every .patchr of ScummVM's grim-patch.lab applied to the game's files) is put into GRIMDATA,
# where the game loads it before its own LABs, and taken out again when the game has gone. ScummVM loads every *.lab of GRIMDATA too,
# so the lab must not stay there: run_all.sh and run_chapter.sh refuse to start while it is.
#   patchlab_install       fails (exit 1) when the lab is missing, older than ScummVM's grim-patch.lab, or another DATAUSR.LAB is in GRIMDATA
#   patchlab_remove        takes it out (only our own lab, once no GRIMFANDANGO.exe is running; waits up to 30 s for the game to go)
PL_AR=/c/Users/Joel/grim_tools/autorun
PL_GD="/c/GOG Games/GRIMDATA"
PL_LAB="$PL_AR/patchlab/DATAUSR.LAB"
PL_SRC="${PATCHLAB_SRC:-$HOME/scummvm-autorun/dists/engine-data/grim-patch.lab}"

patchlab_install() {
	if [ ! -f "$PL_LAB" ]; then
		echo "ERROR: the patch lab $PL_LAB is missing: the original must run with ScummVM's script patches. Build it with: python $PL_AR/tools/mk_patchlab.py" >&2
		exit 1
	fi
	if [ -f "$PL_SRC" ] && [ "$PL_SRC" -nt "$PL_LAB" ]; then
		echo "ERROR: the patch lab $PL_LAB is older than $PL_SRC. Rebuild it with: python $PL_AR/tools/mk_patchlab.py" >&2
		exit 1
	fi
	if [ -e "$PL_GD/DATAUSR.LAB" ]; then
		cmp -s "$PL_GD/DATAUSR.LAB" "$PL_LAB" && return 0
		echo "ERROR: GRIMDATA has a DATAUSR.LAB that is not the patch lab: take it out first" >&2
		exit 1
	fi
	cp "$PL_LAB" "$PL_GD/DATAUSR.LAB" || { echo "ERROR: cannot copy the patch lab into GRIMDATA" >&2; exit 1; }
}

patchlab_remove() {
	local w=0
	while tasklist | grep -qi GRIMFANDANGO && [ $w -lt 30 ]; do sleep 2; w=$((w + 2)); done
	tasklist | grep -qi GRIMFANDANGO && return 0
	[ -e "$PL_GD/DATAUSR.LAB" ] && cmp -s "$PL_GD/DATAUSR.LAB" "$PL_LAB" && rm -f "$PL_GD/DATAUSR.LAB"
	return 0
}
