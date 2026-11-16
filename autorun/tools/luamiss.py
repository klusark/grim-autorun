#!/usr/bin/env python
"""Why the object handlers of the game's scripts that never ran (Lua coverage, tools/luacov.py --json) did not run, from the run's log.

usage: luamiss.py <luacov report.json> <run log> [--list KIND]

Each never-run function named <set>.<object>.<handler> (lookAt, use, pickUp, use_<item>, walkOut, ...) of an object of catalog.json gets one
reason, the first that holds:
  set never entered      the run never was in the set
  set not swept          ex00_sweep.lua keeps the set out of the look at everything (AR_NO_SWEEP), or the log has "no sweep of"
  heavy step off         use/pickUp/use_<item> where the set has no use, pick up and items step (AR_NO_HEAVY, AR_NO_USE)
  tried, refused         the run tried the verb on it and the game did not offer it ("FAIL <verb> <code> is not offered")
  tried, other handler   the run did the verb on it (a COV do line) and still this function did not run (the game took another way)
  item never tried       use_<item> on an object the run never used that item on
  skipped: <why>         the sweep had it in its list and left it (OBJSKIP lines of ar_full.lua: untouchable, owned, no-range, no-look, no-use...)
  never tried            none of the above: the sweep never had it in its list, or it is no verb the run does
The other never-run functions (no object of the catalog) are counted by their file.
"""
import json, re, sys, collections, os

AR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def main():
    args = sys.argv[1:]
    listkind = None
    if "--list" in args:
        i = args.index("--list")
        listkind = args[i + 1]
        del args[i:i + 2]
    rep = json.load(open(args[0]))
    log = open(args[1], encoding="latin-1").read()
    cat = json.load(open(os.path.join(AR, "catalog.json")))
    ex00 = open(os.path.join(AR, "ex00_sweep.lua"), encoding="latin-1").read()
    objs = cat["objects"]
    set_name = {}
    for s, v in cat["sets"].items():
        set_name[v["global"]] = s
    entered = set(re.findall(r"COV set \| (.+)", log)) | set(re.findall(r"Switching to set: (.+?)\.\r?$", log, re.M))
    no_sweep = set(re.findall(r'AR_NO_SWEEP\["(.+?)"\]', ex00)) | set(re.findall(r"no sweep of (.+?) \(", log))
    no_heavy = set(re.findall(r'AR_NO_HEAVY\["(.+?)"\]', ex00))
    no_use = set(re.findall(r'AR_NO_USE\["(.+?)"\]', ex00))
    refused = set()
    for verb, code in re.findall(r"FAIL (\w+) (\S+) is not offered", log):
        refused.add((verb, code))
    done = set()
    for verb, name, item, sname in re.findall(r"COV do \| (\w+) \| (.*?) \| (.*?) \| (.+)", log):
        done.add((verb, name.strip(), item.strip(), sname.strip()))
    skips = collections.defaultdict(set)
    for key, verb, why in re.findall(r"OBJSKIP (\S+) (\w+) (\S+)", log):
        skips[(key, verb)].add(why)
    items_used = collections.defaultdict(set)
    for verb, name, item, sname in done:
        if item:
            items_used[(name, sname)].add(item)
    reasons = collections.Counter()
    by = collections.defaultdict(list)
    other = collections.Counter()
    for f, v in rep.items():
        if f.startswith("(dostring)"):
            continue
        for q in v["functions"]:
            if q["calls"]:
                continue
            n = q["name"]
            m = re.match(r"^([a-z_0-9]+)\.([a-z_0-9]+)\.([A-Za-z_0-9]+)$", n)
            if not m or "%s.%s" % (m[1], m[2]) not in objs:
                other[f.split(chr(92))[-1]] += 1
                continue
            g, field, h = m[1], m[2], m[3]
            o = objs["%s.%s" % (g, field)]
            sname = o.get("set_name") or set_name.get(g, g)
            disp = o["name"]
            verb = "use" if h.startswith("use_") else h
            item = h[4:] if h.startswith("use_") else ""
            if sname not in entered:
                why = "set never entered"
            elif sname in no_sweep and h in ("lookAt",):
                why = "set not swept"
            elif h != "lookAt" and h != "walkOut" and (sname in no_heavy or sname in no_sweep or "%s.%s" % (g, field) in no_use):
                why = "heavy step off"
            elif (verb, o["code"]) in refused:
                why = "tried, refused"
            elif not item and any(d[0] == verb and d[1] == disp and not d[2] and d[3] == sname for d in done):
                why = "tried, other handler"
            elif item:
                why = "item never tried" if not items_used.get((disp, sname)) else "item never tried (others were)"
            elif skips.get(("%s.%s" % (g, field), verb)):
                why = "skipped: " + "/".join(sorted(skips[("%s.%s" % (g, field), verb)]))
            else:
                why = "never tried"
            key = "%s %s" % (why, h if h in ("lookAt", "use", "pickUp", "walkOut") else ("use_<item>" if item else "other handler"))
            reasons[key] += 1
            by[why].append("%s (%s, %s)" % (n, disp, sname))
    print("never-run object handlers: %d" % sum(reasons.values()))
    for k, c in sorted(reasons.items(), key=lambda kv: -kv[1]):
        print("  %5d  %s" % (c, k))
    print("other never-run functions: %d, by file:" % sum(other.values()))
    for k, c in other.most_common(25):
        print("  %5d  %s" % (c, k))
    if listkind:
        print()
        for x in by.get(listkind, []):
            print(x)


if __name__ == "__main__":
    main()
