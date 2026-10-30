#!/usr/bin/env python
"""Static catalogue of the game's dialogs, objects, items, sets and setups.

usage: catalog.py [lua_src_dir] [out.json]
Reads the decompiled Lua 3.1 scripts (default C:/Users/Joel/grim_lua_src) and
autorun/ar_nav_sets.lua.  Setups come from the Set:create(...) setup table of
each set script (name -> number), not from the .set files.
"""
import json, os, re, sys, glob

HERE = os.path.dirname(os.path.abspath(__file__))
AUTORUN = os.path.dirname(HERE)
SRC = sys.argv[1] if len(sys.argv) > 1 else "C:/Users/Joel/grim_lua_src"
OUT = sys.argv[2] if len(sys.argv) > 2 else os.path.join(AUTORUN, "catalog.json")

VERBS = ("lookAt", "use", "pickUp", "walkOut", "climbOut")
EXCLUSIVE = [("ch1", 100, "ch1", 110), ("sa2", 140, "sa2", 210), ("ce1", 120, "ce1", 130)]


def strip_hdr(s):
    return re.sub(r"^/[^/]*/", "", s)


def read(p):
    with open(p, encoding="latin-1") as f:
        return f.read()


files = sorted(glob.glob(os.path.join(SRC, "*.lua")))
texts = {p: read(p) for p in files}

# ---- dialogs ----
dialogs = {}
re_dcreate = re.compile(r"^(\w+)\s*=\s*Dialog:create\(\)", re.M)
re_line = re.compile(r"^(\w+)\[(\d+)\]\s*=\s*\{\s*text\s*=\s*\"(/[^\"]*/)")
re_exit = re.compile(r"^(\w+)\.exit_lines\.(\w+)\s*=\s*\{\s*text\s*=\s*\"(/[^\"]*/)")
re_off = re.compile(r"^(\s*)(\w+)\[(\d+)\]\.off\s*=\s*(TRUE|FALSE|nil)")
re_fn = re.compile(r"^(\w+)\.(\w+)\s*=\s*function")


def newline(n, text, exit_):
    return {"n": n, "text": text, "exit": exit_, "initially_off": False,
            "enabled_by": [], "disabled_by": []}


dialog_files = set()
for p in files:
    base = os.path.basename(p)
    txt = texts[p]
    names = set(m.group(1) for m in re_dcreate.finditer(txt))
    if not names:
        continue
    dialog_files.add(base)
    for n in names:
        dialogs[n] = {"file": base, "lines": []}
    byid = {}
    for ln in txt.splitlines():
        m = re_line.match(ln)
        if m and m.group(1) in names:
            d = m.group(1)
            key = int(m.group(2))
            e = newline(key, m.group(3), False)
            dialogs[d]["lines"].append(e)
            byid[(d, key)] = e
            continue
        m = re_exit.match(ln)
        if m and m.group(1) in names:
            dialogs[m.group(1)]["lines"].append(newline(m.group(2), m.group(3), True))
    # top level (no indent) = initial state; indented = inside a response or intro
    cur = None
    for ln in txt.splitlines():
        m = re_line.match(ln)
        if m:
            cur = "%s[%s]" % (m.group(1), m.group(2))
        m = re_fn.match(ln)
        if m:
            cur = "intro" if m.group(2) == "intro" else cur
        m = re_off.match(ln)
        if not m:
            continue
        ind, d, k, val = m.group(1), m.group(2), int(m.group(3)), m.group(4)
        tgt = byid.get((d, k))
        if d not in names or tgt is None:
            continue
        if not ind:
            if val == "TRUE":
                tgt["initially_off"] = True
        else:
            (tgt["enabled_by"] if val == "FALSE" else tgt["disabled_by"]).append(cur or "?")
# other files flipping lines of a dialog by its global name (do1[50].off = FALSE in dlg_glottis)
for p in files:
    base = os.path.basename(p)
    for m in re.finditer(r"(\w+)\[(\d+)\]\.off\s*=\s*(TRUE|FALSE)", texts[p]):
        d = m.group(1)
        if d in dialogs and dialogs[d]["file"] != base:
            for e in dialogs[d]["lines"]:
                if e["n"] == int(m.group(2)):
                    (e["enabled_by"] if m.group(3) == "FALSE" else e["disabled_by"]).append(base)

for d, dd in dialogs.items():
    for e in dd["lines"]:
        e["unreachable_static"] = e["initially_off"] and not e["enabled_by"]
        e["intro_gated"] = e["initially_off"] and e["enabled_by"] == ["intro"]
        # one-way: switched off by something and nothing ever switches it on again
        e["one_way"] = (not e["initially_off"]) and bool(e["disabled_by"]) and not e["enabled_by"] and not e["exit"]
        e["exclusive_with"] = None
