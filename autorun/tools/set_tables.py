"""Makes ar_nav_sets.lua from the NAVSET lines that dump_sets.lua writes to the log of a ScummVM run:
for each set its global, its cheat boxes and the door objects of its hot sectors. usage: set_tables.py <log> > ar_nav_sets.lua"""
import re, sys
print("-- made by tools/set_tables.py from dump_sets.lua; do not edit")
print("AR_SETS = { }")
seen = {}
for ln in open(sys.argv[1], errors="replace"):
    i = ln.find("NAVSET ")
    if i < 0:
        continue
    t = ln[i + 7:].strip()
    if t == "DONE":
        continue
    head, _, rest = t.partition("|")
    g, _, name = head.strip().partition(" ")
    if name in seen:
        continue
    seen[name] = g
    fm = re.search(r"f:(\S+)", rest)
    cheats = re.findall(r"\bc:(\S+)", rest)
    doors = re.findall(r"\bd:(\S+?)=(\S*)", rest)
    print('AR_SETS["%s"] = { file = "%s", global = "%s", cheat = { %s }, door = { %s } }' % (
        name.replace('"', '\\"'), fm.group(1) if fm else g + ".set", g,
        ", ".join('"%s"' % c for c in cheats),
        ", ".join('["%s"] = { %s }' % (h, ", ".join('"%s"' % k for k in keys.split(",") if k)) for h, keys in doors)))
