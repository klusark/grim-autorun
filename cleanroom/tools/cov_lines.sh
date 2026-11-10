#!/bin/bash
# Which lines of one ScummVM source file some tests run: the tests on the gcov build (README.md "Coverage of ScummVM")
# with counters of their own (GCOV_PREFIX: nothing is added to the build's .gcda files, so runs side by side do not mix),
# then gcov on that file.
#
#   tools/cov_lines.sh <work folder> <source, e.g. engines/grim/actor.cpp> [run.py scummvm options: --only T1,T2, --game emi, --renderer R...]
#
# Writes <work folder>/<file>.gcov (gcov -t: "count:line:source", "#####" for a line never run, "-" for no code) and prints
# how many of the file's lines ran. Look up the lines you want with
#   awk -F: '$2+0 >= 2410 && $2+0 <= 2441' <work folder>/actor.cpp.gcov
# The renderer defaults to opengl (one run); CR_STALL to 60 (the gcov build is slow).
HERE=$(cd "$(dirname "$0")/.." && pwd)
WORK=$1
SRC=$2
shift 2 || { sed -n 2,12p "$0"; exit 2; }
BUILDDIR=${CR_COV_BUILD:-$HOME/scummvm-cleanroom/build-cov}
REPO=$(cd "$BUILDDIR/.." && pwd)
mkdir -p "$WORK"
WORK=$(cd "$WORK" && pwd)
rm -rf "$WORK/gcda"
# (the .gcda of a file is written at its object's path: strip every folder of the build's path, so that they land under
# the prefix as engines/grim/actor.gcda)
strip=$(cygpath -m "$BUILDDIR" | tr '/' '\n' | grep -c .)
args=("$@")
case " ${args[*]} " in *" --renderer "*) ;; *) args+=(--renderer opengl) ;; esac
(cd "$HERE" && GCOV_PREFIX="$(cygpath -w "$WORK/gcda")" GCOV_PREFIX_STRIP=$strip SCUMMVM="$(cygpath -w "$BUILDDIR/scummvm.exe")" \
	CR_STALL=${CR_STALL:-60} CR_STARTUP=${CR_STARTUP:-120} python run.py scummvm --work "$(cygpath -w "$WORK/run")" "${args[@]}") \
	> "$WORK/run.txt" 2>&1
grep -h "regressions\|crashed or hung" "$WORK/run.txt"
obj=$(dirname "$SRC")/$(basename "${SRC%.*}")
if [ ! -f "$WORK/gcda/$obj.gcda" ]; then
	echo "no counters for $SRC (see $WORK/run.txt)"
	exit 1
fi
cp "$BUILDDIR/$obj.gcno" "$WORK/gcda/$obj.gcno"
out=$WORK/$(basename "$SRC").gcov
(cd "$BUILDDIR" && gcov -t -o "$(cygpath -w "$WORK/gcda/$(dirname "$SRC")")" "$(cygpath -w "$REPO/$SRC")" 2>/dev/null) |
	awk -v want="../$SRC" '/^ *-: *0:Source:/ { on = (substr($0, index($0, "Source:") + 7) == want); next } on' |
	sed 's/^ *//' > "$out"
run=$(grep -c '^[0-9]' "$out")
never=$(grep -c '^#####' "$out")
echo "$SRC: $run of $((run + never)) lines run by these tests ($out)"
