#!/bin/sh
# The tests that need no game data and no ScummVM: the planner and the follower of ar_nav.lua on the synthetic sets of synth/sets, in Lua 5.1
# (pacman -S mingw-w64-ucrt-x86_64-lua51). One name part as the argument runs the checks with that in their name.
#   AR_NAV_FILE=<file> sh synth/run.sh        the same checks on another copy of ar_nav.lua (to see that a check fails on the code before a fix)
cd "$(dirname "$0")/.." || exit 1
exec lua5.1 synth/run.lua "$@"
