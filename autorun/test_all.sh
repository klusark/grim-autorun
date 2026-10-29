#!/bin/sh
# The navigation tests, all tiers: sh test_all.sh [offline] [scummvm] [original] [flaky]  (see tools/test_all.py)
exec python "$(dirname "$0")/tools/test_all.py" "$@"
