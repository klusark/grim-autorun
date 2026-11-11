#!/bin/sh
# Builds the autorun engine for both Grim (autorun/) and EMI (emi_autorun/): worktree ~/scummvm-autorun, branch autorun
# (grim-actor-fixes, then cleanroom, linear on master), build-opt. Run from an MSYS2 UCRT64 login shell (see HANDOFF.md section 3).
mkdir -p /home/Joel/scummvm-autorun/build-opt && cd /home/Joel/scummvm-autorun/build-opt
if [ ! -f config.mk ]; then
	CXX="ccache g++" CC="ccache gcc" ../configure --disable-all-engines --enable-engines=grim,monkey4 --enable-release 2>&1 | tail -5
fi
make -j8 2>&1 | grep -E 'error|Error' | head -30
make -j8 2>&1 | tail -4
ls -la scummvm.exe
