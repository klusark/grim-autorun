#!/bin/bash
# Gets a ScummVM checkout ready to build for grim_tools (the autoruns, autorun/ and emi_autorun/, and the clean-room tests,
# cleanroom/), locally (build.sh) and in CI (.github/workflows/scummvm-*.yml):
#
#   prepare.sh [--no-patch] [--lua-coverage] [checkout, default .]
#
#   grim-tools.patch    always (unless --no-patch: a branch that has it already): --autorun, --sim-fps and sim_frame_ms (the
#                       simulated clock), sim_render_every, SCUMMVM_LUA_REMOTE, and the clean-room test data (GF_TESTDATA,
#                       CRSNAP, CRGCOV, the crash dumps); made on upstream master
#   lua-coverage.patch  with --lua-coverage: which functions, lines and instructions of the scripts ran (GRIM_LUA_COVERAGE)
#
# A patch already applied is left as it is, so it can be run again on the same checkout. Exits 1 when a patch does not apply.
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
PATCHES=("$HERE/grim-tools.patch")
DIR=.
while [ $# -gt 0 ]; do
	case $1 in
		--no-patch) PATCHES=() ;;
		--lua-coverage) PATCHES+=("$HERE/lua-coverage.patch") ;;
		*) DIR=$1 ;;
	esac
	shift
done
cd "$DIR"
for p in "${PATCHES[@]}"; do
	if git apply --reverse --check "$p" 2>/dev/null; then
		echo "$(basename "$p"): applied already"
	elif git apply "$p"; then
		echo "$(basename "$p"): applied"
	else
		echo "$(basename "$p") does not apply to $(git log --oneline -1)" >&2
		exit 1
	fi
done
