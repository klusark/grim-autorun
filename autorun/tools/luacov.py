#!/usr/bin/env python
"""Coverage of the Lua scripts: which functions, lines and instructions of the scripts ran, from the files a ScummVM with the Lua
coverage writes (engines/grim/lua/lcoverage.cpp: the configuration key lua_coverage, or GRIM_LUA_COVERAGE, names a folder).

usage: luacov.py <dump file or folder>... [--src DIR]... [--out DIR] [--json FILE] [--missed] [--file NAME]...
       luacov.py --selftest

  --src DIR    where to look for the sources (by the file name the engine was given, then by its base name; several --src)
  --out DIR    writes DIR/index.html (one line per file, the least covered first) and a page per file: its source with the lines
               that ran in green, the ones that never ran in red, the ones that ran only in part in yellow (a branch or a part
               of an expression never taken), with the counts; for a file without lines (the game's compiled scripts) the
               instructions of each function
  --json FILE  the same numbers by file and by function
  --missed     prints the functions that never ran
  --file NAME  only the files whose name contains NAME (several --file: any of them)

The dumps of several runs and engines add up: a function is the same when its file, line, code and constants are.
Lines: the parser of the coverage engine marks each statement of a text script with its line (SETLINEW with bit 15 set, which
the VM skips); a compiled script has lines only if it was compiled with $debug (SETLINE). Without lines, functions and
instructions are counted only.
"""
import html
import json
import os
import re
import sys
from collections import defaultdict

OPS = """ENDCODE PUSHNIL PUSHNIL0 PUSHNUMBER PUSHNUMBER0 PUSHNUMBER1 PUSHNUMBER2 PUSHNUMBERW
PUSHCONSTANT PUSHCONSTANT0 PUSHCONSTANT1 PUSHCONSTANT2 PUSHCONSTANT3 PUSHCONSTANT4 PUSHCONSTANT5 PUSHCONSTANT6 PUSHCONSTANT7 PUSHCONSTANTW
PUSHUPVALUE PUSHUPVALUE0 PUSHUPVALUE1
PUSHLOCAL PUSHLOCAL0 PUSHLOCAL1 PUSHLOCAL2 PUSHLOCAL3 PUSHLOCAL4 PUSHLOCAL5 PUSHLOCAL6 PUSHLOCAL7
GETGLOBAL GETGLOBAL0 GETGLOBAL1 GETGLOBAL2 GETGLOBAL3 GETGLOBAL4 GETGLOBAL5 GETGLOBAL6 GETGLOBAL7 GETGLOBALW
GETTABLE
GETDOTTED GETDOTTED0 GETDOTTED1 GETDOTTED2 GETDOTTED3 GETDOTTED4 GETDOTTED5 GETDOTTED6 GETDOTTED7 GETDOTTEDW
PUSHSELF PUSHSELF0 PUSHSELF1 PUSHSELF2 PUSHSELF3 PUSHSELF4 PUSHSELF5 PUSHSELF6 PUSHSELF7 PUSHSELFW
CREATEARRAY CREATEARRAY0 CREATEARRAY1 CREATEARRAYW
SETLOCAL SETLOCAL0 SETLOCAL1 SETLOCAL2 SETLOCAL3 SETLOCAL4 SETLOCAL5 SETLOCAL6 SETLOCAL7
SETGLOBAL SETGLOBAL0 SETGLOBAL1 SETGLOBAL2 SETGLOBAL3 SETGLOBAL4 SETGLOBAL5 SETGLOBAL6 SETGLOBAL7 SETGLOBALW
SETTABLE0 SETTABLE SETLIST SETLIST0 SETLISTW SETMAP SETMAP0
EQOP NEQOP LTOP LEOP GTOP GEOP ADDOP SUBOP MULTOP DIVOP POWOP CONCOP MINUSOP NOTOP
ONTJMP ONTJMPW ONFJMP ONFJMPW JMP JMPW IFFJMP IFFJMPW IFTUPJMP IFTUPJMPW IFFUPJMP IFFUPJMPW
CLOSURE CLOSURE0 CLOSURE1 CALLFUNC CALLFUNC0 CALLFUNC1 RETCODE SETLINE SETLINEW POP POP0 POP1""".split()
OP = {n: i for i, n in enumerate(OPS)}
LINE_MARK = 0x8000
# (the ones with a constant for operand: PUSHCONSTANT3 is constant 3, PUSHCONSTANT and ...W take it from the operand)
CONST_OPS = ("PUSHCONSTANT", "GETGLOBAL", "GETDOTTED", "PUSHSELF", "SETGLOBAL")


