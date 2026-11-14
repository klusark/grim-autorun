"""Writes tests/grim/zz_args.lua: every Lua builtin of the original called with wrong or missing arguments, one test per call.

  python tools/gen_args.py [log with the builtins test, default expected/original.log]
  python tools/gen_args.py --game emi [log]   EMI: tests/emi/zz_args_emi.lua from expected/emi_original.log (the builtins of
                                              Monkey4.exe; no costume, font, image or object state: EMI has none of ours)

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
sys.path.insert(0, HERE)
import testfiles  # noqa: E402

DENY = set("""
exit Load Save dofile InputDialog QueryDialog StartFullscreenMovie StartMovie NukeResources DetachFromResources AttachToResources
RenderModeUser EngineDisplay SetHardwareState SetVideoDevices EnumerateVideoDevices Enumerate3DDevices GetVideoDevices
SpewStartup SpewShutdown LightMgrShutdown ImStartRecording ImStopRecording EnginePause EngineResume ScreenShot SaveScreen
SubmitSaveGameData GetSaveGameData SaveIMuse RestoreIMuse SetGamma quiet play vfx TEST DumpMemoryLog FindFileOnAnyCD
SearchForFileOrSwapCDs BOOT execute remove rename tmpname writeto appendto readfrom write read setlocale debug print_stack
pause_scripts unpause_scripts pause_script unpause_script stop_script start_script sleep_for break_here next_script
seterrormethod setfallback settagmethod copytagmethods setglobal rawsetglobal
""".split())

# (EMI's own: writing the registry or files, unloading the resources the run needs, its movies, dialogs and saves)
EMI_DENY = set("""
WriteRegistryValue ReadRegistryValue WriteSetToFile PurgeAllResources PurgeUnlockedResources PurgeUnusedResources PurgeAmount
PurgeText PurgePrimitiveQueue ReportAllResources ReportLRUResources ReportUnusedResources ReportUsedResources LoadBundle
NukeAllScriptLocks ThumbnailFromFile ThumbnailFromScreen ScreenshotForSavegame EscapeMovie PauseMovie StopMovie LightMgrStartup
FRUTEY_Begin FRUTEY_End SetMemoryUsage SetActiveCD Display main identify_script
""".split())
EMI = "--game" in sys.argv and sys.argv[sys.argv.index("--game") + 1] == "emi"
if EMI:
    del sys.argv[sys.argv.index("--game"):sys.argv.index("--game") + 2]
    DENY |= EMI_DENY

# (builtins whose result is not meant to repeat run to run, and with which arguments (None: all): their tests mark it with
# cr_unstable. Times, memory and disk sizes, the date, addresses; collectgarbage counts the objects of the test sources;
# EMI's GammaEnabled says what the renderer can do (1 with Direct3D, nil with OpenGL).
# GetActorNodeLocation with a negative node and GetVisibleThings(function) gave other values in other saves (what they
# read is not set, it seems), and EMI's ImStateHasEnded / ImStateHasLooped(1.5) depend on how far the music has got)
UNSTABLE = {"GetTickCount": None, "GetMemoryUsage": None, "GetDiskFreeSpace": None, "ResReport": None,
            "collectgarbage": None, "date": ["none"], "tostring": ["fn", "tab"], "GammaEnabled": None,
            "GetActorNodeLocation": ["p2_neg"], "GetVisibleThings": ["fn"],
            "ImStateHasEnded": ["num"], "ImStateHasLooped": ["num"]}
# (the argument tests ScummVM is known to give differently: cr_scummvm_differs; tools/mark_known.py writes the list)
DIFFERS_LIST = os.path.join(HERE, "tools", "args_differs_emi.txt" if EMI else "args_differs.txt")
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
        if EMI and key not in ("k", "l", "s", "e"):
            continue
        if re.search(rx, name):
            out += [(key, first), (key + "_nil", first + ", nil"), (key + "_str", first + ', "cr"'),
                    (key + "_num", first + ", 1.5"), (key + "_tab", first + ", { }")]
    if "Chore" in name and "Actor" in name and not EMI:
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
    # (the signatures are the ones of Grim's scripts)
    sig = None if EMI else sigs.get(name)
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
    log = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "expected", "emi_original.log" if EMI else "original.log")
    for l in open(log, encoding="latin-1"):
        m = re.match(r"^V builtins\|fn_([A-Za-z_0-9]+)\|", l)
        if m:
            names.append(m.group(1))
    # (and not the globals the tests define: the builtins test sees every function, the tests' helpers too)
    own = set()
    for p in testfiles.all_files():
        if not os.path.basename(p).startswith("zz_args"):
            text = open(p, encoding="latin-1").read()
            own |= set(re.findall(r"^(?:function\s+)?([A-Za-z_][A-Za-z_0-9]*)\s*[=(]", text, re.M))
    return [n for n in names if n not in DENY and n not in own and not n.startswith("cr_")]


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
    differs = set()
    if os.path.exists(DIFFERS_LIST):
        differs = set(l.strip() for l in open(DIFFERS_LIST) if l.strip() and not l.startswith("#"))
    for name in builtins():
        pats = PATTERNS + (ACTOR_PATTERNS if "Actor" in name else []) + family_patterns(name) + position_patterns(name, sigs)
        for key, args in pats:
            n += 1
            fn = "cr_t_args_%d" % n
            out += ["%s = function()" % fn,
                    '\tcr_args_for("%s")' % name,
                    "\tlocal r1, r2, r3, r4 = %s(%s)" % (name, args),
                    # (the marks go on lines that are there anyway: a mark does not move the lines after it)
                    "\t" + ('cr_unstable("r") ' if name in UNSTABLE and (UNSTABLE[name] is None or key in UNSTABLE[name])
                            else "") + 'cr_log("r", r1, r2, r3, r4)']
            if name == "NewObjectState":
                # (the state goes again: one without a bitmap that loads stays in the set otherwise, and ScummVM crashes on
                # it in the next NewObjectState (Set::findState reads its bitmap's name), so run.py blamed each call after
                # it in turn. The original returns a state for every call)
                out.append('\tif type(r1) == "userdata" then FreeObjectState(r1) end')
            out += ["end",
                    ('cr_scummvm_differs("args_%s_%s") ' % (name, key) if "args_%s_%s" % (name, key) in differs else "")
                    + 'cr_test("args_%s_%s", %s)' % (name, key, fn)]
    if EMI:
        # (no costume of EMI's yet, no font, image or object state)
        out = [l for l in out if "SetActorCostume" not in l]
        # (UnloadActor's calls free the actor: ScummVM crashes when the next builtin takes the freed actor out of the set, and
        # run.py blamed each builtin after it in turn. emi_actors' ea_unloaded has that call by itself)
        i = out.index("\t\tCR_ARGS_FOR = name")
        assert out[i + 1] == "\t\tif CR_ARGS_ACTOR then"
        out[i:i + 2] = ['\t\tif CR_ARGS_ACTOR and CR_ARGS_FOR ~= "UnloadActor" then']
        out.insert(i + 3, "\t\tCR_ARGS_FOR = name")
    path = os.path.join(testfiles.TESTS, "emi" if EMI else "grim", "zz_args_emi.lua" if EMI else "zz_args.lua")
    with open(path, "w", newline="\n") as f:
        f.write("\n".join(out) + "\n")
    print("wrote %s: %d calls of %d builtins" % (path, n, len(builtins())))


if __name__ == "__main__":
    main()
