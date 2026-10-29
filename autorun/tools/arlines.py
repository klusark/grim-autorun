#!/usr/bin/env python3
"""Lists the AUTORUN lines of one chapter of a frame-trace log with the frame (FT counter) they were printed in, to compare the timing of the autorun
steps of two engines:  arlines.py <log> <chapter prefix> [max lines]"""
import re, sys
log, ch = sys.argv[1], sys.argv[2]
mx = int(sys.argv[3]) if len(sys.argv) > 3 else 60
inch = False
base = None
fr = 0
n = 0
for l in open(log, errors="ignore"):
    m = re.search(r"=== chapter (\S+) ===", l)
    if m:
        inch = m.group(1).startswith(ch)
        base = None
        continue
    if not inch:
        continue
    m = re.search(r"FT (\d+) ", l)
    if m:
        fr = int(m.group(1))
        if base is None:
            base = fr
        continue
    if "AUTORUN" in l:
        t = re.sub(r"[0-9A-F]{8,16}", "PTR", l.split("AUTORUN", 1)[1].strip())
        print("%6d %s" % (fr - (base or 0), t[:110]))
        n += 1
        if n >= mx:
            break
