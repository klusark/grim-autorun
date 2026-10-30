#!/bin/sh
# Random sets for the planner and the follower: sh synth/fuzz.sh [seed [count]]
cd "$(dirname "$0")/.." || exit 1
exec lua5.1 synth/fuzz.lua "$@"
