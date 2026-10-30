#!/usr/bin/env python3
"""Names the set whose sweep (ar_full.lua) came last before the first failure of a chapter in a speed100 run.
  sweep_blame.py <log>   prints "PASSED", or "<set name>|<the failure>", or "?|<the failure>" when no sweep came before it."""
import re, sys
last = None
inside = False
for ln in open(sys.argv[1], errors="replace"):
    if "AUTORUN extra: " in ln:
        t = ln.split("AUTORUN extra: ", 1)[1].strip()
        if t.startswith("done "):
            inside = False
        elif t.startswith("no sweep of ") or t.endswith("did not all work") or t.endswith("(nothing defined)"):
            pass
        else:
            inside = True
            if t.startswith("visit "):
                last = t[6:]
    elif "AUTORUN FAIL" in ln and not inside:
        print((last or "?") + "|" + ln.split("AUTORUN FAIL", 1)[1].strip()[:110])
        sys.exit(0)
    elif "AUTORUN RESULT PASSED" in ln:
        print("PASSED")
        sys.exit(0)
print("?|no result")
