#!/bin/bash
# Builds the patched ScummVM of grim_tools locally: the one engine of the autoruns (autorun/, emi_autorun/: SVM=patched) and
# the clean-room tests (cleanroom/run.py's default SCUMMVM). Run it from an MSYS2 UCRT64 login shell:
#
#   MSYSTEM=UCRT64 bash -l scummvm/build.sh [--gcov] [--lua-coverage] [--ref REF] [worktree]
#
#   worktree        default ~/scummvm-patched; made from ~/scummvm-autorun's repository (SVM_REPO) on REF when it does not
#                   exist (default origin/master, fetched first), then prepare.sh (grim-tools.patch)
#   --gcov          the coverage build, build-cov (configure.sh gcov); otherwise build-opt (configure.sh release)
#   --asan          the AddressSanitizer build, build-asan (configure.sh asan; Linux/WSL, worktree ~/scummvm-wsl there)
#   --valgrind      the build for valgrind, build-vg (configure.sh valgrind; Linux/WSL)
#   --lua-coverage  lua-coverage.patch too (a worktree of its own is best: the patch stays in the worktree)
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
		--asan) MODE=asan ;;
		--valgrind) MODE=valgrind ;;
		--lua-coverage) PREP+=(--lua-coverage) ;;
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
case $MODE in gcov) BUILD=$W/build-cov ;; asan) BUILD=$W/build-asan ;; valgrind) BUILD=$W/build-vg ;; *) BUILD=$W/build-opt ;; esac
cd "$W"
[ -f "$BUILD/config.mk" ] || bash "$HERE/configure.sh" "$MODE" "$BUILD"
cd "$BUILD"
make -j"${JOBS:-$(nproc)}" 2>&1 | grep -E 'error:|Error [0-9]' | head -20 || true
make -j"${JOBS:-$(nproc)}" 2>&1 | tail -2
ls -la "$BUILD"/scummvm "$BUILD"/scummvm.exe 2>/dev/null || true
