#!/bin/sh
# Everything that needs no game data: the checks of the planner and follower, 200 random sets, and the python tools. Under a minute.
cd "$(dirname "$0")/.." || exit 1
status=0
lua5.1 synth/run.lua || status=1
lua5.1 synth/fuzz.lua 1 ${FUZZ:-200} || status=1
python synth/test_tools.py || status=1
exit $status
