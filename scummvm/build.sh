#!/bin/bash
# Builds the patched ScummVM of grim_tools locally: the one engine of the autoruns (autorun/, emi_autorun/: SVM=patched) and
# the clean-room tests (cleanroom/run.py's default SCUMMVM). Run it from an MSYS2 UCRT64 login shell:
#
#   MSYSTEM=UCRT64 bash -l scummvm/build.sh [--gcov] [--lua-coverage] [--emi-walk] [--ref REF] [worktree]
#
#   worktree        default ~/scummvm-patched; made from ~/scummvm-autorun's repository (SVM_REPO) on REF when it does not
#                   exist (default origin/master, fetched first), then prepare.sh (grim-tools.patch)
#   --gcov          the coverage build, build-cov (configure.sh gcov); otherwise build-opt (configure.sh release)
#   --lua-coverage  lua-coverage.patch too (a worktree of its own is best: the patch stays in the worktree)
#   --emi-walk      emi-walk.patch too (Monkey4.exe's walker, for the EMI whole run; a worktree of its own is best)
#   --ref REF       the commit a new worktree starts from
# To build on a newer master: remove the worktree (git worktree remove ~/scummvm-patched) and run this again.
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
MODE=release
PREP=()
REF=origin/master
W=
while [ $# -gt 0 ]; do
	case $1 in
		--gcov) MODE=gcov ;;
		--lua-coverage) PREP+=(--lua-coverage) ;;
		--emi-walk) PREP+=(--emi-walk) ;;
		--ref) REF=$2; shift ;;
		*) W=$1 ;;
	esac
	shift
done
W=${W:-$HOME/scummvm-patched}
REPO=${SVM_REPO:-$HOME/scummvm-autorun}
if [ ! -d "$W" ]; then
	[ "$REF" = origin/master ] && git -C "$REPO" fetch -q origin master
	git -C "$REPO" worktree add --detach "$W" "$REF"
fi
bash "$HERE/prepare.sh" "${PREP[@]}" "$W"
BUILD=$W/$([ "$MODE" = gcov ] && echo build-cov || echo build-opt)
cd "$W"
[ -f "$BUILD/config.mk" ] || bash "$HERE/configure.sh" "$MODE" "$BUILD"
cd "$BUILD"
make -j"${JOBS:-$(nproc)}" 2>&1 | grep -E 'error:|Error [0-9]' | head -20 || true
make -j"${JOBS:-$(nproc)}" 2>&1 | tail -2
ls -la "$BUILD/scummvm.exe"
