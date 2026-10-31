#!/usr/bin/env python
"""Sum the SPEED lines of a log (SPEEDLOG=1): frames by class where the autorun has the control, and the longest segments that are not a run.
usage: speedsum.py <log> [n]"""
import re, sys
rows = []
for l in open(sys.argv[1], errors='replace'):
    m = re.search(r'SPEED (stop|walk|run)\s+(\d+) frames (.*?) \(([-\d. ]+)\) -> \(([-\d. ]+)\) ([\d.]+) m, control (\S+), (.*)', l)
    if m:
        rows.append((m.group(1), int(m.group(2)), m.group(3), m.group(4), m.group(5), float(m.group(6)), m.group(7), m.group(8).strip()))
tot = {'stop': 0, 'walk': 0, 'run': 0}
for r in rows:
    if r[6] == '1':
        tot[r[0]] += r[1]
print('under the autorun control: stop %d walk %d run %d frames' % (tot['stop'], tot['walk'], tot['run']))
n = int(sys.argv[2]) if len(sys.argv) > 2 else 12
bad = sorted([r for r in rows if r[6] == '1' and r[0] != 'run'], key=lambda r: -r[1])[:n]
for r in bad:
    print('%-4s %3d frames %s (%s) -> (%s) %s' % (r[0], r[1], r[2], r[3], r[4], r[7]))
