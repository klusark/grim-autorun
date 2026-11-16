#!/usr/bin/env python3
"""Writes ex02_dialogs.lua from the dialog scripts (~/grim_lua_src):
  AR_NO_AUTO[dialog][line] = TRUE   the lines that a 100% run does not say on its own, because their response ends the dialog, starts a cutscene,
                                    changes the set or moves to another node of the dialog. Those are for the extras of the chapters.
  AR_DLG_MOVE[dialog][line] = node  of those, the lines whose response does nothing but move to one other node (a sub-menu of the talk)
  AR_DLG_EXIT[dialog][node] = node  where the exit line of a node goes, when it goes to one node only ("exit_dialog" ends the talk)
  AR_DLG_END[dialog][line] = TRUE   of the AR_NO_AUTO lines, the ones whose response does nothing but end the talk (no items, no story): said in place of
                                    the exit line when a chapter ends the talk anyway
  AR_DLG_MOVES[dialog][line] = { "a", "b" }  of the AR_NO_AUTO lines, the ones whose response does nothing but move to one of several nodes, as the
                                    state of the dialog has it (Eva's 12 and 14, ev1:explain_choice(): explain_node, or first_eva_node once she has
                                    explained it all); the talk follows the node the game goes to
  AR_DLG_ABORT[dialog][node] = node where the abort of a node goes, when it only moves to one node: the game runs it by itself when the node has no
                                    line left but its exit line (_dialog.lua, min_line), so a node talked through comes back there (Eva's explain2_node)
  AR_DLG_KEEP[dialog][line] = TRUE  of the moves, the ones that stay on when said (the response turns no line off): an extra may say one that a chapter
                                    picks later, it is offered again (Salvador's 220 into angry_node, chapter 5)
ar_talk_before (ar_full.lua) enters a sub-menu only when its exit line comes back to the node it was entered from.
  python tools/gen_dlg_skip.py [source dir]"""
import re, glob, os, sys
src = sys.argv[1] if len(sys.argv) > 1 else "C:/Users/Joel/grim_lua_src"
line_def = re.compile(r'^([a-z_0-9]+)\[(\d+)\] = \{')
resp_def = re.compile(r'^([a-z_0-9]+)\[(\d+)\]\.response = function')
exit_def = re.compile(r'^([a-z_0-9]+)\.exit_lines\.([a-z_0-9]+)\.response = function')
abort_def = re.compile(r'^([a-z_0-9]+)\.aborts\.([a-z_0-9]+) = function')
obj_resp_def = re.compile(r'^([a-z_0-9]+)\.([a-z_0-9]+)\.response = function')
exit_set = re.compile(r'\b([a-z_0-9]+)\.exit_lines\.([a-z_0-9]+) = ([a-z_0-9]+)\.(exit_lines\.)?([a-z_0-9]+)\s*$')
obj_resp = {}
exit_from = {}
alias = re.compile(r'^([a-z_0-9]+)\[(\d+)\]\.response = ([a-z_0-9]+)\[(\d+)\]\.response')
alias_func = re.compile(r'^([a-z_0-9]+)\[(\d+)\]\.response = ([a-z_0-9]+)\.([a-z_0-9]+)\s*$')
fal = {}
risky = re.compile(r'\.node\s*=|exit_dialog|START_CUT_SCENE|switch_to_set|cut_scene\.|\.outro|Dialog:|put_in_limbo|goto_|game_over|ChangeSet|load_game|save_game')
# (what makes a line more than a move to a node: anything of risky but the node itself)
story = re.compile(r'exit_dialog\(|START_CUT_SCENE|switch_to_set|cut_scene\.|\.outro|Dialog:|put_in_limbo|goto_|game_over|ChangeSet|load_game|save_game')
items = re.compile(r':get\(\)|:free\(\)|put_in_limbo|give|\.owner')
manny_walk = re.compile(r'manny:walkto\b|manny:walk_and_face|manny:run_to')
node_set = re.compile(r'\.node\s*=\s*"([a-z_0-9]+)"')
assign = re.compile(r'^\s*(local\s+)?([A-Za-z_][\w.\[\]"]*)\s*=[^=]')


def sets_state(text, d=None):
    """Whether a response assigns anything but the node of the dialog, the off of its line, locals and fields of its own dialog table (gl1[220]
    recruits Glottis: a story line; Nick's 210 sets vi1.joke_time, which only picks his next greeting)."""
    for ln in text.split("\n"):
        m = assign.match(ln)
        if m and not m.group(1) and not m.group(2).endswith(".node") and not m.group(2).endswith(".off") and not (d and m.group(2).startswith(d + ".")):
            return True
    return False
