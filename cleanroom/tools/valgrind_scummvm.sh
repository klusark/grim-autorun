#!/bin/bash
# ScummVM under valgrind, for run.py on Linux: SCUMMVM=tools/valgrind_scummvm.sh. The first memory error ends ScummVM (exit 99),
# so run.py counts the test running then as a crasher (expected/*scummvm_crashers_<renderer>.txt). The valgrind report is
# appended to ScummVM's --logfile (run.py keeps it in logs/crashes/) and kept in $VG_LOGS.
# Valgrind is slow: CR_STALL=180 CR_STARTUP=600 CR_GAMES=<cores>. VG_EXE: the ScummVM build (with -g); VG_SUPP: suppressions.
EXE=${VG_EXE:-$HOME/scummvm-cleanroom/build/scummvm}
VG_LOGS=${VG_LOGS:-/tmp/vglogs}; mkdir -p "$VG_LOGS"
# (the OpenGL shaders: an uninstalled build looks for shaders/ under extrapath)
SRC=$(dirname "$(dirname "$EXE")"); mkdir -p "$VG_LOGS/extra"; ln -sfn "$SRC/engines/grim/shaders" "$VG_LOGS/extra/shaders"
LOG=""; for a in "$@"; do case "$a" in --logfile=*) LOG="${a#--logfile=}";; esac; done
VL="$VG_LOGS/vg.$$.log"
SDL_AUDIODRIVER=dummy valgrind --error-exitcode=99 --exit-on-first-error=yes --leak-check=no --num-callers=30 \
  ${VG_SUPP:+--suppressions=$VG_SUPP} --log-file="$VL" "$EXE" --extrapath="$VG_LOGS/extra" "$@"
rc=$?
if [ $rc = 99 ] && [ -n "$LOG" ]; then
  t=$(grep -o "CR BEGIN [^ ]*" "$LOG" | tail -1); echo "TEST: $t" >> "$VL"
  { echo "==== valgrind"; cat "$VL"; } >> "$LOG"
else
  rm -f "$VL"
fi
exit $rc