def op_size(name):
    if name == "SETLISTW":
        return 4
    if name in ("SETLIST", "CALLFUNC") or (name.endswith("W") and name != "ENDCODE"):
        return 3
    if name in ("PUSHNIL", "PUSHNUMBER", "PUSHCONSTANT", "PUSHUPVALUE", "PUSHLOCAL", "GETGLOBAL", "GETDOTTED", "PUSHSELF",
                "CREATEARRAY", "SETLOCAL", "SETGLOBAL", "SETTABLE", "SETLIST0", "SETMAP", "ONTJMP", "ONFJMP", "JMP", "IFFJMP",
                "IFTUPJMP", "IFFUPJMP", "CLOSURE", "CALLFUNC0", "CALLFUNC1", "RETCODE", "SETLINE", "POP"):
        return 2
    return 1


SIZE = [op_size(n) for n in OPS]


def decode(code):
    """The instructions of a function's code: (offset, name, operand or None, const index or None, line mark or None).
    The words are little-endian, as ScummVM's VM reads them."""
    out = []
    p = 2
    while p < len(code):
        b = code[p]
        if b >= len(OPS):
            break
        name = OPS[b]
        sz = SIZE[b]
        arg = None
        if sz == 2:
            arg = code[p + 1]
        elif sz == 3 and name not in ("SETLIST", "CALLFUNC"):
            arg = code[p + 1] | (code[p + 2] << 8)
        elif sz >= 3:
            arg = code[p + 1]
        k = None
        for c in CONST_OPS:
            if name.startswith(c):
                suf = name[len(c):]
                k = arg if suf in ("", "W") else int(suf)
                break
        mark = None
        if name == "SETLINEW" and arg & LINE_MARK:
            mark = arg & ~LINE_MARK
        out.append((p, name, arg, k, mark))
        p += sz
        if name == "ENDCODE":
            break
    return out


def unescape(s):
    return re.sub(r"\\(x[0-9a-f]{2}|\\)", lambda m: "\\" if m.group(1) == "\\" else chr(int(m.group(1)[1:], 16)), s)


class Func:
    def __init__(self, file, line, code, consts):
        self.file, self.line, self.code, self.consts = file, line, code, consts   # consts: ("S", text) ("N", n) ("P", Func) ("-", None)
        self.hits = defaultdict(int)
        self.name = None
        self.parent = None
        self._ins = None

    def ins(self):
        if self._ins is None:
            self._ins = decode(self.code)
        return self._ins

    def key(self):
        return (self.file, self.line, self.code, tuple((t, id(v) if t == "P" else v) for t, v in self.consts))


