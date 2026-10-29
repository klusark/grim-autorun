#!/bin/sh
# show.sh logname [pattern]: the useful lines of a log
grep -a "AUTORUN\|rror" logs/$1.log | grep -a -v "Starting wait\|Waited\|__autorun__" | grep -a "${2:-.}" | cut -c1-${W:-240}
