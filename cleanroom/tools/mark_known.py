"""Marks the tests ScummVM is known to get wrong (cr_scummvm_differs), from the last ScummVM run, and unmarks the fixed ones.

  python tools/mark_known.py [--game emi] [scummvm logs...]

The logs default to logs/scummvm_<renderer>.log of each renderer (logs/emi/ for EMI), as run.py scummvm leaves them; each
is compared with expected/original.log. A test that differs with any renderer gets the mark, a marked test that is the
same with every renderer loses it. The marks go next to the test:
  - a hand-written test: cr_scummvm_differs("name") in front of its cr_test("name", ...), on the same line (no line
    number changes: some results hold them); a test made under a computed name ("draw_" .. name) gets it at the end of
    the file that makes it. In a file both games run (tests/common/), the mark names the game: cr_scummvm_differs("name", nil, "grim").
    A mark with a reason (cr_scummvm_differs("name", "why")) is never removed.
  - an argument test of tools/gen_args.py: its name in tools/args_differs.txt (args_differs_emi.txt), and gen_args.py is
    run again.
After it, run.py scummvm reports a test that differs without the mark as a regression."""
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, HERE)
import compare  # noqa: E402
import testfiles  # noqa: E402

EMI = "--game" in sys.argv and sys.argv[sys.argv.index("--game") + 1] == "emi"
if "--game" in sys.argv:
    del sys.argv[sys.argv.index("--game"):sys.argv.index("--game") + 2]
EXPECTED = os.path.join(HERE, "expected", "emi_original.log" if EMI else "original.log")
UNSTABLE = os.path.join(HERE, "expected", "emi_unstable.txt" if EMI else "unstable.txt")
LOGS = os.path.join(HERE, "logs", "emi") if EMI else os.path.join(HERE, "logs")
ARGS_FILE = "zz_args_emi.lua" if EMI else "zz_args.lua"
ARGS_LIST = os.path.join(HERE, "tools", "args_differs_emi.txt" if EMI else "args_differs.txt")
RENDERERS = os.environ.get("CR_RENDERERS", "opengl,opengl_shaders,software").split(",")


def parse(path):
    return compare.parse(open(path, encoding="latin-1").read().splitlines())[1]


TAIL = "\n-- (ScummVM differs: tools/mark_known.py)\n"


games_of = testfiles.games_of


def test_files():
    return [p for p in testfiles.files("emi" if EMI else "grim") if not os.path.basename(p).startswith("zz_args")]


def main():
    logs = sys.argv[1:] or [p for p in (os.path.join(LOGS, "scummvm_%s.log" % r) for r in RENDERERS) if os.path.exists(p)]
    if not logs:
        sys.exit("no ScummVM log: run run.py scummvm first")
    ref = parse(EXPECTED)
    others = [parse(p) for p in logs]
    unstable = compare.load_unstable(UNSTABLE) | compare.marked(ref, *others)
    marks = compare.known(ref, *others)
    differs, same = set(), set()
    for name, a in ref.items():
        if a["status"] == "skipped":
            continue
        diffs = [o.get(name) is None or [l for l, c in compare.test_diff(name, a, o[name], unstable=unstable) if not c]
                 for o in others]
        if any(diffs):
            differs.add(name)
        else:
            same.add(name)
    args = set(n for n in differs | same if n.startswith("args_") and n != "args_setup")
    add = sorted(differs - set(marks))
    drop = sorted(n for n in same if n in marks)

    # the argument tests: the list gen_args.py reads
    listed = set(l.strip() for l in open(ARGS_LIST) if l.strip() and not l.startswith("#")) if os.path.exists(ARGS_LIST) else set()
    new_list = (listed | (set(add) & args)) - (set(drop) & args)
    if new_list != listed:
        with open(ARGS_LIST, "w", newline="\n") as f:
            f.write("# argument tests ScummVM gives differently from the original (tools/mark_known.py; read by gen_args.py)\n")
            f.write("".join(n + "\n" for n in sorted(new_list)))
        subprocess.run([sys.executable, os.path.join(HERE, "tools", "gen_args.py")] + (["--game", "emi"] if EMI else []),
                       check=True)

    # the hand-written tests
    files = dict((p, open(p, encoding="latin-1", newline="").read()) for p in test_files())
    game = "emi" if EMI else "grim"
    unplaced = []
    for name in add:
        if name in args:
            continue
        for p, text in files.items():
            # (a file both games run gets the mark of this game only)
            mark = 'cr_scummvm_differs("%s"%s)' % (name, ', nil, "%s"' % game if len(games_of(p)) > 1 else "")
            # (the other game's marks may be in front of it already)
            m = re.search(r'^[ \t]*(?:cr_scummvm_differs\([^)]*\) )*()cr_test\("%s",' % re.escape(name), text, re.M)
            if m:
                # (on the cr_test's own line: no line number of the file changes, and some results hold them. The mark may
                # be there already: the logs that are read may be older than it)
                if mark + " " not in text[m.start():m.start(1)]:
                    files[p] = text[:m.start(1)] + mark + " " + text[m.start(1):]
                break
        else:
            # (a test made under a computed name: the file with the longest string that starts the name and is joined
            # to something ("cm_" .. how, "draw_" .. name) has it; the mark goes at its end)
            best = None
            for p, text in files.items():
                for x in re.findall(r'"([A-Za-z0-9_]+)"\s*\.\.', text):
                    if name.startswith(x) and (best is None or len(x) > len(best[1])):
                        best = (p, x)
            if best:
                p = best[0]
                mark = 'cr_scummvm_differs("%s"%s)' % (name, ', nil, "%s"' % game if len(games_of(p)) > 1 else "")
                text = files[p]
                if "\n" + mark + "\n" not in text:
                    if TAIL not in text:
                        text = text.rstrip("\n") + "\n" + TAIL
                    files[p] = text + mark + "\n"
            else:
                unplaced.append(name)
    for name in drop:
        if name in args:
            continue
        # (only a mark without a reason, of this game or of every game)
        mark = r'cr_scummvm_differs\("%s"(?:, nil, "%s")?\)' % (re.escape(name), game)
        for p, text in files.items():
            text = re.sub(mark + r" (?=cr_test\()", "", text)
            files[p] = re.sub(r"^" + mark + r"\n", "", text, flags=re.M)
    for p, text in files.items():
        if text != open(p, encoding="latin-1", newline="").read():
            open(p, "w", encoding="latin-1", newline="").write(text)
            print("marked in %s" % os.path.relpath(p, HERE))
    print("%d tests differ, %d marked now, %d unmarked (fixed)%s" % (len(differs), len(add), len(drop),
                                                                     ("; no place found for: " + ", ".join(unplaced)) if unplaced else ""))
    kept = sorted(n for n in drop if n not in args and n in marks and marks[n])
    if kept:
        print("marked with a reason, kept (same now: take the mark out by hand if it is fixed): " + ", ".join(kept))
    return 1 if unplaced else 0


if __name__ == "__main__":
    sys.exit(main())
