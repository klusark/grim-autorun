#!/usr/bin/env python3
"""Names what to block for the first failure of a chapter in a speed100 run (the extras of ar_full.lua).
  sweep_blame.py <log>   prints "PASSED", or "<kind>:<name>|<the failure>", or "?|<the failure>" when nothing came before it.
Kinds (tools/sweep_lib.sh blocks them in ex00_sweep.lua): visit, heavy (by set), talk (by dialog), talker (one person of a set), use (one object,
by its name in the scripts).
What is blamed, first to last: what took the item that the failure names; the first object or extra that took Manny out of his set or took an item;
the last extra before the failure."""
import sys

# notes of the extras: lines that do not start an extra (an extra starts with its tag and ends with "done <tag>")
NOTES = ("no sweep of ", "given up after ", "Manny held ", "no talk to ", "not used: ", "nothing new to say", "the talk ended", "the set was left by ", "an item was taken by ")


def block_of(who):
    """The block for an object name ("bv.bone_wagon") or an extra's tag in brackets ("[people Blue Casket interior olivia_obj]")."""
    if who == "nil" or not who:
        return None
    if who.startswith("[") and who.endswith("]"):
        kind, _, rest = who[1:-1].partition(" ")
        if kind in ("visit", "heavy"):
            return kind + ":" + rest
        if kind == "talk":
            return "talk:" + rest.split()[0]
        if kind == "people":
            # (one person of the set: "<set name> <object field>", AR_NO_TALKER)
            return "talker:" + rest
        return None
    return "use:" + who


last = None
left = None
item_lefts = []
losses = []
lefts = []
chapter = 0
# (how deep in extras the log is: a talk is an extra inside the people extra, and its done line used to end both)
inside = 0
for ln in open(sys.argv[1], errors="replace"):
    if "AUTORUN === chapter " in ln:
        chapter += 1
    if "AUTORUN STALL:" in ln or ("AUTORUN FAIL" in ln and not inside):
        near = [b for c, b in item_lefts + lefts if c >= chapter - 1]
        left = near[0] if near else None
    if "AUTORUN extra: " in ln:
        t = ln.split("AUTORUN extra: ", 1)[1].strip()
        if t.startswith("the set was left by "):
            # (only of this chapter or the one before it when the failure comes: a set left in chapter 2, Eva's talk took Manny to the lobby, is not
            # what breaks chapter 19)
            b = block_of(t[len("the set was left by "):].rsplit(" (now in ", 1)[0])
            if b:
                lefts.append((chapter, b))
        elif t.startswith("an item was taken by "):
            who, _, item = t[len("an item was taken by "):].rpartition(" (")
            b = block_of(who)
            if b:
                losses.append((item.rstrip(")"), b))
                # (one that the failure does not name counts only near it, as a set left: the pot of coffee put back in chapter 54 did not break 57)
                item_lefts.append((chapter, b))
        elif t.startswith("done "):
            inside = max(0, inside - 1)
        elif t.startswith(NOTES) or t.endswith("did not all work") or t.endswith("(nothing defined)") or ": could not come back from " in t or " is left to " in t:
            pass
        else:
            inside += 1
            if t.startswith("visit "):
                last = "visit:" + t[6:]
            elif t.startswith("heavy "):
                last = "heavy:" + t[6:]
            elif t.startswith("talk "):
                last = "talk:" + t.split()[1]
            elif t.startswith("people "):
                last = "talker:" + t[7:]
    elif "AUTORUN STALL:" in ln:
        print((left or last or "?") + "|stalled: " + ln.split("AUTORUN STALL:", 1)[1].strip()[:100])
        sys.exit(0)
    elif "AUTORUN FAIL" in ln and not inside:
        why = ln.split("AUTORUN FAIL", 1)[1]
        for item, b in losses:
            if item and item in why:
                left = b
                break
        print((left or last or "?") + "|" + why.strip()[:110])
        sys.exit(0)
    elif "AUTORUN RESULT FAILED" in ln:
        # (the run ended inside an extra: three waits for the control in a row failed, ar_wait_for_control)
        near = [b for c, b in item_lefts + lefts if c >= chapter - 1]
        print(((near[0] if near else None) or last or "?") + "|the run ended inside an extra (the game never gave control back)")
        sys.exit(0)
    elif "AUTORUN RESULT PASSED" in ln:
        print("PASSED")
        sys.exit(0)
# (a run that ran out of its time limit, ROUND_MAX seconds of tools/sweep_fix.sh: the last extra is blamed, it is not an engine killed from outside)
import os, re
m = re.search(r"scummvm exit: \d+ after (\d+) s", open(sys.argv[1], errors="replace").read())
if m and os.environ.get("ROUND_MAX") and int(m.group(1)) >= int(os.environ["ROUND_MAX"]) - 10:
    print((last or "?") + "|the round ran out of its %s s" % os.environ["ROUND_MAX"])
else:
    print("?|no result")
