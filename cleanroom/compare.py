"""Compares two result logs of the clean-room tests: compare.py <reference.log> <other.log> [--tol X] [--all]

The reference is normally the original's run (expected/original.log). Per test it reports
  same      every value equal (numbers within --tol, default 1e-6: the logs have 6 decimals)
  close     the values that differ are numbers within --close (default 1e-3) of the reference: counted apart, not a failure
  DIFF      a value differs, a key is missing or extra, or the test ended differently (END / FAILED)
  MISSING   the test is not in the other log
A Lua error message (ERROR lines) is engine-specific text, so only the fact that a test raised one is compared.
--unstable FILE: test|key values the reference does not repeat run to run are not compared (expected/unstable.txt).
Keys a test marks with cr_unstable (U lines) in either log are not compared either.
--known: the other log is ScummVM's, and a test marked with cr_scummvm_differs (DIFFERS lines, in either log) is
  known     it differs, as the mark says: not a failure
  FIXED     it is the same now: the mark should go (not a failure either)
  and a test that differs without the mark is a regression.
Exit status 1 when anything differs (with --known: a test that differs without the mark, or is missing)."""
import os
import re
import sys

# (patch.dll writes "DEBUG CR ...", ScummVM "Debug: CR ..."; EMI's grimlaunch hook writes PrintDebug's text as it is)
LINE = re.compile(r"(?:\bDEBUG |Debug: |^)CR (.*?)\s*$")
TOKEN = re.compile(r'"[^"]*"|\S+')


def extract(raw):
    """The CR lines of an engine log, without the engine's prefix."""
    out = []
    for l in raw.splitlines():
        m = LINE.search(l)
        if m:
            out.append(m.group(1))
    return out


def parse(lines):
    tests = {}
    order = []
    cur = None
    for l in lines:
        word, _, rest = l.partition(" ")
        if word == "BEGIN":
            cur = {"status": "running", "values": [], "error": None, "unstable": set()}
            tests[rest] = cur
            order.append(rest)
        elif word == "V":
            name, key, vals = (rest.split("|", 2) + ["", ""])[:3]
            t = tests.setdefault(name, {"status": "running", "values": [], "error": None, "unstable": set()})
            # (a key logged again in the same test is numbered: key, key#2, ...)
            n = sum(1 for k, _ in t["values"] if k == key or k.startswith(key + "#"))
            t["values"].append((key if n == 0 else "%s#%d" % (key, n + 1), TOKEN.findall(vals)))
        elif word == "U":
            name, _, key = rest.partition("|")
            tests.setdefault(name, {"status": "running", "values": [], "error": None, "unstable": set()})["unstable"].add(key)
        elif word == "DIFFERS":
            name, _, why = rest.partition("|")
            tests.setdefault(name, {"status": "running", "values": [], "error": None, "unstable": set()})["differs"] = why
        elif word == "SKIP":
            if rest not in tests:
                order.append(rest)
            tests[rest] = {"status": "skipped", "values": [], "error": None, "unstable": set()}
        elif word in ("END", "FAILED", "TIMEOUT"):
            t = tests.get(rest)
            # (TIMEOUT comes before FAILED and is the one kept)
            if t is not None and t["status"] != "timeout":
                t["status"] = word.lower()
        elif word == "ERROR":
            name, _, msg = rest.partition(" ")
            if name in tests:
                tests[name]["error"] = msg
    return order, tests


def num(s):
    try:
        return float(s)
    except ValueError:
        return None


def load_unstable(path):
    """test|key lines: values the reference does not repeat run to run (written by run.py original --save)."""
    if not path or not os.path.exists(path):
        return set()
    return set(l.strip() for l in open(path) if l.strip() and not l.startswith("#"))


def marked(*tests):
    """The test|key values the tests mark with cr_unstable, in any of the parsed logs given."""
    return set("%s|%s" % (name, k) for ts in tests for name, t in ts.items() for k in t["unstable"])


def known(*tests):
    """{test: reason} of the tests marked with cr_scummvm_differs, in any of the parsed logs given."""
    return dict((name, t["differs"]) for ts in tests for name, t in ts.items() if "differs" in t)


def unstable_keys(runs):
    """The test|key values that differ between parsed runs of the same engine (or that only some runs have)."""
    out = set()
    tables = [dict(((name, k), tuple(v)) for name, t in tests.items() for k, v in t["values"]) for _, tests in runs]
    keys = set().union(*tables)
    for k in keys:
        if len(set(t.get(k) for t in tables)) > 1:
            out.add("%s|%s" % k)
    for name in set().union(*[set(tests) for _, tests in runs]):
        if len(set(tests[name]["status"] if name in tests else None for _, tests in runs)) > 1:
            out.add("%s|(status)" % name)
    return out