body = {}
exits = {}
aborts = {}
funcs = {}
lines = set()
al = {}
# (the functions of a dialog table, "ev1.explain_choice = function": a response that calls one, ev1:explain_choice(), does what its body does. Eva's
# line 12 moves to explain_node that way, which the walker could not come back from, chapter 1)
func_def = re.compile(r'^([a-z_0-9]+)\.([a-z_0-9]+) = function')
func_call = re.compile(r'\b([a-z_0-9]+):([a-z_0-9]+)\(')
line_call = re.compile(r'\b([a-z_0-9]+)\[(\d+)\]:response\(')
for f in sorted(glob.glob(os.path.join(src, "*.lua"))):
    cur = None
    for ln in open(f, errors="replace").read().split("\n"):
        m = alias.match(ln)
        if m:
            al[(m[1], int(m[2]))] = (m[3], int(m[4])); cur = None; continue
        # (a response that is a function of the dialog, "sa1[170].response = sa1.back_in": its body; Salvador's 170 moves to fold_node that way)
        m = alias_func.match(ln)
        if m:
            fal[(m[1], int(m[2]))] = (m[3], m[4]); cur = None; continue
        m = line_def.match(ln)
        if m:
            lines.add((m[1], int(m[2]))); cur = None; continue
        m = resp_def.match(ln)
        if m:
            cur = body.setdefault((m[1], int(m[2])), []); continue
        m = exit_def.match(ln)
        if m:
            cur = exits.setdefault((m[1], m[2]), []); continue
        m = abort_def.match(ln)
        if m:
            cur = aborts.setdefault((m[1], m[2]), []); continue
        # (a line kept in a field of the dialog, "me2.delayed_n3_exit.response = function": for an exit line that is set to it, below)
        m = obj_resp_def.match(ln)
        if m:
            cur = obj_resp.setdefault((m[1], m[2]), []); continue
        # (an exit line set from another table, anywhere, also inside a function: "me2.exit_lines.n3 = me2.delayed_n3_exit", which Meche's n3 shows
        # when it is displayed, or "ev1.exit_lines.explain2_node = ev1.exit_lines.first_eva_node")
        m = exit_set.search(ln)
        if m:
            exit_from[(m[1], m[2])] = (m[3], m[4], m[5])
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
    # (the response of another line of the dialog, "vi1[190]:response()": Nick's 180 moves to best_node that way, and was taken for a plain line)
    for obj, n in line_call.findall(text):
        k = (obj, int(n))
        if obj == d and k in body or k in al:
            extra.append(with_calls("\n".join(body.get(al.get(k, k), [])), d, depth - 1))
    return text + ("\n" + "\n".join(extra) if extra else "")


out, move, back, end, keep, multi, abort = {}, {}, {}, {}, {}, {}, {}
turns_off = re.compile(r"\.off\s*=\s*TRUE")
for k in sorted(lines):
    text = with_calls("\n".join(funcs.get(fal[k], []) if k in fal else body.get(al.get(k, k), [])), k[0])
    if risky.search(text):
        out.setdefault(k[0], []).append(k[1])
        nodes = set(node_set.findall(text))
        if len(nodes) == 1 and not story.search(text) and "exit_dialog" not in nodes:
            move.setdefault(k[0], {})[k[1]] = nodes.pop()
            if not turns_off.search(text):
                keep.setdefault(k[0], []).append(k[1])
        elif len(nodes) > 1 and not story.search(text) and "exit_dialog" not in nodes:
            multi.setdefault(k[0], {})[k[1]] = sorted(nodes)
            if not turns_off.search(text):
                keep.setdefault(k[0], []).append(k[1])
        # (nor a walk of Manny's: Carla's line 120, ca1, ends the talk with a walk across the metal detector, whose scene then never gives control back)
        elif nodes == {"exit_dialog"} and not story.search(text) and not items.search(text) and not sets_state(text, k[0]) and not manny_walk.search(text):
            end.setdefault(k[0], []).append(k[1])
for (d, node), b in sorted(aborts.items()):
    text = with_calls("\n".join(b), d)
    nodes = set(node_set.findall(text))
    if len(nodes) == 1 and not story.search(text) and "exit_dialog" not in nodes:
        abort.setdefault(d, {})[node] = nodes.pop()
for (d, node), (d2, isexit, name) in sorted(exit_from.items()):
    if (d, node) in exits:
        continue
    b = exits.get((d2, name)) if isexit else obj_resp.get((d2, name))
    if b is not None:
        exits[(d, node)] = b
for (d, node), b in sorted(exits.items()):
    nodes = set(node_set.findall("\n".join(b)))
    if len(nodes) == 1:
        back.setdefault(d, {})[node] = nodes.pop()
with open("ex02_dialogs.lua", "w", newline=chr(10)) as f:
    f.write("-- made by tools/gen_dlg_skip.py from the dialog scripts: the lines that the 100% run does not say on its own (their response ends the dialog,\n"
            "-- starts a cutscene, changes the set or moves to a node), the moves to a node, where the exit line of each node goes, and the lines that only\n"
            "-- end the talk; do not edit\n"
            "AR_NO_AUTO = AR_NO_AUTO or { }\nAR_DLG_MOVE = AR_DLG_MOVE or { }\nAR_DLG_EXIT = AR_DLG_EXIT or { }\nAR_DLG_END = AR_DLG_END or { }\nAR_DLG_KEEP = AR_DLG_KEEP or { }\nAR_DLG_MOVES = AR_DLG_MOVES or { }\nAR_DLG_ABORT = AR_DLG_ABORT or { }\n")
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
    for d, m in sorted(multi.items()):
        f.write('AR_DLG_MOVES["%s"] = { }\n' % d)
        for n, nodes in sorted(m.items()):
            f.write('AR_DLG_MOVES["%s"][%d] = { %s }\n' % (d, n, ", ".join('"%s"' % x for x in nodes)))
    for d, m in sorted(abort.items()):
        f.write('AR_DLG_ABORT["%s"] = { }\n' % d)
        for node, to in sorted(m.items()):
            f.write('AR_DLG_ABORT["%s"]["%s"] = "%s"\n' % (d, node, to))
    for d, ns in sorted(keep.items()):
        f.write('AR_DLG_KEEP["%s"] = { }\n' % d)
        for n in ns:
            f.write('AR_DLG_KEEP["%s"][%d] = TRUE\n' % (d, n))
print(sum(len(v) for v in out.values()), "lines of", len(lines), "left to the extras;", sum(len(v) for v in move.values()), "of them move to a node,",
      sum(len(v) for v in end.values()), "only end the talk;", sum(len(v) for v in back.values()), "exit lines go to one node")
