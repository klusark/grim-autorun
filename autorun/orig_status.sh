#!/bin/sh
L="/c/GOG Games/GRIMDATA/grimdebug.log"
grep -a "=== chapter" "$L" | tail -1 | cut -c1-100
grep -a "AUTORUN PASS\|AUTORUN FAIL\|RESULT" "$L" | tail -2 | cut -c1-140
tail -1 "$L" | cut -c1-120
tasklist //FI "IMAGENAME eq GRIMFANDANGO.exe" | tail -1 | cut -c1-60
