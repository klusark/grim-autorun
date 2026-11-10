#!/bin/bash
# The ScummVM runs of the suite all at once: each game and renderer is its own run.py scummvm, in its own --work folder
# (its own build/, run/ and logs/ under run/parallel/; nothing is written to expected/: a crasher it finds is reported only).
#
#   tools/parallel.sh [--games grim,emi,remastered] [--renderers opengl,opengl_shaders,software] [run.py options...]
#       a quick check with the usual build ($SCUMMVM, or run.py's default); games default grim,emi
#   tools/parallel.sh --coverage [build dir] [...]
#       the coverage: the gcov build (default ~/scummvm-cleanroom/build-cov, README.md "Coverage of ScummVM"), its counters
#       cleared first, every game by default, then autorun/tools/covreport.py --all into reports/coverage/
#   (other options go to every run.py: --only T1,T2, --fresh, --visible)
#
# Each run's output: run/parallel/<game>_<renderer>.txt, its logs in run/parallel/<game>_<renderer>/logs/. Exits 1 when a
# Grim or EMI run has a regression (the Remastered mode is a report only). CR_STALL defaults to 15 here (2 in run.py): nine
# engines at once make the machine busy, and a test quiet for 2 s would be killed as hung.
HERE=$(cd "$(dirname "$0")/.." && pwd)
GAMES=grim,emi
RENDERERS=opengl,opengl_shaders,software
COV=
GAMES_SET=
ARGS=()
while [ $# -gt 0 ]; do
	case $1 in
		--coverage)
			COV=$HOME/scummvm-cleanroom/build-cov
			if [ -n "$2" ] && [ "${2#--}" = "$2" ]; then COV=$2; shift; fi ;;
		--games) GAMES=$2; GAMES_SET=1; shift ;;
		--renderers) RENDERERS=$2; shift ;;
		*) ARGS+=("$1") ;;
	esac
	shift
done
[ -n "$COV" ] && [ -z "$GAMES_SET" ] && GAMES=grim,emi,remastered
WORK=$HERE/run/parallel
cd "$HERE" || exit 1
export CR_STALL=${CR_STALL:-15}
if [ -n "$COV" ]; then
	COV=$(cd "$COV" && pwd) || exit 1
	export SCUMMVM="$(cygpath -w "$COV/scummvm.exe")" CR_STALL=${CR_STALL_COV:-60} CR_STARTUP=${CR_STARTUP:-120}
	find "$COV" -name '*.gcda' -delete
fi
rm -rf "$WORK"
mkdir -p "$WORK"
start=$(date +%s)
for game in ${GAMES//,/ }; do
	case $game in
		grim) opt=() ;;
		emi) opt=(--game emi) ;;
		remastered) opt=(--remastered) ;;
		*) echo "unknown game $game"; exit 2 ;;
	esac
	for r in ${RENDERERS//,/ }; do
		python run.py scummvm "${opt[@]}" --renderer "$r" --work "$(cygpath -w "$WORK/${game}_$r")" "${ARGS[@]}" \
			> "$WORK/${game}_$r.txt" 2>&1 &
	done
done
wait
echo "ran in $(( $(date +%s) - start )) s"
rc=0
for f in "$WORK"/*.txt; do
	name=$(basename "$f" .txt)
	line=$(grep -h 'regressions' "$f" | tail -1)
	echo "$name: ${line:-no result (see $f)}"
	grep -h 'crashed or hung ScummVM' "$f" | sed 's/^/    /'
	case $name in
		remastered_*) ;;
		*) case $line in "0 of "*) ;; *) rc=1 ;; esac ;;
	esac
done
if [ -n "$COV" ]; then
	repo=$(cd "$COV/.." && pwd)
	python "$HERE/../autorun/tools/covreport.py" "$(cygpath -w "$HERE/reports/coverage")" "$(cygpath -w "$COV")" "$(cygpath -w "$repo")" --all \
		--title "the clean-room tests ($GAMES; $RENDERERS) on $(git -C "$repo" rev-parse --short HEAD)" > "$WORK/covreport.txt" 2>&1
	head -6 "$HERE/reports/coverage/summary.txt"
fi
exit $rc
