#!/usr/bin/env python3
"""Turns the NAVCASE lines of a run (ar_nav.lua logs every plan with the set, where Manny stood and the goal) into test cases:
nav_cases_run.lua.   gen_cases.py logs/all_pass1.log [more logs]
A case is: the way from `from` to `to` in the set must exist, end at the goal, and be about as long as it was (within 40%).
Duplicates (the same set, start and goal to 30 cm) are dropped; so are plans of a few centimetres and the walks whose set the tables do
not know. In-game they run in the unit tier; offline (tools/lua31/run.sh) they run with the sector states the set file starts with."""
import re, sys

sets = {}
for line in open('ar_nav_sets.lua'):
    m = re.search(r'file = "(\w+)\.set", global = "(\w+)"', line)
    if m:
        sets[m.group(1)] = m.group(2)
seen = {}
cases = []
for path in sys.argv[1:]:
    for line in open(path, errors='replace'):
        m = re.search(r'NAVCASE (\w+)\.set from (-?[\d.]+) (-?[\d.]+) (-?[\d.]+) to (-?[\d.]+) (-?[\d.]+) (-?[\d.]+) len ([\d.]+) points (\d+)', line)
        if not m or m.group(1) not in sets:
            continue
        g = sets[m.group(1)]
        f = [float(m.group(i)) for i in (2, 3, 4)]
        t = [float(m.group(i)) for i in (5, 6, 7)]
        ln = float(m.group(8))
        if ln < 0.3:
            continue
        key = (g, round(f[0] / 0.3), round(f[1] / 0.3), round(t[0] / 0.3), round(t[1] / 0.3))
        if key in seen:
            continue
        seen[key] = 1
        cases.append((g, f, t, ln))
out = ['-- made by tools/gen_cases.py from the NAVCASE lines of a full run; do not edit', 'AR_RUN_CASES = {']
n = {}
for g, f, t, ln in cases:
    n[g] = n.get(g, 0) + 1
    out.append('\t{ id = "run_%s_%d", set = "%s", from = { %.3f, %.3f, %.3f }, to = { %.3f, %.3f, %.3f }, len = %.2f, tol = 0.2 },' % (g, n[g], g, f[0], f[1], f[2], t[0], t[1], t[2], ln))
out.append('}')
open('nav_cases_run.lua', 'w').write('\n'.join(out) + '\n')
print(len(cases), 'cases in', len(n), 'sets')
