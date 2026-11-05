"""Infers the argument kinds of each builtin from how the game's decompiled scripts call it (only read, to know the
signatures; nothing of them goes into the tests): signatures.py [scripts dir] [--print]

A call's arguments are split at the top level; each gets a kind from its text: actor (an hActor or an actor table),
costume / set / string (a string), table, bool (TRUE / FALSE / nil), number (anything else). Per builtin the longest call
is kept, the kind of a position is the most common one. Writes tools/signatures.json, which gen_args.py reads."""
import collections
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = r"C:\Users\Joel\grim_lua_src"


def split_args(s):
    """The top-level arguments of the text after a '(' up to the matching ')'; None if it does not close."""
    depth, cur, out, quote = 0, "", [], None
    for ch in s:
        if quote:
            cur += ch
            if ch == quote:
                quote = None
            continue
        if ch in "\"'":
            quote = ch
            cur += ch
        elif ch in "([{":
            depth += 1
            cur += ch
        elif ch in ")]}":
            if depth == 0:
                if cur.strip():
                    out.append(cur.strip())
                return out
            depth -= 1
            cur += ch
        elif ch == "," and depth == 0:
            out.append(cur.strip())
            cur = ""
        else:
            cur += ch
    return None


def kind(a):
    if re.search(r"hActor\b|\bmanny\b|actor$", a):
        return "actor"
    if a.startswith(("\"", "'")):
        if re.search(r"\.cos[\"']", a):
            return "costume"
        if re.search(r"\.set[\"']", a):
            return "set"
        return "string"
    if a.startswith("{"):
        return "table"
    if a in ("TRUE", "FALSE", "nil"):
        return "bool"
    if re.search(r"costume|\.cos\b", a, re.I):
        return "costume"
    if re.search(r"setFile|\.set\b", a):
        return "set"
    if re.search(r"\bname\b|text|line|_font\b", a):
        return "string" if "font" not in a else "font"
    return "number"


def main():
    src = sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].startswith("--") else SRC
    calls = collections.defaultdict(list)
    for f in os.listdir(src):
        if not f.endswith(".lua"):
            continue
        text = open(os.path.join(src, f), encoding="latin-1").read()
        for m in re.finditer(r"\b([A-Z][A-Za-z0-9]+)\(", text):
            args = split_args(text[m.end():m.end() + 400])
            if args is not None:
                calls[m.group(1)].append([kind(a) for a in args])
    sigs = {}
    for name, cl in calls.items():
        n = max(len(c) for c in cl)
        pos = []
        for i in range(n):
            ks = collections.Counter(c[i] for c in cl if len(c) > i)
            pos.append(ks.most_common(1)[0][0])
        sigs[name] = pos
    out = os.path.join(HERE, "tools", "signatures.json")
    with open(out, "w", newline="\n") as f:
        json.dump(sigs, f, indent=0, sort_keys=True)
    print("wrote %s: %d signatures" % (out, len(sigs)))
    if "--print" in sys.argv:
        for k in sorted(sigs):
            print(k, sigs[k])


if __name__ == "__main__":
    main()
