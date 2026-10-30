#!/usr/bin/env python3
"""Pass-through for the output of a run: writes every AUTORUN line, with the milliseconds of the wall clock since the start, to a side file.

  scummvm ... | python logts.py <side file> | ...

tools/gaps.py lists the stretches of the run with no AUTORUN line.
"""
import sys
import time

side = open(sys.argv[1], "w", encoding="utf-8", errors="replace", newline="\n")
out = sys.stdout.buffer
t0 = time.monotonic()
for raw in sys.stdin.buffer:
    out.write(raw)
    out.flush()
    if b"AUTORUN" in raw:
        ms = int((time.monotonic() - t0) * 1000)
        side.write("%d\t%s\n" % (ms, raw.decode("utf-8", "replace").rstrip()[:300]))
        side.flush()
side.close()
