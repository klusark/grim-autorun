#!/bin/bash
# Configures a build folder of a prepared ScummVM checkout (prepare.sh), the same way locally and in CI:
#
#   configure.sh release|gcov [build folder, default ./build]   (run in the checkout; the folder can be anywhere)
#
#   release  --enable-release (-O2): the autoruns and the clean-room tests
#   gcov     --coverage -O0, and -DCR_GCOV: grim-tools.patch writes the counters at exit and when the tests ask (CRGCOV),
#            for cleanroom/tools/parallel.sh --coverage and .github/workflows/scummvm-coverage.yml
# Only Grim and EMI, through ccache, without the network, cloud, update and text-to-speech parts nothing here uses.
set -e
MODE=${1:?release or gcov}
BUILD=${2:-build}
SRC=$(pwd)
mkdir -p "$BUILD"
cd "$BUILD"
COMMON=(--disable-all-engines --enable-engines=grim,monkey4 --disable-libcurl --disable-sdlnet --disable-cloud --disable-updates --disable-tts)
case $MODE in
	release)
		CXX="ccache g++" CC="ccache gcc" "$SRC/configure" "${COMMON[@]}" --enable-release ;;
	gcov)
		CXX="ccache g++" CC="ccache gcc" CXXFLAGS="--coverage -fprofile-update=atomic -O0" LDFLAGS="--coverage -fprofile-update=atomic" \
			"$SRC/configure" "${COMMON[@]}"
		sed -i 's/^CXXFLAGS := \(.*\)$/CXXFLAGS := \1 -DCR_GCOV/' config.mk ;;
	*)
		echo "configure.sh: release or gcov, not $MODE" >&2
		exit 1 ;;
esac
