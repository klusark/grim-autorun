"""Writes tests/zz_args.lua: every Lua builtin of the original called with wrong or missing arguments, one test per call.

  python tools/gen_args.py [log with the builtins test, default expected/original.log]

The builtins are the ones the builtins test finds on the original (expected/original.log). For each one, the calls are
f(), f(nil), f("cr"), f(1.5), f({ }), f(function); a builtin whose name holds "Actor" is also called with a real actor
first: f(actor), f(actor, nil), f(actor, "cr"), f(actor, 1.5), f(actor, { }). The families (FAMILIES: text objects,
fonts, primitives, images, object states, colours, lights, sets, sectors) get a real first argument of their kind followed
by each wrong one, and the actor chore builtins wrong chores and costumes after a real actor. What comes back is logged (up to four values).
The original is the reference: where ScummVM accepts what the original refuses, or the other way round, the values or the
Lua errors differ. A call that crashes the original is found by run.py (expected/crashers.txt) and skipped on both.

DENY: builtins that would end or block the run, change the runner itself or touch files outside the test folder."""
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

DENY = set("""
exit Load Save dofile InputDialog QueryDialog StartFullscreenMovie StartMovie NukeResources DetachFromResources AttachToResources
RenderModeUser EngineDisplay SetHardwareState SetVideoDevices EnumerateVideoDevices Enumerate3DDevices GetVideoDevices
SpewStartup SpewShutdown LightMgrShutdown ImStartRecording ImStopRecording EnginePause EngineResume ScreenShot SaveScreen
SubmitSaveGameData GetSaveGameData SaveIMuse RestoreIMuse SetGamma quiet play vfx TEST DumpMemoryLog FindFileOnAnyCD
SearchForFileOrSwapCDs BOOT execute remove rename tmpname writeto appendto readfrom write read setlocale debug print_stack
pause_scripts unpause_scripts pause_script unpause_script stop_script start_script sleep_for break_here next_script
seterrormethod setfallback settagmethod copytagmethods setglobal rawsetglobal
""".split())

PATTERNS = [("none", ""), ("nil", "nil"), ("str", '"cr"'), ("num", "1.5"), ("tab", "{ }"), ("fn", "cr_args_fn")]
ACTOR_PATTERNS = [("a", "CR_ARGS_ACTOR"), ("a_nil", "CR_ARGS_ACTOR, nil"), ("a_str", 'CR_ARGS_ACTOR, "cr"'),
                  ("a_num", "CR_ARGS_ACTOR, 1.5"), ("a_tab", "CR_ARGS_ACTOR, { }")]

# Families of builtins with a real first argument of their kind, then each wrong one. The handles are made fresh for each
# call (cr_args_text() ...), so that a builtin that frees one cannot break the calls after it.
FAMILIES = [
    ("t", r"TextObject|^GetTextCharPosition$", "cr_args_text()"),
    ("f", r"Font", "cr_args_font()"),
    ("p", r"Primitive$", "cr_args_prim()"),
    ("i", r"^(BlastImage|FreeImage)$", "cr_args_image()"),
    ("o", r"^(SetObjectType|SendObjectToBack|SendObjectToFront|FreeObjectState)$", "cr_args_obj()"),
    ("k", r"^GetColorComponents$", "cr_args_color()"),
    ("l", r"Light", '"cr_light"'),
    ("s", r"^(MakeCurrentSet|LockSet|UnLockSet|GetCurrentSetup)$", '"cr_flat.set"'),
    ("e", r"^(MakeSectorActive|IsSectorActive|GetSectorVertices)$", '"floor"'),
]


def family_patterns(name):
    out = []
    for key, rx, first in FAMILIES:
        if re.search(rx, name):
            out += [(key, first), (key + "_nil", first + ", nil"), (key + "_str", first + ', "cr"'),
                    (key + "_num", first + ", 1.5"), (key + "_tab", first + ", { }")]
    if "Chore" in name and "Actor" in name:
        a = "CR_ARGS_ACTOR"
        out += [("c_ok", a + ', 0, "cr_box.cos"'), ("c_nil", a + ", 0, nil"), ("c_str", a + ', 0, "cr"'),
                ("c_num", a + ", 0, 1.5"), ("c_tab", a + ", 0, { }"), ("c_chore_big", a + ', 99, "cr_box.cos"'),
                ("c_chore_neg", a + ', -1, "cr_box.cos"'), ("c_chore_str", a + ', "cr", "cr_box.cos"')]
    return out


