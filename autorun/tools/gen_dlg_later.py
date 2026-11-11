#!/usr/bin/env python3
"""Writes ex04_dlg_later.lua from the chapters (ch*.lua, in the order run_all.sh plays them):
  AR_DLG_LAST["<dialog>"] = "<chapter>"      the last chapter that talks in the dialog itself (ar_pick, ar_pick_exit, ar_choose_line, ar_dialog_ready,
                                             ar_talk_all on it). An extra of the 100% modes says nothing in a dialog a later chapter still talks in:
                                             Celso's sales pitch, said at the end of chapter 59, took the line chapter 60 picks.
  AR_DLG_PICKS["<dialog>"][<line>] = "<chapter>"   the last chapter that picks the line (ar_pick(dlg, n)). The talk before a pick (ar_talk_before) never
                                             says a line that this chapter or a later one picks: chapter 13 picks Celso's lines 110, 120 and 135 in turn,
                                             and 135 said before 110 was off when the chapter came to it.
  AR_CHAPTERS = { "<chapter>", ... }         the chapters in order (a run of one chapter has a tag after its name: the name is found by its start)
  python tools/gen_dlg_later.py"""
import glob, os, re

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
use = re.compile(r'ar_(?:pick|pick_if|pick_exit|choose_line|dialog_ready|talk_all|line_shown)\(\s*([a-z]{2}[0-9])\b')
# (ar_pick_if too: chapter 17 picks Charlie's lines with it, and the talk before said them first)
pick = re.compile(r'ar_(?:pick|pick_if|choose_line)\(\s*([a-z]{2}[0-9])\s*,\s*(\d+)\s*\)')
last, picks, chapters = {}, {}, []
for f in sorted(glob.glob(os.path.join(HERE, "ch*.lua"))):
    name = os.path.basename(f)[:-4]
    chapters.append(name)
    text = open(f, errors="replace").read()
    for d in use.findall(text):
        last[d] = name
    for d, n in pick.findall(text):
        picks.setdefault(d, {})[int(n)] = name
# (a line that shares its response with a picked line is held back as well: two wordings of one question, saying one takes the other. Charlie's 110 has
# the response of 100, which chapter 17 picks: 110 said first and 100 was not offered any more)
SRC = os.environ.get("GRIM_LUA_SRC", "C:/Users/Joel/grim_lua_src")
alias = re.compile(r'^([a-z_0-9]+)\[(\d+)\]\.response = \1\[(\d+)\]\.response', re.M)
shared = {}
for g in glob.glob(os.path.join(SRC, "dlg_*.lua")) + glob.glob(os.path.join(SRC, "*.lua")):
    for d, a, b in alias.findall(open(g, errors="replace").read()):
        shared.setdefault((d, int(b)), set()).add(int(a))
        shared.setdefault((d, int(a)), set()).add(int(b))
for d in list(picks):
    for n, ch in list(picks[d].items()):
        todo, seen = [n], {n}
        while todo:
            for m in shared.get((d, todo.pop()), ()):
                if m not in seen:
                    seen.add(m)
                    todo.append(m)
                    if m not in picks[d] or picks[d][m] < ch:
                        picks[d][m] = ch
with open(os.path.join(HERE, "ex04_dlg_later.lua"), "w") as f:
    f.write("-- made by tools/gen_dlg_later.py from the chapters: the last chapter that talks in each dialog itself, the last that picks each line, and the\n"
            "-- chapters in order; do not edit\n"
            "AR_DLG_LAST = AR_DLG_LAST or { }\nAR_DLG_PICKS = AR_DLG_PICKS or { }\n")
    for d, ch in sorted(last.items()):
        f.write('AR_DLG_LAST["%s"] = "%s"\n' % (d, ch))
    for d, m in sorted(picks.items()):
        f.write('AR_DLG_PICKS["%s"] = { }\n' % d)
        for n, ch in sorted(m.items()):
            f.write('AR_DLG_PICKS["%s"][%d] = "%s"\n' % (d, n, ch))
    f.write("AR_CHAPTERS = { " + ", ".join('"%s"' % c for c in chapters) + " }\n")
print(len(last), "dialogs,", sum(len(m) for m in picks.values()), "lines picked,", len(chapters), "chapters")
