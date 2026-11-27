#!/bin/bash
# Configures a build folder of a prepared ScummVM checkout (prepare.sh), the same way locally and in CI:
#
#   configure.sh release|gcov|asan [build folder, default ./build]   (run in the checkout; the folder can be anywhere)
#
#   release  --enable-release (-O2): the autoruns and the clean-room tests
#   gcov     --coverage -O0, and -DCR_GCOV: grim-tools.patch writes the counters at exit and when the tests ask (CRGCOV),
#            for cleanroom/tools/parallel.sh --coverage and .github/workflows/scummvm-coverage.yml
#   asan     -fsanitize=address,undefined -O1 -g: the memory checks of a run (Linux/WSL only: autorun/run_all.sh ASAN=1)
#   valgrind -O1 -g, no sanitizers: a run under valgrind (Linux/WSL only: autorun/run_all.sh VALGRIND=1)
# Only Grim and EMI, through ccache, without the network, cloud, update and text-to-speech parts nothing here uses.
set -e
MODE=${1:?release, gcov, asan or valgrind}
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
	asan)
		CXX="ccache g++" CC="ccache gcc" CXXFLAGS="-fsanitize=address,undefined -fno-omit-frame-pointer -O1 -g" \
			LDFLAGS="-fsanitize=address,undefined" "$SRC/configure" "${COMMON[@]}" ;;
	valgrind)
		CXX="ccache g++" CC="ccache gcc" CXXFLAGS="-fno-omit-frame-pointer -O1 -g" "$SRC/configure" "${COMMON[@]}" ;;
	*)
		echo "configure.sh: release, gcov, asan or valgrind, not $MODE" >&2
		exit 1 ;;
esac
