"""Which Lua builtins the clean-room tests call: coverage.py [--list]

The builtins are the function globals the builtins test logs (fn_<name>) in expected/original.log (the original's) and in
logs/scummvm.log (ScummVM's). A builtin counts as covered when a test file calls it by name, other than in the
generated argument probe (tests/zz_args.lua, which only calls with wrong arguments); probed counts the ones that file calls."""
import os
import re
import sys

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FN = re.compile(r"^V builtins\|fn_([A-Za-z_0-9]+)\|")


def builtins(path):
    if not os.path.exists(path):
        return set()
    return set(m.group(1) for l in open(path, encoding="latin-1") for m in [FN.match(l)] if m)


def called(files):
    text = ""
    for f in files:
        # (comments out)
        text += re.sub(r"--[^\n]*", "", open(f, encoding="latin-1").read()) + "\n"
    return set(re.findall(r"\b([A-Za-z_][A-Za-z_0-9]*)\s*\(", text)) | set(re.findall(r'"([A-Za-z_][A-Za-z_0-9]*)"', text))


def main():
    orig = builtins(os.path.join(HERE, "expected", "original.log"))
    svm = builtins(os.path.join(HERE, "logs", "scummvm.log"))
    tests = os.path.join(HERE, "tests")
    files = [os.path.join(tests, f) for f in sorted(os.listdir(tests)) if f.endswith(".lua") and f != "zz_args.lua"]
    used = called(files)
    probe = os.path.join(tests, "zz_args.lua")
    probed = called([probe]) if os.path.exists(probe) else set()
    names = sorted(orig | svm)
    cov = [n for n in names if n in used]
    pro = [n for n in names if n in probed]
    print("builtins: %d (original %d, ScummVM %d, both %d)" % (len(names), len(orig), len(svm), len(orig & svm)))
    print("called by a test: %d (%.0f%%); in the argument probe: %d; neither: %d" % (
        len(cov), 100.0 * len(cov) / max(1, len(names)), len(pro), len([n for n in names if n not in used and n not in probed])))
    if "--list" in sys.argv:
        for n in names:
            where = "test " if n in used else ("probe" if n in probed else "-    ")
            side = "both" if n in orig and n in svm else ("original only" if n in orig else "ScummVM only")
            print("  %s %-32s %s" % (where, n, side))


if __name__ == "__main__":
    main()
