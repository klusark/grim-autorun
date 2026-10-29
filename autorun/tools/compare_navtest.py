#!/usr/bin/env python3
"""Compares the NAVTEST lines of two logs (say ScummVM's test_nav.log and the original's grimdebug.log) case by case.
Usage: compare_navtest.py a.log b.log [mode]   -- prints the cases that PASS in one and FAIL (or are missing) in the other."""
import re, sys

def read(path):
    r = {}
    for line in open(path, errors='replace'):
        m = re.search(r'NAVTEST (unit|walk|move|coll) (\S+) (PASS|FAIL|KNOWN) ?(.*)', line)
        if m and 'AUTORUN' not in line.split('NAVTEST')[0]:
            r[(m.group(1), m.group(2))] = (m.group(3), m.group(4)[:100])
    return r

a = read(sys.argv[1])
b = read(sys.argv[2])
mode = sys.argv[3] if len(sys.argv) > 3 else None
same = 0
diff = 0
for k in sorted(set(a) | set(b)):
    if mode and k[0] != mode:
        continue
    ra = a.get(k)
    rb = b.get(k)
    if ra and rb and ra[0] == rb[0]:
        same += 1
        continue
    diff += 1
    print('%s %s: A=%s B=%s' % (k[0], k[1], ra and ra[0] or 'missing', rb and rb[0] or 'missing'))
    if ra and ra[0] == 'FAIL':
        print('    A: ' + ra[1])
    if rb and rb[0] == 'FAIL':
        print('    B: ' + rb[1])
print('%d the same, %d different' % (same, diff))
