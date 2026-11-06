#!/bin/sh
# Builds the ScummVM the clean-room tests use by default: a worktree at ~/scummvm-cleanroom (upstream master,
# or any branch, with grim-test-data.patch applied), configured like build-opt. Run it from an MSYS2 UCRT64 login shell:
#   MSYSTEM=UCRT64 bash -l cleanroom/scummvm/build.sh [worktree]
W="${1:-$HOME/scummvm-cleanroom}"
mkdir -p "$W/build" && cd "$W/build" || exit 1
[ -f config.mk ] || ../configure --disable-all-engines --enable-engines=grim,monkey4 --enable-release || exit 1
make -j8 2>&1 | tail -5
