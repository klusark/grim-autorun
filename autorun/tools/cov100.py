#!/usr/bin/env python
"""Coverage report of what the runs did, against catalog.json (tools/catalog.py).

usage: cov100.py <catalog.json> <log>... [--out DIR]     |     cov100.py --selftest

Log lines (anywhere in the line, fields separated by " | "):
  AUTORUN COV do | <verb> | <object display name> | <item display name or empty> | <set name>
  AUTORUN COV say | <text code, e.g. /gama007/>
  AUTORUN COV set | <set name>
  AUTORUN COV setup | <set name> | <setup number>
Writes <out>/index.html (default autorun/coverage100/index.html) and prints the lists.
"""
import html, json, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
AUTORUN = os.path.dirname(HERE)
MARK = "AUTORUN COV "


def parse_logs(paths):
    do, say, sets, setups = set(), set(), set(), set()
    for p in paths:
        with open(p, encoding="latin-1") as f:
            for ln in f:
                i = ln.find(MARK)
                if i < 0:
                    # the camera notes of the library: "AUTORUN camera: <set name> setup <n>" (every set and setup that was in view)
                    j = ln.find("AUTORUN camera: ")
                    if j >= 0:
                        t = ln[j + 16:].strip()
                        name, sep, num = t.rpartition(" setup ")
                        if sep:
                            sets.add(name)
                            setups.add((name, num.strip()))
                    continue
                parts = [x.strip() for x in ln[i + len(MARK):].rstrip("\r\n").split(" | ")]
                k = parts[0].split(" |")[0].strip()
                parts[0] = k
                if k == "do" and len(parts) >= 3:
                    parts += [""] * (5 - len(parts))
                    do.add((parts[1], parts[2], parts[3], parts[4]))
                elif k == "say" and len(parts) >= 2:
                    say.add(parts[1])
                elif k == "set" and len(parts) >= 2:
                    sets.add(parts[1])
                elif k == "setup" and len(parts) >= 3:
                    setups.add((parts[1], parts[2]))
    return do, say, sets, setups


def analyse(cat, do, say, sets, setups):
    r = {}
    # dialogs
    dl = {}
    tot = done = 0
    for d, dd in sorted(cat["dialogs"].items()):
        rows = []
        for e in dd["lines"]:
            ok = e["text"] in say
            rows.append((e, ok))
            tot += 1
            done += ok
        dl[d] = (dd["file"], rows)
    r["dialogs"] = dl
    r["lines"] = (done, tot)
    # objects and verbs
    objs = {**cat["objects"], **cat["items"]}
    name_of = {}
    for k, o in objs.items():
        name_of[k.split(".")[-1]] = o["name"]
    did_v = set()      # (set name, object name, verb)
    did_v_any = set()  # (object name, verb)
    did_c = set()      # (set name, object name, item name)
    did_c_any = set()
    for verb, obj, item, st in do:
        if item:
            did_c.add((st, obj, item))
            did_c_any.add((obj, item))
        else:
            did_v.add((st, obj, verb))
            did_v_any.add((obj, verb))
    per_set = {}
    vt = vd = ct = cd = ot = od = 0
    for k, o in sorted(objs.items(), key=lambda kv: (kv[1]["set_name"], kv[0])):
        sn = o["set_name"]
        s = per_set.setdefault(sn, {"verbs": [], "combos": []})
        any_v = False
        for v in o["verbs"]:
            ok = (sn, o["name"], v) in did_v or (o["name"], v) in did_v_any
            s["verbs"].append((k, o["name"], v, ok))
            vt += 1
            vd += ok
            any_v = any_v or ok
        for it in o["combos"]:
            iname = name_of.get(it, it)
            ok = (sn, o["name"], iname) in did_c or (o["name"], iname) in did_c_any
            s["combos"].append((k, o["name"], iname, ok))
            ct += 1
            cd += ok
        if o["verbs"]:
            ot += 1
            od += any_v
    r["per_set"] = per_set
    r["verbs"] = (vd, vt)
    r["combos"] = (cd, ct)
    r["objects"] = (od, ot)
    # sets and setups
    st_rows = []
    sst = sd = 0
    nt = nd = 0
    for sn, s in sorted(cat["sets"].items()):
        nums = sorted(set(s["setups"].values()))
        seen = [n for n in nums if (sn, str(n)) in setups]
        st_rows.append((sn, sn in sets, nums, seen))
        sst += 1
        sd += sn in sets
        nt += len(nums)
        nd += len(seen)
    r["set_rows"] = st_rows
    r["sets"] = (sd, sst)
    r["setups"] = (nd, nt)
    return r


def pct(a):
    return "%d/%d (%.1f%%)" % (a[0], a[1], 100.0 * a[0] / a[1] if a[1] else 100.0)


def head(cat):
    nl = sum(len(d["lines"]) for d in cat["dialogs"].values())
    nv = sum(len(o["verbs"]) for o in list(cat["objects"].values()) + list(cat["items"].values()))
    nc = sum(len(o["combos"]) for o in list(cat["objects"].values()) + list(cat["items"].values()))
    return ("catalogue: %d dialogs (plan 35), %d lines (plan 493), %d objects (plan 1266), "
            "%d verbs, %d item combos, %d sets"
            % (len(cat["dialogs"]), nl, len(cat["objects"]) + len(cat["items"]), nv, nc, len(cat["sets"])))