def read_dumps(paths, funcs, warn=print):
    """Adds the dumps in paths (files, or folders of luacov_*.txt) to funcs (key -> Func). Returns how many files were read."""
    files = []
    for p in paths:
        if os.path.isdir(p):
            files += sorted(os.path.join(p, f) for f in os.listdir(p) if f.startswith("luacov") and f.endswith(".txt"))
        else:
            files.append(p)
    n = 0
    for path in files:
        with open(path, encoding="latin-1") as f:
            lines = f.read().split("\n")
        if not lines or not lines[0].startswith("LUACOV 1"):
            warn("not a Lua coverage file: %s" % path)
            continue
        if "END" not in lines[-3:]:
            warn("cut short (the engine ended while writing it?): %s" % path)
        n += 1
        byid = {}
        cur = None   # [id, line, file, code, consts, hits]

        def close(c):
            fid, line, file, code, consts, hits = c
            fn = Func(file, line, code, consts)
            k = fn.key()
            old = funcs.get(k)
            if old is None:
                funcs[k] = old = fn
            for off, cnt in hits:
                old.hits[off] += cnt
            byid[fid] = old
        for ln in lines:
            if ln.startswith("F "):
                if cur:
                    close(cur)
                _, fid, line, file = ln.split(" ", 3)
                cur = [int(fid), int(line), unescape(file), b"", [], []]
            elif ln.startswith("C ") and cur:
                cur[3] = bytes.fromhex(ln[2:])
            elif ln.startswith("K ") and cur:
                _, _, t, *v = ln.split(" ", 3)
                v = v[0] if v else ""
                if t == "S":
                    cur[4].append(("S", unescape(v)))
                elif t == "N":
                    cur[4].append(("N", float(v)))
                elif t == "P":
                    cur[4].append(("P", byid.get(int(v))))
                else:
                    cur[4].append(("-", None))
            elif ln.startswith("H") and cur:
                for x in ln[1:].split():
                    o, c = x.split(":")
                    cur[5].append((int(o), int(c)))
        if cur:
            close(cur)
    return n


def const_name(fn, k):
    if k is not None and k < len(fn.consts) and fn.consts[k][0] == "S":
        return fn.consts[k][1]
    return None


def name_functions(funcs):
    """Names each function after what its parent does with it: function f() / f = function (SETGLOBAL f), function a.b:c()
    (GETGLOBAL a, GETDOTTED b, PUSHCONSTANT "c", the function, SETTABLE), local f = function (SETLOCAL), else <function>."""
    for fn in funcs:
        ins = [i for i in fn.ins() if i[4] is None]
        for j, (off, name, arg, k, mark) in enumerate(ins):
            if not name.startswith("PUSHCONSTANT") or k is None or k >= len(fn.consts) or fn.consts[k][0] != "P":
                continue
            child = fn.consts[k][1]
            if child is None or child.parent is not None:
                continue
            child.parent = fn
            nxt = j + 1
            while nxt < len(ins) and ins[nxt][1].startswith("CLOSURE"):
                nxt += 1
            nn = ins[nxt][1] if nxt < len(ins) else ""
            nm = None
            if nn.startswith("SETGLOBAL"):
                nm = const_name(fn, ins[nxt][3])
            elif nn == "SETTABLE0" or nn == "SETMAP0" or nn == "SETMAP":
                # (the key and the table before the function, past the upvalues pushed for its closure)
                b = j - 1
                while b >= 0 and (ins[b][1].startswith("PUSHUPVALUE") or ins[b][1].startswith("PUSHLOCAL")) and \
                        ins[j + 1][1].startswith("CLOSURE"):
                    b -= 1
                if b >= 0 and ins[b][1].startswith("PUSHCONSTANT"):
                    key = const_name(fn, ins[b][3])
                    parts = [key] if key else []
                    b -= 1
                    while b >= 0 and ins[b][1].startswith("GETDOTTED"):
                        parts.insert(0, const_name(fn, ins[b][3]) or "?")
                        b -= 1
                    if nn == "SETTABLE0" and b >= 0 and ins[b][1].startswith("GETGLOBAL"):
                        parts.insert(0, const_name(fn, ins[b][3]) or "?")
                    elif nn == "SETTABLE0" and b >= 0 and ins[b][1].startswith("PUSHLOCAL"):
                        parts.insert(0, "<local>")
                    elif nn != "SETTABLE0":
                        parts.insert(0, "{}")
                    if key:
                        nm = ".".join(parts)
            elif nn.startswith("SETLOCAL"):
                nm = "local function"
            child.name = nm
    for fn in funcs:
        if fn.name is None:
            if fn.line == 0 and fn.parent is None:
                fn.name = "(main chunk)"
            else:
                outer = fn.parent.name if fn.parent is not None and fn.parent.name and fn.parent.line else None
                fn.name = "<function>" + (" in " + outer if outer else "")