for a, an, b, bn in EXCLUSIVE:
    for e in dialogs.get(a, {"lines": []})["lines"]:
        if e["n"] == an:
            e["exclusive_with"] = "%s[%d]" % (b, bn)
        if e["n"] == bn:
            e["exclusive_with"] = "%s[%d]" % (a, an)

# ---- objects ----
re_obj = re.compile(r"^\s*(\w+)\.([\w.]+)\s*=\s*Object:create\((\w+),\s*\"([^\"]*)\"")
re_verb = re.compile(r"^\s*(\w+)\.([\w.]+?)\.(lookAt|use|pickUp|walkOut|climbOut|use_\w+)\s*=\s*(.*)")
re_in = re.compile(r"^\s*(\w+)\.([\w.]+?)\.(?:in\s*=|wav\s*=\s*\"get)")
objects = {}
for p in files:
    base = os.path.basename(p)
    for ln in texts[p].splitlines():
        m = re_obj.match(ln)
        if m:
            key = m.group(1) + "." + m.group(2)
            objects[key] = {"set": m.group(3), "var": key, "file": base,
                            "name": strip_hdr(m.group(4)), "code": m.group(4),
                            "verbs": [], "combos": [], "item": False}
for p in files:
    for ln in texts[p].splitlines():
        m = re_verb.match(ln)
        if m:
            key = m.group(1) + "." + m.group(2)
            f = m.group(3)
            o = objects.get(key)
            if not o or m.group(4).strip() == "nil":
                continue
            if f in VERBS:
                if f not in o["verbs"]:
                    o["verbs"].append(f)
            elif not re.match(r"use_(pnt|rot)", f):
                it = f[4:]
                if it not in o["combos"]:
                    o["combos"].append(it)
            continue
        m = re_in.match(ln)
        if m:
            o = objects.get(m.group(1) + "." + m.group(2))
            if o:
                o["item"] = True

# ---- sets ----
sets = {}
txt = read(os.path.join(AUTORUN, "ar_nav_sets.lua"))
for m in re.finditer(r'^AR_SETS\["([^"]+)"\]\s*=\s*\{\s*file\s*=\s*"([^"]+)",\s*global\s*=\s*"([^"]+)"', txt, re.M):
    sets[m.group(1)] = {"file": m.group(2), "global": m.group(3), "setups": {}}
byglobal = {s["global"]: k for k, s in sets.items()}
re_setc = re.compile(r"^(\w+)\s*=\s*Set:create\(\"([^\"]+)\",\s*\"([^\"]*)\",\s*\{([^}]*)\}")
extra_sets = {}
for p in files:
    for ln in texts[p].splitlines():
        m = re_setc.match(ln)
        if m:
            g = m.group(1)
            setups = {a: int(b) for a, b in re.findall(r"(\w+)\s*=\s*(\d+)", m.group(4))}
            if g in byglobal:
                sets[byglobal[g]]["setups"] = setups
            else:
                extra_sets[g] = {"file": m.group(2), "name": m.group(3), "setups": setups}

for o in objects.values():
    o["set_name"] = byglobal.get(o["set"], o["set"])
items = {k: o for k, o in objects.items() if o["item"]}
other_objs = {k: o for k, o in objects.items() if not o["item"]}

cat = {"dialogs": dialogs, "objects": other_objs, "items": items, "sets": sets,
       "sets_not_in_AR_SETS": extra_sets, "exclusions": [list(x) for x in EXCLUSIVE],
       "setups_note": "setups from the Set:create table of the set scripts; .set files not read"}
with open(OUT, "w") as f:
    json.dump(cat, f, indent=1)

nl = sum(len(d["lines"]) for d in dialogs.values())
print("dialogs %d (plan 35)  lines %d (plan 493)  exit lines %d" % (
    len(dialogs), nl, sum(1 for d in dialogs.values() for e in d["lines"] if e["exit"])))
print("objects %d + items %d = %d (plan 1266)  verbs %d  combos %d" % (
    len(other_objs), len(items), len(objects),
    sum(len(o["verbs"]) for o in objects.values()), sum(len(o["combos"]) for o in objects.values())))
print("sets %d  setups %d  (set scripts not in AR_SETS: %d)" % (
    len(sets), sum(len(set(s["setups"].values())) for s in sets.values()), len(extra_sets)))
print("one_way %d  intro_gated %d  unreachable_static %d  exclusive %d" % tuple(
    sum(1 for d in dialogs.values() for e in d["lines"] if e[k]) for k in
    ("one_way", "intro_gated", "unreachable_static", "exclusive_with")))
print("wrote", OUT)
