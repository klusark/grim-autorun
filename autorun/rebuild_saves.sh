#!/bin/sh
# Rebuilds the checkpoint saves in ./saves by playing the chapters one after the other (the
# first starts a new game, each other one loads the save the one before wrote).
# Stops at the first chapter that does not pass. Run from an MSYS2 UCRT64 shell.

AR=/c/Users/Joel/grim_tools/autorun
cd "$AR" || exit 1
for f in "$AR"/ch*.lua; do
	ch=$(basename "$f" .lua)
	echo "== $ch"
	sh run_chapter.sh "$f" 900 > /dev/null
	if ! grep -q "RESULT PASSED" "logs/$ch.log"; then
		echo "$ch did not pass, see logs/$ch.log"
		exit 1
	fi
done
echo "all saves rebuilt"
ls -l saves