class Stats:
    def __init__(self, fn):
        ins = fn.ins()
        self.ninstr = 0
        self.nhit = 0
        self.lines = {}   # line -> [count, executed instructions, instructions]
        line = None
        # (what follows a return or a jump that always jumps, up to where a jump lands, never runs: the jump over the else
        # after a return in the then part, the ENDCODE after a last return; not counted)
        targets = set()
        for off, name, arg, k, mark in ins:
            if name.rstrip("W") in ("ONTJMP", "ONFJMP", "JMP", "IFFJMP"):
                targets.add(off + SIZE[OP[name]] + arg)
            elif name.rstrip("W") in ("IFTUPJMP", "IFFUPJMP"):
                targets.add(off + SIZE[OP[name]] - arg)
        dead = False
        for off, name, arg, k, mark in ins:
            if off in targets:
                dead = False
            if mark is not None:
                line = mark
                self.lines.setdefault(line, [0, 0, 0])
                self.lines[line][0] = max(self.lines[line][0], fn.hits.get(off, 0))
                continue
            if name == "SETLINE" or (name == "SETLINEW" and mark is None):
                line = arg
            c = fn.hits.get(off, 0)
            if dead and not c:
                continue
            dead = name in ("RETCODE", "JMP", "JMPW", "ENDCODE")
            self.ninstr += 1
            self.nhit += 1 if c else 0
            if line is not None:
                ent = self.lines.setdefault(line, [0, 0, 0])
                ent[0] = max(ent[0], c)
                ent[1] += 1 if c else 0
                ent[2] += 1
        self.called = fn.hits.get(2, 0) > 0 or self.nhit > 0
        self.calls = fn.hits.get(2, 0)


def find_source(name, srcs, cache={}):
    if name in cache:
        return cache[name]
    found = None
    for d in srcs:
        for cand in (os.path.join(d, name), os.path.join(d, os.path.basename(name.replace("\\", "/")))):
            if os.path.isfile(cand):
                found = cand
                break
        if found:
            break
    cache[name] = found
    return found


def analyse(funcs):
    files = defaultdict(list)
    for fn in funcs:
        files[fn.file].append(fn)
    res = {}
    for file, fns in files.items():
        fns.sort(key=lambda f: (f.line, f.name or ""))
        st = [(f, Stats(f)) for f in fns]
        lines = {}
        for f, s in st:
            for ln, (c, h, t) in s.lines.items():
                old = lines.get(ln)
                if old is None:
                    lines[ln] = [c, h, t]
                else:
                    old[0] = max(old[0], c)
                    old[1] += h
                    old[2] += t
        # (the main chunk runs once per load: it counts like the others, but is shown apart)
        nf = [x for x in st if x[0].name != "(main chunk)"]
        res[file] = {
            "funcs": st,
            "lines": lines,
            "nfunc": len(nf), "nfunc_hit": sum(1 for f, s in nf if s.called),
            "nline": len(lines), "nline_hit": sum(1 for v in lines.values() if v[0] > 0),
            "nline_part": sum(1 for v in lines.values() if v[0] > 0 and v[1] < v[2]),
            "ninstr": sum(s.ninstr for f, s in st), "ninstr_hit": sum(s.nhit for f, s in st),
        }
    return res


def pct(a, b):
    return 100.0 * a / b if b else 100.0


def safe_name(file):
    return re.sub(r"[^A-Za-z0-9_.-]", "_", file) + ".html"


CSS = ("body{font:14px sans-serif;margin:1em;background:#fff;color:#222}table{border-collapse:collapse}"
       "td,th{border:1px solid #ccc;padding:2px 8px;text-align:right}td.l,th.l{text-align:left}"
       "pre{font:12px monospace;line-height:1.35}.h{background:#dfd}.m{background:#fcc}.p{background:#ffc}"
       ".n{color:#888;user-select:none}.c{color:#555;display:inline-block;width:6em;text-align:right;user-select:none}"
       "a{color:#036}")


