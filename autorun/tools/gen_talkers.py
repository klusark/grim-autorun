#!/usr/bin/env python3
"""Writes ex03_talkers.lua from the scripts: AR_TALKERS[set global] = { object, ... } for the objects whose use starts a dialog, and
AR_TALKER_DLGS["<set global>.<object>"] = { dialog, ... }, the dialogs its use can start (the people step of ar_full.lua leaves a person alone whose
dialog a chapter still talks in: only opening and closing Celso's talk before chapter 13 broke the chapter's own talk with him)."""
import re, glob, os
src = "C:/Users/Joel/grim_lua_src"
hdr = re.compile(r"^([a-z_0-9]+)\.([a-zA-Z_0-9]+)\.use = function")
other = re.compile(r"^[a-z_0-9]+(\.[a-zA-Z_0-9]+)+ = function")
run = re.compile(r'Dialog:run\("(\w+)"')
talk = {}
dlgs = {}
for f in sorted(glob.glob(src + "/*.lua")):
    if os.path.basename(f).startswith("dlg_"):
        continue
    cur = None
    for ln in open(f, errors="replace").read().split("\n"):
        m = hdr.match(ln)
        if m:
            cur = (m[1], m[2])
        elif other.match(ln):
            cur = None
        m = run.search(ln)
        if m and cur:
            talk.setdefault(cur[0], [])
            if cur[1] not in talk[cur[0]]:
                talk[cur[0]].append(cur[1])
            d = dlgs.setdefault(cur[0] + "." + cur[1], [])
            if m[1] not in d:
                d.append(m[1])
with open("ex03_talkers.lua", "w") as o:
    o.write("-- made by tools/gen_talkers.py from the scripts (the use of an object that starts a dialog): AR_TALKERS[set global] = { object, ... } and\n"
            "-- AR_TALKER_DLGS[\"<set global>.<object>\"] = { dialog, ... }; the 100% run uses them and talks, see ar_talk_people in ar_full.lua\n"
            "AR_TALKERS = AR_TALKERS or { }\nAR_TALKER_DLGS = AR_TALKER_DLGS or { }\n")
    for s, l in sorted(talk.items()):
        o.write('AR_TALKERS["%s"] = { %s }\n' % (s, ", ".join('"%s"' % n for n in l)))
    for k, l in sorted(dlgs.items()):
        o.write('AR_TALKER_DLGS["%s"] = { %s }\n' % (k, ", ".join('"%s"' % n for n in l)))
print(sum(len(v) for v in talk.values()), "talkers in", len(talk), "sets:", " ".join(sorted(talk)))