def diff_values(a, b, tol, name="", unstable=(), close=0.0):
    """The differences between two value lists [(key, tokens)] as (line, is_close) pairs; is_close: every value is a number within
    `close` of the reference. Keys in unstable are not compared."""
    out = []
    a = [(k, v) for k, v in a if "%s|%s" % (name, k) not in unstable]
    b = [(k, v) for k, v in b if "%s|%s" % (name, k) not in unstable]
    bk = dict(b)
    ak = dict(a)
    for key, ta in a:
        if key not in bk:
            out.append(("  %-24s missing (reference: %s)" % (key, " ".join(ta)), False))
            continue
        tb = bk[key]
        bad = len(ta) != len(tb)
        far = bad
        worst = 0.0
        for x, y in zip(ta, tb):
            nx, ny = num(x), num(y)
            if nx is not None and ny is not None:
                d = abs(nx - ny)
                worst = max(worst, d)
                bad |= d > tol
                far |= d > close
            else:
                bad |= x != y
                far |= x != y
        if bad:
            out.append(("  %-24s %s  vs  %s%s" % (key, " ".join(ta), " ".join(tb), ("  (max diff %g)" % worst) if worst else ""),
                        not far))
    for key, tb in b:
        if key not in ak:
            out.append(("  %-24s extra: %s" % (key, " ".join(tb)), False))
    return out


def test_diff(name, a, b, tol=1e-6, unstable=(), close=1e-3):
    """diff_values of one test, with how it ended and whether it raised a Lua error."""
    lines = diff_values(a["values"], b["values"], tol, name, unstable, close)
    if a["status"] != b["status"] and "%s|(status)" % name not in unstable:
        lines.insert(0, ("  ended: %s vs %s" % (a["status"], b["status"]), False))
    if (a["error"] is None) != (b["error"] is None):
        lines.insert(0, ("  Lua error: %s vs %s" % (a["error"], b["error"]), False))
    return lines


def main(argv):
    tol = 1e-6
    close = 1e-3
    show_all = False
    files = []
    unstable_path = None
    use_known = False
    i = 0
    while i < len(argv):
        if argv[i] == "--tol":
            tol = float(argv[i + 1])
            i += 1
        elif argv[i] == "--close":
            close = float(argv[i + 1])
            i += 1
        elif argv[i] == "--unstable":
            unstable_path = argv[i + 1]
            i += 1
        elif argv[i] == "--all":
            show_all = True
        elif argv[i] == "--known":
            use_known = True
        else:
            files.append(argv[i])
        i += 1
    if len(files) != 2:
        print(__doc__)
        return 2
    logs = []
    for f in files:
        text = open(f, encoding="latin-1").read()
        lines = text.splitlines()
        if not any(l.startswith(("BEGIN", "START")) for l in lines):
            lines = extract(text)
        logs.append(parse(lines))
    (order_a, ta), (order_b, tb) = logs
    unstable = load_unstable(unstable_path) | marked(ta, tb)
    marks = known(ta, tb) if use_known else {}
    bad = 0
    near = 0
    n_known = []
    fixed = []
    print("reference %s\nother     %s" % tuple(files))
    for name in order_a + [n for n in order_b if n not in ta]:
        a, b = ta.get(name), tb.get(name)
        if a is None:
            print("%-26s EXTRA (not in the reference)" % name)
            continue
        if b is None:
            print("%-26s MISSING" % name)
            bad += 1
            continue
        lines = test_diff(name, a, b, tol, unstable, close)
        skipped = sum(1 for k, _ in a["values"] if "%s|%s" % (name, k) in unstable)
        if name in marks and lines and not all(c for _, c in lines):
            n_known.append(name)
            print("%-26s known (%d: %s)" % (name, len(lines), marks[name] or "marked cr_scummvm_differs"))
            if show_all:
                for l, _ in lines:
                    print(l)
        elif name in marks and not lines:
            fixed.append(name)
            print("%-26s FIXED (marked cr_scummvm_differs, now the same: the mark should go)" % name)
        elif lines and all(c for _, c in lines):
            near += 1
            print("%-26s close (%d values within %g)" % (name, len(lines), close))
            if show_all:
                for l, _ in lines:
                    print(l)
        elif lines:
            bad += 1
            print("%-26s %s (%d)" % (name, "REGRESSION" if use_known else "DIFF", len(lines)))
            for l, _ in lines[:None if show_all else 12]:
                print(l)
            if len(lines) > 12 and not show_all:
                print("  ... %d more (--all)" % (len(lines) - 12))
        else:
            print("%-26s same (%d values)%s" % (name, len(a["values"]) - skipped,
                                                  (", %d unstable in the reference not compared" % skipped) if skipped else ""))
    same = len(order_a) - bad - near - len(n_known) - len(fixed)
    if use_known:
        print("%d of %d tests differ without a cr_scummvm_differs mark (regressions), %d differ as marked (known), "
              "%d marked are the same now (fixed), %d are close (within %g), %d the same" %
              (bad, len(order_a), len(n_known), len(fixed), near, close, same))
        if fixed:
            print("fixed, take the mark out: %s" % ", ".join(fixed))
    else:
        print("%d of %d tests differ, %d are close (within %g), %d the same" % (bad, len(order_a), near, close, same))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
