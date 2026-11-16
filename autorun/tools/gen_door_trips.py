#!/usr/bin/env python
"""Writes ex06_doors.lua from a Lua coverage report (tools/luacov.py --json): the doors whose walkOut the run never called, for door trips
(ar_door_trips, ar_full.lua). A door is "<set global>.<set global of the target>_door" with a set of catalog.json as the target; the other
walkOuts (trigger boxes: ac.drift_trigger, nl.retreat) are no doors and are left out.

  python tools/gen_door_trips.py <report.json>
"""
import json, re, sys, os

AR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
rep = json.load(open(sys.argv[1]))
cat = json.load(open(os.path.join(AR, "catalog.json")))
sets = {v["global"] for v in cat["sets"].values()}
doors = set()
for f, v in rep.items():
    for q in v["functions"]:
        m = re.match(r"^([a-z_0-9]+)\.([a-z_0-9]+)_door\.walkOut$", q["name"])
        if m and not q["calls"] and m[2] in sets and m[1] in sets:
            doors.add("%s.%s_door" % (m[1], m[2]))
with open(os.path.join(AR, "ex06_doors.lua"), "w", newline=chr(10)) as f:
    f.write("-- made by tools/gen_door_trips.py from a Lua coverage report: the doors the 100% run never walked through. A door trip (ar_door_trips,\n"
            "-- ar_full.lua) takes each once, through and back, or out by the door back and in by it; do not edit\n")
    f.write("AR_TRIP_DOOR = AR_TRIP_DOOR or { }\n")
    for d in sorted(doors):
        f.write('AR_TRIP_DOOR["%s"] = TRUE\n' % d)
print(len(doors), "doors")