def write_html(out, res, srcs, title):
    os.makedirs(out, exist_ok=True)
    rows = sorted(res.items(), key=lambda kv: (pct(kv[1]["nline_hit"], kv[1]["nline"]) if kv[1]["nline"] else
                                               pct(kv[1]["ninstr_hit"], kv[1]["ninstr"]), kv[0]))
    T = {k: sum(r[k] for r in res.values()) for k in ("nfunc", "nfunc_hit", "nline", "nline_hit", "nline_part", "ninstr", "ninstr_hit")}
    with open(os.path.join(out, "index.html"), "w", encoding="utf-8") as f:
        f.write('<!doctype html><meta charset="utf-8"><title>Lua coverage</title><style>%s</style>' % CSS)
        f.write("<h2>Lua coverage</h2><p>%s</p>" % html.escape(title))
        f.write("<table><tr><th class=l>file</th><th>functions run</th><th>lines run</th><th>in part</th><th>instructions run</th></tr>")

        def row(name, r, link):
            ln = "%d / %d (%.1f%%)" % (r["nline_hit"], r["nline"], pct(r["nline_hit"], r["nline"])) if r["nline"] else "-"
            f.write("<tr><td class=l>%s</td><td>%d / %d (%.1f%%)</td><td>%s</td><td>%s</td><td>%d / %d (%.1f%%)</td></tr>" % (
                '<a href="%s">%s</a>' % (link, html.escape(name)) if link else "<b>%s</b>" % name,
                r["nfunc_hit"], r["nfunc"], pct(r["nfunc_hit"], r["nfunc"]), ln, r["nline_part"] if r["nline"] else "-",
                r["ninstr_hit"], r["ninstr"], pct(r["ninstr_hit"], r["ninstr"])))
        row("total", T, None)
        for file, r in rows:
            row(file, r, safe_name(file))
        f.write("</table>")
    for file, r in res.items():
        write_file_page(os.path.join(out, safe_name(file)), file, r, srcs)
    return T


def write_file_page(path, file, r, srcs):
    src = find_source(file, srcs) if r["nline"] else None
    with open(path, "w", encoding="utf-8") as f:
        f.write('<!doctype html><meta charset="utf-8"><title>%s</title><style>%s</style>' % (html.escape(file), CSS))
        f.write('<p><a href="index.html">all files</a></p><h2>%s</h2>' % html.escape(file))
        f.write("<p>functions %d / %d run, lines %d / %d run (%d in part), instructions %d / %d run%s</p>" % (
            r["nfunc_hit"], r["nfunc"], r["nline_hit"], r["nline"], r["nline_part"], r["ninstr_hit"], r["ninstr"],
            "" if src or not r["nline"] else "; the source was not found (--src)"))
        f.write("<table><tr><th>line</th><th class=l>function</th><th>calls</th><th>instructions run</th></tr>")
        for fn, s in r["funcs"]:
            cls = "h" if s.called and s.nhit == s.ninstr else ("p" if s.called else "m")
            anchor = ("#L%d" % fn.line) if src else ("#F%d_%d" % (fn.line, id(fn)))
            f.write('<tr class=%s><td><a href="%s">%d</a></td><td class=l>%s</td><td>%d</td><td>%d / %d</td></tr>' % (
                cls, anchor, fn.line, html.escape(fn.name or "?"), s.calls, s.nhit, s.ninstr))
        f.write("</table>")
        if src:
            with open(src, encoding="latin-1") as sf:
                text = sf.read().split("\n")
            f.write("<p>source: %s</p><pre>" % html.escape(src))
            for i, t in enumerate(text, 1):
                v = r["lines"].get(i)
                cls, cnt = "", ""
                if v:
                    cls = "m" if v[0] == 0 else ("p" if v[1] < v[2] else "h")
                    cnt = str(v[0])
                f.write('<span id="L%d" class="%s"><span class=n>%5d</span><span class=c>%s</span>  %s</span>\n' % (
                    i, cls, i, cnt, html.escape(t)))
            f.write("</pre>")
        else:
            for fn, s in r["funcs"]:
                f.write('<h3 id="F%d_%d">%s (line %d): %d / %d instructions run</h3><pre>' % (
                    fn.line, id(fn), html.escape(fn.name or "?"), fn.line, s.nhit, s.ninstr))
                for off, name, arg, k, mark in fn.ins():
                    c = fn.hits.get(off, 0)
                    if mark is not None:
                        f.write('<span class=n>-- line %d</span>\n' % mark)
                        continue
                    txt = name
                    if k is not None and k < len(fn.consts):
                        t, v = fn.consts[k]
                        txt += " " + (repr(v) if t in ("S", "N") else ("<%s>" % (v.name if v else "function")))
                    elif arg is not None:
                        txt += " %d" % arg
                    f.write('<span class="%s"><span class=n>%5d</span><span class=c>%d</span>  %s</span>\n' % (
                        "h" if c else "m", off, c, html.escape(txt)))
                f.write("</pre>")


