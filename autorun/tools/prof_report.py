#!/usr/bin/env python3
"""The report of tools/sample_prof.sh:   python tools/prof_report.py <samples file> [top, default 25]
Counts, over the samples, the function the main thread was in (self) and the functions it was in or below (the first frames kept)."""
import re
import sys
from collections import Counter

path = sys.argv[1]
top = int(sys.argv[2]) if len(sys.argv) > 2 else 25
samples = []
cur = None
for line in open(path, encoding="utf-8", errors="replace"):
    if line.startswith("=== sample"):
        cur = []
        samples.append(cur)
    elif line.startswith("#") and cur is not None:
        m = re.match(r"#\d+\s+(?:0x[0-9a-f]+ in )?(.*?)\s*\(", line)
        cur.append((m.group(1) if m else line.strip())[:90])
samples = [s for s in samples if s]
selfc, incl = Counter(), Counter()
for s in samples:
    selfc[s[0]] += 1
    for f in set(s):
        incl[f] += 1
n = len(samples)
print("%d samples" % n)
print("--- in the function itself")
for f, c in selfc.most_common(top):
    print("%5.1f%%  %s" % (100.0 * c / n, f))
print("--- in it or below it")
for f, c in incl.most_common(top):
    print("%5.1f%%  %s" % (100.0 * c / n, f))
