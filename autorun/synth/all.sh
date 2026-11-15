#!/bin/sh
# Everything that needs no game data: the checks of the planner and follower, 200 random sets, and the python tools. Under a minute.
cd "$(dirname "$0")/.." || exit 1
status=0
# LUA=<interpreter>: lua5.1 by default, luajit where lua5.1 is not installed (both are Lua 5.1)
if [ -z "$LUA" ]; then
	if command -v lua5.1 >/dev/null 2>&1; then LUA=lua5.1; else LUA=luajit; fi
fi
$LUA synth/run.lua || status=1
$LUA synth/fuzz.lua 1 ${FUZZ:-200} || status=1
# (the dialog walker of the 100% modes)
$LUA synth/test_talk.lua || status=1
python synth/test_tools.py || status=1
exit $status