def main(argv):
    if "--selftest" in argv:
        return selftest()
    paths, srcs, out, js, only = [], [], None, None, []
    missed = False
    i = 0
    while i < len(argv):
        a = argv[i]
        if a in ("--src", "--out", "--json", "--file"):
            if i + 1 >= len(argv):
                sys.exit("%s needs a value" % a)
            v = argv[i + 1]
            if a == "--src":
                srcs.append(v)
            elif a == "--out":
                out = v
            elif a == "--json":
                js = v
            else:
                only.append(v)
            i += 2
            continue
        if a == "--missed":
            missed = True
        elif a.startswith("-"):
            sys.exit(__doc__)
        else:
            paths.append(a)
        i += 1
    if not paths:
        sys.exit(__doc__)
    funcs = {}
    n = read_dumps(paths, funcs, warn=lambda m: print(m, file=sys.stderr))
    fl = list(funcs.values())
    name_functions(fl)
    if only:
        fl = [f for f in fl if any(o in f.file for o in only)]
    res = analyse(fl)
    title = "%d dump files, %d functions in %d files" % (n, len(fl), len(res))
    T = {k: sum(r[k] for r in res.values()) for k in ("nfunc", "nfunc_hit", "nline", "nline_hit", "nline_part", "ninstr", "ninstr_hit")}
    print(title)
    print("%-40s %18s %24s %22s" % ("file", "functions run", "lines run (in part)", "instructions run"))
    for file, r in sorted(res.items(), key=lambda kv: kv[0]):
        print("%-40s %8d/%-5d %3.0f%% %10s %4s %3s %12s %3.0f%%" % (
            file[-40:], r["nfunc_hit"], r["nfunc"], pct(r["nfunc_hit"], r["nfunc"]),
            "%d/%d" % (r["nline_hit"], r["nline"]) if r["nline"] else "-",
            "%3.0f%%" % pct(r["nline_hit"], r["nline"]) if r["nline"] else "", "(%d)" % r["nline_part"] if r["nline"] else "",
            "%d/%d" % (r["ninstr_hit"], r["ninstr"]), pct(r["ninstr_hit"], r["ninstr"])))
    print("%-40s %8d/%-5d %3.0f%% %10s %3.0f%% %4s %12s %3.0f%%" % (
        "total", T["nfunc_hit"], T["nfunc"], pct(T["nfunc_hit"], T["nfunc"]), "%d/%d" % (T["nline_hit"], T["nline"]),
        pct(T["nline_hit"], T["nline"]), "(%d)" % T["nline_part"], "%d/%d" % (T["ninstr_hit"], T["ninstr"]),
        pct(T["ninstr_hit"], T["ninstr"])))
    if missed:
        print("\nnever run:")
        for file, r in sorted(res.items()):
            for fn, s in r["funcs"]:
                if not s.called:
                    print("  %s:%d %s" % (file, fn.line, fn.name))
    if out:
        write_html(out, res, srcs, title)
        print("wrote %s" % os.path.join(out, "index.html"))
    if js:
        with open(js, "w") as f:
            json.dump({file: {
                "functions": [{"name": fn.name, "line": fn.line, "calls": s.calls, "instructions": s.ninstr, "run": s.nhit}
                              for fn, s in r["funcs"]],
                "lines": {str(k): {"count": v[0], "partial": v[0] > 0 and v[1] < v[2]} for k, v in sorted(r["lines"].items())},
                **{k: r[k] for k in ("nfunc", "nfunc_hit", "nline", "nline_hit", "nline_part", "ninstr", "ninstr_hit")}}
                for file, r in res.items()}, f, indent=1, sort_keys=True)
    return 0


