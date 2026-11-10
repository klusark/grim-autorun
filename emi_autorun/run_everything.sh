#!/bin/sh
# The whole game with one command: new game to the end of the credits (run_whole.sh: one process through all four acts, restarted from the
# checkpoint before a chapter that fails). About 10 minutes of real time. The old way (each act in its own run) is run_act1_seq.sh, run_all_act2.sh,
# run_all_act3.sh (Act 4 is in run_single.sh: act4_26, act4_27; the act4 runners are gone).
exec /c/Users/Joel/grim_tools/emi_autorun/run_whole.sh "$@"