def text_report(cat, r):
    out = [head(cat), "",
           "dialog lines said   : " + pct(r["lines"]),
           "objects touched     : " + pct(r["objects"]),
           "verbs done          : " + pct(r["verbs"]),
           "item combos tried   : " + pct(r["combos"]),
           "sets entered        : " + pct(r["sets"]),
           "setups seen         : " + pct(r["setups"]), ""]
    for d, (f, rows) in r["dialogs"].items():
        miss = [e for e, ok in rows if not ok]
        if miss:
            out.append("dialog %s (%s): %d of %d lines never said" % (d, f, len(miss), len(rows)))
            for e in miss:
                out.append("   %s %s%s" % (e["n"], e["text"], flags(e)))
    out.append("")
    for sn, s in sorted(r["per_set"].items()):
        mv = [x for x in s["verbs"] if not x[3]]
        mc = [x for x in s["combos"] if not x[3]]
        if mv or mc:
            out.append("set %s: %d verbs, %d combos never done" % (sn, len(mv), len(mc)))
            for _, n, v, _ok in mv:
                out.append("   %s: %s" % (n, v))
            for _, n, i, _ok in mc:
                out.append("   %s with %s" % (n, i))
    out.append("")
    for sn, entered, nums, seen in r["set_rows"]:
        if not entered or len(seen) < len(nums):
            out.append("set %s: %s, setups unseen %s" % (
                sn, "entered" if entered else "never entered", [n for n in nums if n not in seen]))
    return "\n".join(out)


def flags(e):
    f = []
    if e["exit"]:
        f.append("exit")
    if e.get("exclusive_with"):
        f.append("either/or " + e["exclusive_with"])
    if e.get("unreachable_static"):
        f.append("never enabled")
    if e.get("one_way"):
        f.append("one-way")
    if e.get("intro_gated"):
        f.append("intro-gated")
    return "  [" + ", ".join(f) + "]" if f else ""


def html_report(cat, r, outdir):
    h = html.escape
    o = ["<!DOCTYPE html><meta charset=utf-8><title>Coverage 100</title>",
         "<style>body{font:14px sans-serif;margin:2em;max-width:70em}.no{color:#b00}.ok{color:#080}"
         "td,th{padding:1px 8px;text-align:left}table{border-collapse:collapse}details{margin:.3em 0}</style>",
         "<h1>Coverage of the catalogue</h1><p>%s</p><table>" % h(head(cat))]
    for lab, key in (("Dialog lines said", "lines"), ("Objects touched", "objects"), ("Verbs done", "verbs"),
                     ("Item combinations tried", "combos"), ("Sets entered", "sets"), ("Setups seen", "setups")):
        o.append("<tr><th>%s<td>%s" % (lab, h(pct(r[key]))))
    o.append("</table><h2>Dialogs</h2>")
    for d, (f, rows) in r["dialogs"].items():
        n = sum(1 for _, ok in rows if ok)
        o.append("<details%s><summary>%s (%s): %d/%d</summary><table>" % (
            "" if n == len(rows) else " open", h(d), h(f), n, len(rows)))
        for e, ok in rows:
            o.append("<tr class=%s><td>%s<td>%s<td>%s<td>%s" % (
                "ok" if ok else "no", e["n"], h(e["text"]), "said" if ok else "never", h(flags(e))))
        o.append("</table></details>")
    o.append("<h2>Objects by set</h2>")
    for sn, s in sorted(r["per_set"].items()):
        rows = s["verbs"] + [(k, n, "with " + i, ok) for k, n, i, ok in s["combos"]]
        if not rows:
            continue
        n = sum(1 for x in rows if x[3])
        o.append("<details%s><summary>%s: %d/%d</summary><table>" % (
            "" if n == len(rows) else " open", h(sn), n, len(rows)))
        for _, nm, v, ok in rows:
            o.append("<tr class=%s><td>%s<td>%s<td>%s" % ("ok" if ok else "no", h(nm), h(v), "done" if ok else "never"))
        o.append("</table></details>")
    o.append("<h2>Sets and setups</h2><table><tr><th>set<th>entered<th>setups seen<th>setups never seen")
    for sn, entered, nums, seen in r["set_rows"]:
        o.append("<tr class=%s><td>%s<td>%s<td>%s<td>%s" % (
            "ok" if entered and len(seen) == len(nums) else "no", h(sn), "yes" if entered else "no",
            seen, [n for n in nums if n not in seen]))
    o.append("</table>")
    os.makedirs(outdir, exist_ok=True)
    with open(os.path.join(outdir, "index.html"), "w", encoding="utf-8") as f:
        f.write("\n".join(o))


def run(catpath, logs, outdir):
    with open(catpath) as f:
        cat = json.load(f)
    r = analyse(cat, *parse_logs(logs))
    print(text_report(cat, r))
    html_report(cat, r, outdir)
    print("\nwrote", os.path.join(outdir, "index.html"))
    return cat, r


def selftest():
    td = os.path.join(HERE, "testdata")
    cat, r = run(os.path.join(td, "mini_catalog.json"), [os.path.join(td, "mini.log")],
                 os.path.join(td, "out"))
    assert r["lines"] == (2, 3), r["lines"]
    assert r["verbs"] == (2, 4), r["verbs"]
    assert r["combos"] == (1, 2), r["combos"]
    assert r["sets"] == (1, 2), r["sets"]
    assert r["setups"] == (1, 3), r["setups"]
    print("selftest ok")


if __name__ == "__main__":
    a = sys.argv[1:]
    if "--selftest" in a:
        selftest()
        sys.exit(0)
    out = os.path.join(AUTORUN, "coverage100")
    if "--out" in a:
        i = a.index("--out")
        out = a[i + 1]
        del a[i:i + 2]
    if len(a) < 2:
        print(__doc__)
        sys.exit(1)
    run(a[0], a[1:], out)
