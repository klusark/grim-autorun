#!/bin/sh
# sends a whole Lua file to the running game (see rl.sh)
D=/c/Users/Joel/grim_tools/autorun/remote
rm -f $D/cmd.out
cp "$1" $D/cmd.tmp.lua && mv $D/cmd.tmp.lua $D/cmd.lua
i=0; while [ ! -f $D/cmd.out ] && [ $i -lt 600 ]; do sleep 0.2; i=$((i+1)); done
cat $D/cmd.out 2>/dev/null; echo
