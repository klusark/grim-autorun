#!/usr/bin/env python3
"""Writes ex02_dialogs.lua from the dialog scripts (~/grim_lua_src):
  AR_NO_AUTO[dialog][line] = TRUE   the lines that a 100% run does not say on its own, because their response ends the dialog, starts a cutscene,
                                    changes the set or moves to another node of the dialog. Those are for the extras of the chapters.
  AR_DLG_MOVE[dialog][line] = node  of those, the lines whose response does nothing but move to one other node (a sub-menu of the talk)
  AR_DLG_EXIT[dialog][node] = node  where the exit line of a node goes, when it goes to one node only ("exit_dialog" ends the talk)
  AR_DLG_END[dialog][line] = TRUE   of the AR_NO_AUTO lines, the ones whose response does nothing but end the talk (no items, no story): said in place of
                                    the exit line when a chapter ends the talk anyway
ar_talk_before (ar_full.lua) enters a sub-menu only when its exit line comes back to the node it was entered from.
  python tools/gen_dlg_skip.py [source dir]"""
import re, glob, os, sys
src = sys.argv[1] if len(sys.argv) > 1 else "C:/Users/Joel/grim_lua_src"
line_def = re.compile(r'^([a-z_0-9]+)\[(\d+)\] = \{')
resp_def = re.compile(r'^([a-z_0-9]+)\[(\d+)\]\.response = function')
exit_def = re.compile(r'^([a-z_0-9]+)\.exit_lines\.([a-z_0-9]+)\.response = function')
alias = re.compile(r'^([a-z_0-9]+)\[(\d+)\]\.response = ([a-z_0-9]+)\[(\d+)\]\.response')
risky = re.compile(r'\.node\s*=|exit_dialog|START_CUT_SCENE|switch_to_set|cut_scene\.|\.outro|Dialog:|put_in_limbo|goto_|game_over|ChangeSet|load_game|save_game')
# (what makes a line more than a move to a node: anything of risky but the node itself)
story = re.compile(r'exit_dialog\(|START_CUT_SCENE|switch_to_set|cut_scene\.|\.outro|Dialog:|put_in_limbo|goto_|game_over|ChangeSet|load_game|save_game')
items = re.compile(r':get\(\)|:free\(\)|put_in_limbo|give|\.owner')
node_set = re.compile(r'\.node\s*=\s*"([a-z_0-9]+)"')
assign = re.compile(r'^\s*(local\s+)?([A-Za-z_][\w.\[\]"]*)\s*=[^=]')


def sets_state(text):
    """Whether a response assigns anything but the node of the dialog, the off of its line and locals (gl1[220] recruits Glottis: a story line)."""
    for ln in text.split("\n"):
        m = assign.match(ln)
        if m and not m.group(1) and not m.group(2).endswith(".node") and not m.group(2).endswith(".off"):
            return True
    return False
body = {}
exits = {}
funcs = {}
lines = set()
al = {}
# (the functions of a dialog table, "ev1.explain_choice = function": a response that calls one, ev1:explain_choice(), does what its body does. Eva's
# line 12 moves to explain_node that way, which the walker could not come back from, chapter 1)
func_def = re.compile(r'^([a-z_0-9]+)\.([a-z_0-9]+) = function')
func_call = re.compile(r'\b([a-z_0-9]+):([a-z_0-9]+)\(')
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
            cur = body.setdefault((m[1], int(m[2])), []); continue
        m = exit_def.match(ln)
        if m:
            cur = exits.setdefault((m[1], m[2]), []); continue
        m = func_def.match(ln)
        if m:
            cur = funcs.setdefault((m[1], m[2]), []); continue
        if ln.startswith("end"):
            cur = None; continue
        if cur is not None:
            cur.append(ln)


def with_calls(text, d, depth=3):
    """The text of a response with the bodies of the functions of its own dialog that it calls (d:func(), arg1:func()), three levels deep."""
    if depth == 0:
        return text
    extra = []
    for obj, name in func_call.findall(text):
        if obj in (d, "arg1") and (d, name) in funcs:
            extra.append(with_calls("\n".join(funcs[(d, name)]), d, depth - 1))
    return text + ("\n" + "\n".join(extra) if extra else "")


out, move, back, end = {}, {}, {}, {}
for k in sorted(lines):
    text = with_calls("\n".join(body.get(al.get(k, k), [])), k[0])
    if risky.search(text):
        out.setdefault(k[0], []).append(k[1])
        nodes = set(node_set.findall(text))
        if len(nodes) == 1 and not story.search(text) and "exit_dialog" not in nodes:
            move.setdefault(k[0], {})[k[1]] = nodes.pop()
        elif nodes == {"exit_dialog"} and not story.search(text) and not items.search(text) and not sets_state(text):
            end.setdefault(k[0], []).append(k[1])
for (d, node), b in sorted(exits.items()):
    nodes = set(node_set.findall("\n".join(b)))
    if len(nodes) == 1:
        back.setdefault(d, {})[node] = nodes.pop()
with open("ex02_dialogs.lua", "w") as f:
    f.write("-- made by tools/gen_dlg_skip.py from the dialog scripts: the lines that the 100% run does not say on its own (their response ends the dialog,\n"
            "-- starts a cutscene, changes the set or moves to a node), the moves to a node, where the exit line of each node goes, and the lines that only\n"
            "-- end the talk; do not edit\n"
            "AR_NO_AUTO = AR_NO_AUTO or { }\nAR_DLG_MOVE = AR_DLG_MOVE or { }\nAR_DLG_EXIT = AR_DLG_EXIT or { }\nAR_DLG_END = AR_DLG_END or { }\n")
    for d, ns in sorted(out.items()):
        f.write('AR_NO_AUTO["%s"] = { }\n' % d)
        for n in ns:
            f.write('AR_NO_AUTO["%s"][%d] = TRUE\n' % (d, n))
    for d, m in sorted(move.items()):
        f.write('AR_DLG_MOVE["%s"] = { }\n' % d)
        for n, node in sorted(m.items()):
            f.write('AR_DLG_MOVE["%s"][%d] = "%s"\n' % (d, n, node))
    for d, m in sorted(back.items()):
        f.write('AR_DLG_EXIT["%s"] = { }\n' % d)
        for node, to in sorted(m.items()):
            f.write('AR_DLG_EXIT["%s"]["%s"] = "%s"\n' % (d, node, to))
    for d, ns in sorted(end.items()):
        f.write('AR_DLG_END["%s"] = { }\n' % d)
        for n in ns:
            f.write('AR_DLG_END["%s"][%d] = TRUE\n' % (d, n))
print(sum(len(v) for v in out.values()), "lines of", len(lines), "left to the extras;", sum(len(v) for v in move.values()), "of them move to a node,",
      sum(len(v) for v in end.values()), "only end the talk;", sum(len(v) for v in back.values()), "exit lines go to one node")
