#!/bin/sh
# Runs test_nav.lua in the ORIGINAL game (from the save in slot 19), waits for the end and closes the game; the log is copied to
# logs/orig_tn_full.log (the NAVTEST lines are in it).   Part of the cases: sh orig_test.sh <file made of switches + test_nav.lua>
AR=/c/Users/Joel/grim_tools/autorun
sh "$AR/orig_test.sh" "$AR/test_nav.lua" 3000 "$AR/logs/orig_tn_full.log"