# Every position of a builtin: valid arguments of the kinds tools/signatures.py found in the game's scripts (OVERRIDES
# where the guess is wrong), with one position at a time replaced by a wrong value (nil, a string, a number, a table; for
# numbers also -1 and 1e9). Keys: p<position>_<what>.
VALID = {"actor": "CR_ARGS_ACTOR", "number": "0", "costume": '"cr_box.cos"', "set": '"cr_flat.set"', "string": '"x"',
         "table": "{ }", "bool": "TRUE", "font": "cr_args_font()", "bitmap": '"cr_obj.bm"', "light": '"cr_light"'}
BAD = [("nil", "nil"), ("str", '"cr"'), ("num", "1.5"), ("tab", "{ }"), ("neg", "-1"), ("big", "1000000000")]
OVERRIDES = {
    "PlayActorChore": ["actor", "number", "costume"], "PlayActorChoreLooping": ["actor", "number", "costume"],
    "StopActorChore": ["actor", "number", "costume"], "CompleteActorChore": ["actor", "number", "costume"],
    "IsActorChoring": ["actor", "number", "bool", "costume"], "SetActorChoreLooping": ["actor", "number", "bool", "costume"],
    "FadeInChore": ["actor", "costume", "number", "number"], "FadeOutChore": ["actor", "costume", "number", "number"],
    "SetActorCostume": ["actor", "costume"], "PushActorCostume": ["actor", "costume"], "GetActorCostume": ["actor", "number"],
    "SetActorWalkChore": ["actor", "number", "costume"], "SetActorRestChore": ["actor", "number", "costume"],
    "SetActorTurnChores": ["actor", "number", "number", "costume"], "SetActorTalkChore": ["actor", "number", "number", "costume"],
    "SetActorMumblechore": ["actor", "number", "costume"], "SayLine": ["actor", "string", "table"],
    "ImStartSound": ["string", "number", "number"], "SetSoundPosition": ["string", "number", "number", "number"],
    "PutActorInSet": ["actor", "set"], "MakeCurrentSet": ["set"], "GetCurrentSetup": ["set"], "LockSet": ["set"],
    "SetActorRot": ["actor", "number", "number", "number", "bool"], "ActorLookAt": ["actor", "number", "number", "number", "number"],
    "MakeTextObject": ["string", "table"], "LockFont": ["string"], "GetPointSector": ["number", "number", "number", "number"],
    "IsPointInSector": ["number", "number", "number", "string"], "MakeSectorActive": ["string", "bool"],
    "SetActorHead": ["actor", "number", "number", "number", "number", "number", "number"],
    "WalkActorVector": ["actor", "actor", "number", "number", "number", "number"],
    "NewObjectState": ["number", "number", "bitmap", "bitmap", "bool"], "GetImage": ["bitmap"],
}


def signatures():
    path = os.path.join(HERE, "tools", "signatures.json")
    sigs = json.load(open(path)) if os.path.exists(path) else {}
    sigs.update(OVERRIDES)
    return sigs


def position_patterns(name, sigs):
    sig = sigs.get(name)
    if not sig:
        return []
    sig = list(sig)
    # (a light builtin names its light first)
    if "Light" in name and sig[0] == "string":
        sig[0] = "light"
    # (p0: all positions valid. When it crashes an engine, run.py skips the whole p group of the builtin at once)
    out = [("p0", ", ".join(VALID.get(x, "0") for x in sig))]
    for i, k in enumerate(sig):
        for bad, expr in BAD:
            if (bad in ("str",) and k in ("string", "costume", "set")) or (bad in ("num", "neg", "big") and k != "number") \
                    or (bad == "tab" and k == "table"):
                continue
            if bad == "str" and k in ("bitmap", "light"):
                continue
            args = [VALID.get(x, "0") for x in sig]
            args[i] = expr
            out.append(("p%d_%s" % (i + 1, bad), ", ".join(args)))
    return out


