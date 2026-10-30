#!/usr/bin/env python3
"""Writes ex02_dialogs.lua: AR_NO_AUTO[dialog][line] = TRUE for the lines of the game's dialogs that a 100% run does not say on its own, because their
response (read from the script source, ~/grim_lua_src) ends the dialog, starts a cutscene or changes the set. Those are for the extras of the chapters.
  python tools/gen_dlg_skip.py [source dir]"""
import re, glob, os, sys
src = sys.argv[1] if len(sys.argv) > 1 else "C:/Users/Joel/grim_lua_src"
line_def = re.compile(r'^([a-z_0-9]+)\[(\d+)\] = \{')
resp_def = re.compile(r'^([a-z_0-9]+)\[(\d+)\]\.response = function')
alias = re.compile(r'^([a-z_0-9]+)\[(\d+)\]\.response = ([a-z_0-9]+)\[(\d+)\]\.response')
risky = re.compile(r'\.node\s*=|exit_dialog|START_CUT_SCENE|switch_to_set|cut_scene\.|\.outro|Dialog:|put_in_limbo|goto_|game_over|ChangeSet|load_game|save_game')
body = {}
lines = set()
al = {}
for f in sorted(glob.glob(os.path.join(src, "*.lua"))):
    cur = None
    for ln in open(f, errors="replace").read().split("\n"):
        m = alias.match(ln)
        if m:
            al[(m[1], int(m[2]))] = (m[3], int(m[4])); cur = None; continue
        m = line_def.match(ln)
        if m:
            lines.add((m[1], int(m[2]))); cur = None; continue
        m = resp_def.match(ln)
        if m:
            cur = (m[1], int(m[2])); body[cur] = []; continue
        if ln.startswith("end"):
            cur = None; continue
        if cur:
            body[cur].append(ln)
out = {}
for k in sorted(lines):
    kk = al.get(k, k)
    text = "\n".join(body.get(kk, []))
    if risky.search(text):
        out.setdefault(k[0], []).append(k[1])
with open("ex02_dialogs.lua", "w") as f:
    f.write("-- made by tools/gen_dlg_skip.py from the dialog scripts: the lines that the 100% run does not say on its own (their response ends the dialog,\n-- starts a cutscene or changes the set); do not edit\nAR_NO_AUTO = AR_NO_AUTO or { }\n")
    for d, ns in sorted(out.items()):
        f.write('AR_NO_AUTO["%s"] = { }\n' % d)
        for n in ns:
            f.write('AR_NO_AUTO["%s"][%d] = TRUE\n' % (d, n))
print(sum(len(v) for v in out.values()), "lines of", len(lines), "left to the extras")