def selftest():
    """A dump made by hand: f = function(a) if a then x() end end, called once with a false a."""
    import tempfile
    # code: header, mark line 1, PUSHLOCAL0 IFFJMP 4, mark 2, GETGLOBAL0 CALLFUNC0 0, mark 3, ENDCODE
    m = lambda line: [OP["SETLINEW"], line & 0xff, (line | LINE_MARK) >> 8]
    code = [1, 1] + m(1) + [OP["PUSHLOCAL0"], OP["IFFJMP"], 6] + m(2) + [OP["GETGLOBAL0"], OP["CALLFUNC0"], 0] + m(3) + [OP["ENDCODE"]]
    main_code = [0, 0] + m(1) + [OP["PUSHCONSTANT1"], OP["SETGLOBAL0"]] + m(4) + [OP["ENDCODE"]]
    ins = decode(bytes(code))
    assert [i[1] for i in ins] == ["SETLINEW", "PUSHLOCAL0", "IFFJMP", "SETLINEW", "GETGLOBAL0", "CALLFUNC0", "SETLINEW", "ENDCODE"], ins
    offs = [i[0] for i in ins]
    hit = [0, 1, 2, 6, 7]   # (the then part, instructions 3 to 5, skipped)
    d = tempfile.mkdtemp()
    with open(os.path.join(d, "luacov_t.txt"), "w") as f:
        f.write("LUACOV 1\nF 0 1 t.lua\nC %s\nK 0 S x\nH %s\n" % (bytes(code).hex(), " ".join("%d:1" % offs[i] for i in hit)))
        f.write("F 1 0 t.lua\nC %s\nK 0 S f\nK 1 P 0\nH %s\nEND\n" % (bytes(main_code).hex(), " ".join("%d:1" % i[0] for i in decode(bytes(main_code)))))
    with open(os.path.join(d, "t.lua"), "w") as f:
        f.write("f = function(a) if a then\n x()\nend end\n")
    funcs = {}
    assert read_dumps([d], funcs) == 1
    read_dumps([d], funcs)   # (twice: the counts add up, the functions stay two)
    fl = list(funcs.values())
    assert len(fl) == 2, fl
    name_functions(fl)
    res = analyse(fl)["t.lua"]
    names = sorted(fn.name for fn, s in res["funcs"])
    assert names == ["(main chunk)", "f"], names
    fs = [s for fn, s in res["funcs"] if fn.name == "f"][0]
    assert fs.called and fs.calls == 2 and fs.nhit == 3 and fs.ninstr == 5, (fs.calls, fs.nhit, fs.ninstr)
    assert res["lines"][1][0] == 2 and res["lines"][2][0] == 0, res["lines"]
    assert res["nline_part"] == 0 and res["nline_hit"] == 3, res
    write_html(os.path.join(d, "out"), {"t.lua": res}, [d], "selftest")
    page = open(os.path.join(d, "out", "t.lua.html"), encoding="utf-8").read()
    assert 'class="m"' in page and 'class="h"' in page
    print("selftest ok")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
