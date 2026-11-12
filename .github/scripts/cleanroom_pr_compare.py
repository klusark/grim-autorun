"""Compares the clean-room runs of a ScummVM PR with the runs of its base (.github/workflows/scummvm-pr.yml).

  cleanroom_pr_compare.py <cleanroom dir> <base runs> <pr runs> <renderers> [summary.md]

<cleanroom dir> is the clean room of the tests' branch (its compare.py and expected/), <base runs> and <pr runs> the
run/ folders of tools/parallel.sh (parallel_grim/grim_<renderer>/logs/scummvm_<renderer>.log, parallel_emi/emi_<renderer>/
logs/emi/...); <base runs> may be missing (no base run).

With no base run, the PR's runs are judged as run.py does: a test that differs from the original without a
cr_scummvm_differs mark, or crashes or hangs ScummVM without one, fails.
With a base run, each side is compared with the original (compare.py --known), and the PR with the base directly:
  new regressions  differ from the original without a mark with the PR, not with the base: the PR broke them (failure)
  new crashers     crash or hang ScummVM with the PR, not with the base (failure)
  fixed            differ from the original (or crashed) with the base, not with the PR
  changed          any value the PR gives differently from the base (information: marked tests, and fixes, are in it too)
Exit status 1 on a new regression or crasher, or a missing log."""
import contextlib
import io
import os
import re
import sys

STATUS = re.compile(r"^(\S+)\s+(REGRESSION|MISSING|DIFF|known|FIXED|close|same|EXTRA)\b")
BAD = ("REGRESSION", "MISSING")


def statuses(compare, args):
    out = io.StringIO()
    with contextlib.redirect_stdout(out):
        compare.main(args)
    result = {}
    for line in out.getvalue().splitlines():
        m = STATUS.match(line)
        if m:
            result[m.group(1)] = m.group(2)
    return result, out.getvalue()


def print_tests(out, tests):
    """The lines compare.py gave for these tests: each one's status line and its value lines under it."""
    keep = False
    for l in out.splitlines():
        m = STATUS.match(l)
        if m or not l.startswith(" "):
            keep = bool(m) and m.group(1) in tests
        if keep:
            print(l)


def has_tests(compare, log):
    """The log is there and has tests in it (a run that stopped at once leaves one with none)."""
    if not os.path.exists(log):
        return False
    return bool(compare.parse(open(log, encoding="latin-1").read().splitlines())[1])


def crashers(logs, renderer):
    p = os.path.join(logs, "scummvm_crashers_%s.txt" % renderer)
    if not os.path.exists(p):
        return set()
    return {l.strip() for l in open(p) if l.strip() and not l.startswith("#")}


def names(items, limit=30):
    items = sorted(items)
    if not items:
        return "-"
    return ", ".join("`%s`" % n for n in items[:limit]) + (" ... (%d)" % len(items) if len(items) > limit else "")


def main(argv):
    if len(argv) < 4:
        print(__doc__)
        return 2
    cleanroom, base_dir, pr_dir, renderers = argv[:4]
    summary = argv[4] if len(argv) > 4 else None
    sys.path.insert(0, cleanroom)
    import compare
    has_base = os.path.isdir(base_dir)
    rows = []
    details = []
    failed = False
    for game in ("grim", "emi"):
        expected = os.path.join(cleanroom, "expected", "original.log" if game == "grim" else "emi_original.log")
        unstable = os.path.join(cleanroom, "expected", "unstable.txt" if game == "grim" else "emi_unstable.txt")
        for r in renderers.split(","):
            sub = os.path.join("parallel_%s" % game, "%s_%s" % (game, r), "logs", *(["emi"] if game == "emi" else []))
            pr_logs = os.path.join(pr_dir, sub)
            base_logs = os.path.join(base_dir, sub)
            pr_log = os.path.join(pr_logs, "scummvm_%s.log" % r)
            base_log = os.path.join(base_logs, "scummvm_%s.log" % r)
            label = "%s %s" % (game, r)
            if not has_tests(compare, pr_log) or (has_base and not has_tests(compare, base_log)):
                rows.append("| %s | no log (the run did not finish: see its job) |%s" % (label, " |" * (4 if has_base else 1)))
                failed = True
                continue
            pr_st, pr_out = statuses(compare, [expected, pr_log, "--unstable", unstable, "--known"])
            pr_bad = {n for n, s in pr_st.items() if s in BAD}
            pr_crash = crashers(pr_logs, r)
            if not has_base:
                # (as run.py: a crash of a test marked cr_scummvm_differs is a known one)
                marks = compare.known(*[compare.parse(open(p, encoding="latin-1").read().splitlines())[1]
                                        for p in (expected, pr_log)])
                crash_new = pr_crash - set(marks)
                reg = pr_bad - pr_crash
                if reg or crash_new:
                    failed = True
                rows.append("| %s | %d | %d (%d marked) |" % (label, len(reg), len(crash_new), len(pr_crash - crash_new)))
                details.append("#### %s\n- regressions: %s\n- crashers without a mark: %s\n- crashers marked: %s\n"
                               % (label, names(reg), names(crash_new), names(pr_crash - crash_new)))
                if reg:
                    print("==== %s: the regressions" % label)
                    print_tests(pr_out, reg)
                continue
            base_st, _ = statuses(compare, [expected, base_log, "--unstable", unstable, "--known"])
            base_bad = {n for n, s in base_st.items() if s in BAD}
            base_crash = crashers(base_logs, r)
            new_reg = pr_bad - base_bad - pr_crash
            new_crash = pr_crash - base_crash
            fixed = (base_bad | base_crash) - pr_bad - pr_crash
            changed_st, changed_out = statuses(compare, [base_log, pr_log, "--unstable", unstable])
            changed = {n for n, s in changed_st.items() if s in ("DIFF", "MISSING")}
            if new_reg or new_crash:
                failed = True
            rows.append("| %s | %d | %d | %d | %d | %d (base %d) |" % (label, len(new_reg), len(new_crash), len(fixed),
                                                                       len(changed), len(pr_bad), len(base_bad)))
            details.append("#### %s\n- new regressions: %s\n- new crashers: %s\n- fixed: %s\n- changed: %s\n"
                           % (label, names(new_reg), names(new_crash), names(fixed), names(changed)))
            # (the values of the tests that changed, as compare.py gives them, in the job's log)
            print("==== %s: the PR against the base" % label)
            print("\n".join(l for l in changed_out.splitlines() if not re.match(r"^\S+\s+(same|close)\b", l)))
            if new_reg:
                print("==== %s: the new regressions against the original" % label)
                print_tests(pr_out, new_reg)
    if has_base:
        head = ("| run | new regressions | new crashers | fixed | changed from the base | unmarked differences, PR |\n"
                "|---|---|---|---|---|---|")
    else:
        head = ("| run | regressions (differ without a mark) | crashed or hung without a mark |\n"
                "|---|---|---|")
    text = "%s\n%s\n\n%s\n%s\n" % (
        "### Clean-room tests: the PR " + ("against its base" if has_base else "against the original"),
        head + "\n" + "\n".join(rows), "\n".join(details),
        "**%s**" % (("The PR breaks tests" if has_base else "Tests fail") + " (or a run did not finish)." if failed else
                    "No test is broken by the PR." if has_base else "Every test is as the original, or as its mark says."))
    print(text)
    if summary:
        with open(summary, "a", encoding="utf-8") as f:
            f.write(text)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