def builtins():
    names = []
    log = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "expected", "original.log")
    for l in open(log, encoding="latin-1"):
        m = re.match(r"^V builtins\|fn_([A-Za-z_0-9]+)\|", l)
        if m:
            names.append(m.group(1))
    return [n for n in names if n not in DENY and not n.startswith("cr_")]


def main():
    out = ["-- GENERATED by tools/gen_args.py: every builtin of the original with wrong or missing arguments. Do not edit.",
           "",
           "cr_args_fn = function()",
           "end",
           "",
           "-- (the actor the actor builtins get: in cr_flat, following the boxes, with the model costume)",
           "cr_t_args_setup = function()",
           '\tMakeCurrentSet("cr_flat.set")',
           '\tCR_ARGS_ACTOR = LoadActor("cr_args")',
           '\tPutActorInSet(CR_ARGS_ACTOR, "cr_flat.set")',
           "\tPutActorAt(CR_ARGS_ACTOR, 0, 0, 0)",
           "\tSetActorFollowBoxes(CR_ARGS_ACTOR, TRUE)",
           '\tSetActorCostume(CR_ARGS_ACTOR, "cr_box.cos")',
           '\tcr_log("actor", type(CR_ARGS_ACTOR))',
           "end",
           'cr_test("args_setup", cr_t_args_setup)',
           "",
           "-- (each builtin gets an actor of its own, and every call starts from the same state: the set, the actor at the",
           "-- origin facing 0. Otherwise a call that breaks the shared actor makes the calls after it fail, and run.py blames them)",
           "cr_args_for = function(name)",
           "\tif CR_ARGS_FOR ~= name then",
           "\t\tCR_ARGS_FOR = name",
           "\t\tif CR_ARGS_ACTOR then",
           "\t\t\tPutActorInSet(CR_ARGS_ACTOR, nil)",
           "\t\tend",
           '\t\tMakeCurrentSet("cr_flat.set")',
           '\t\tCR_ARGS_ACTOR = LoadActor("cr_args_" .. name)',
           '\t\tPutActorInSet(CR_ARGS_ACTOR, "cr_flat.set")',
           "\t\tSetActorFollowBoxes(CR_ARGS_ACTOR, TRUE)",
           '\t\tSetActorCostume(CR_ARGS_ACTOR, "cr_box.cos")',
           "\tend",
           "\tPutActorAt(CR_ARGS_ACTOR, 0, 0, 0)",
           "\tSetActorRot(CR_ARGS_ACTOR, 0, 0, 0)",
           "end",
           "",
           "-- (fresh handles for the families of tools/gen_args.py)",
           "cr_args_font = function()",
           '\treturn LockFont("cr_font.laf")',
           "end",
           "cr_args_text = function()",
           '\treturn MakeTextObject("abc", { font = cr_args_font(), x = 10, y = 20 })',
           "end",
           "cr_args_prim = function()",
           "\treturn DrawLine(1, 2, 30, 40, { color = MakeColor(1, 2, 3) })",
           "end",
           "cr_args_image = function()",
           '\treturn GetImage("cr_obj.bm")',
           "end",
           "cr_args_obj = function()",
           '\treturn NewObjectState(0, 1, "cr_obj.bm", nil, TRUE)',
           "end",
           "cr_args_color = function()",
           "\treturn MakeColor(10, 20, 30)",
           "end",
           ""]
    n = 0
    sigs = signatures()
    for name in builtins():
        pats = PATTERNS + (ACTOR_PATTERNS if "Actor" in name else []) + family_patterns(name) + position_patterns(name, sigs)
        for key, args in pats:
            n += 1
            fn = "cr_t_args_%d" % n
            out += ["%s = function()" % fn,
                    '\tcr_args_for("%s")' % name,
                    "\tlocal r1, r2, r3, r4 = %s(%s)" % (name, args),
                    '\tcr_log("r", r1, r2, r3, r4)',
                    "end",
                    'cr_test("args_%s_%s", %s)' % (name, key, fn)]
    path = os.path.join(HERE, "tests", "zz_args.lua")
    with open(path, "w", newline="\n") as f:
        f.write("\n".join(out) + "\n")
    print("wrote %s: %d calls of %d builtins" % (path, n, len(builtins())))


if __name__ == "__main__":
    main()
