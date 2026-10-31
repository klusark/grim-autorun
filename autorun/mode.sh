# Sourced by run_all.sh, run_chapter.sh and build_original.sh: MODE=<name> sets the variables the scripts already know (see MODES_PLAN.md).
#   speed (default)  cutscenes skipped, every line skipped with the skip key, text only, the minimum of the story
#   text             as speed, but the lines last as long as their text says (what the frame comparisons are made with)
#   full             nothing skipped, voices on (REAL=1)
#   speed100         as speed, and everything there is to do (FULL=1: the extras of the ex*.lua files)
#   full100          as full, and everything there is to do
case "${MODE:-speed}" in
	speed) ;;
	text) NOSKIPLINES=1 ;;
	full) REAL=1 ;;
	speed100) FULL=1 ;;
	full100) REAL=1; FULL=1 ;;
	*) echo "MODE must be speed, text, full, speed100 or full100" >&2; exit 1 ;;
esac
# (a frame capture wants the text on the screen for as long as it lasts, a real run wants the lines to the end)
[ -n "$FRAMES" ] && NOSKIPLINES=1
[ -n "$REAL" ] && NOSKIPLINES=1
# MODE_LUA: the lines the generated script starts with
MODE_LUA="AR_MODE = \"${MODE:-speed}\""
[ -n "$REAL" ] && MODE_LUA="$MODE_LUA
AR_REAL = TRUE"
[ -n "$FULL" ] && MODE_LUA="$MODE_LUA
AR_FULL = TRUE"
[ -z "$NOSKIPLINES" ] && MODE_LUA="$MODE_LUA
AR_SKIPLINES = TRUE"
[ -n "$REALTIME" ] && MODE_LUA="$MODE_LUA
AR_NOTIMEOUT = TRUE"
# NAVDEBUG=1: the nav is drawn on the screen (ar_navdebug.lua)
[ -n "$NAVDEBUG" ] && MODE_LUA="$MODE_LUA
AR_NAVDEBUG = TRUE"
# SPEEDLOG=1: the movement of Manny as segments of stop, walk and run (ar_navdebug.lua)
[ -n "$SPEEDLOG" ] && MODE_LUA="$MODE_LUA
AR_SPEEDLOG = TRUE"
# the 100% modes keep their own saves and logs (their checkpoints hold a different game). The real modes (full, full100) save their checkpoints by default: a
# run of hours has to be able to replay the chapter that failed alone (SAVE= with nothing turns it off, but chapter 64 of mode full is held up in the
# meadow without the save: the menu mode of the save changes how much game time passes between the chapters)
if [ -n "$MODE" ]; then
	: "${LOG:=$MODE}"
	[ -n "$FULL" ] || [ -n "$REAL" ] && : "${SAVES:=$AR/saves_$MODE}"
fi
[ -n "$REAL" ] && : "${SAVE:=1}"
true
