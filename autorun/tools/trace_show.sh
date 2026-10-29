#!/bin/sh
# Positions of a traced walk (NAVTRACE lines, see AR_NT_WTRACE in test_nav.lua) every N frames, from a log of either engine:
#   sh tools/trace_show.sh <log> <case id> [every N frames, default 45] [first line, default 1] [last line, default 40]
log="$1"
id="$2"
every="${3:-45}"
from="${4:-1}"
to="${5:-40}"
grep -a "NAVTRACE $id " "$log" | grep -v AUTORUN | sed "s/.*NAVTRACE $id //" | awk -v e="$every" '{ if ($1 % e == 1) print $1, $2, $3, $4 }' | sed -n "${from},${to}p" | tr '\n' ';'
echo
