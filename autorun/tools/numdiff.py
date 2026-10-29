#!/usr/bin/env python3
"""Compares two text files line by line; the numbers in them may differ by the tolerance (default 2e-4), the rest of the line must be the same.
   numdiff.py a b [tolerance]   -> prints the lines that differ, exit code 1 when there are any"""
import re
import sys

num = re.compile(r"-?\d+\.\d+")
a = open(sys.argv[1], errors="ignore").read().splitlines()
b = open(sys.argv[2], errors="ignore").read().splitlines()
tol = float(sys.argv[3]) if len(sys.argv) > 3 else 2e-4
bad = 0
if len(a) != len(b):
    print("different number of lines: %d / %d" % (len(a), len(b)))
    bad += 1
for i, (x, y) in enumerate(zip(a, b)):
    if num.sub("#", x) != num.sub("#", y) or any(abs(float(p) - float(q)) > tol for p, q in zip(num.findall(x), num.findall(y))):
        print("line %d:\n  %s\n  %s" % (i + 1, x, y))
        bad += 1
sys.exit(1 if bad else 0)
