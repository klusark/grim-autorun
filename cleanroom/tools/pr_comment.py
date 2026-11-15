"""The pull request comment of the clean-room CI (this repository's pr.yml, grim-decomp's build.yml): what failed, from
run.py's output (the tests that differ from the original, each with the first lines of what differs, and the tests that
crashed or hung the engine), and posts it on the PR, or edits the comment an earlier run posted.

    python pr_comment.py --job NAME RESULT [OUTPUT ...] [--job ...] --url RUN_URL --out comment.md [--post OWNER/REPO PR]

A job is one CI job: its result (success, failure, cancelled, skipped) and the files run.py's output went to (a file of
tools/parallel.sh holds a renderer's run, "==== scummvm, renderer <r>" first). --post (with gh and GH_TOKEN): a failing run
posts or edits the comment; a passing one only edits a comment an earlier run left, no new comment.
"""
import argparse
import json
import os
import re
import subprocess
import sys

MARKER = "<!-- grim cleanroom ci -->"
DETAIL_LINES = 8     # (of each failing test; the run's summary and its logs have the rest)
MAX_TESTS = 40       # (of each section: a comment is at most 65536 characters)
MAX_CHARS = 60000

TEST = re.compile(r"^(\S+)\s+(DIFF|REGRESSION) \((\d+)\)\s*$|^(\S+)\s+(MISSING|EXTRA)\b.*$")


def parse(lines):
    """The sections of an output: [(label or None, failed [(name, status, detail lines)], crashed [names], count line)]."""
    sections = []
    cur = [None, [], [], None]
    test = None
    for l in lines:
        if l.startswith("==== "):
            m = re.match(r"^==== \S+, renderer (\S+)", l)
            if cur[1] or cur[2] or cur[3]:
                sections.append(tuple(cur))
            cur = [m.group(1) if m else None, [], [], None]
            test = None
            continue
        m = TEST.match(l)
        if m:
            test = (m.group(1) or m.group(4), m.group(2) or m.group(5), [])
            cur[1].append(test)
            continue
        if test and l.startswith("  "):
            test[2].append(l)
            continue
        test = None
        if l.startswith("crashed or hung the rebuilt exe: "):
            cur[2] += [n.strip() for n in l.split(": ", 1)[1].split(",") if n.strip()]
        elif l.startswith("crashed or hung ScummVM") and "; not marked: " in l:
            # (only the ones without a cr_scummvm_differs mark fail the run)
            cur[2] += [n.strip() for n in l.split("; not marked: ", 1)[1].split(",") if n.strip()]
        elif re.match(r"^\d+ of \d+ tests differ", l):
            cur[3] = l.strip()
    if cur[1] or cur[2] or cur[3]:
        sections.append(tuple(cur))
    return sections


def read(path):
    try:
        return open(path, encoding="utf-8-sig", errors="replace").read().splitlines()
    except OSError:
        return None


def code(names):
    return ", ".join("`%s`" % n for n in names[:MAX_TESTS]) + (" and %d more" % (len(names) - MAX_TESTS)
                                                                if len(names) > MAX_TESTS else "")


def job_md(name, result, paths):
    if result == "success":
        return ["#### :white_check_mark: %s" % name]
    md = ["#### :x: %s (%s)" % (name, result)]
    outputs = [(p, read(p)) for p in paths]
    outputs = [(p, l) for p, l in outputs if l is not None]
    if not outputs:
        md.append("No test output: the job ended (%s) before the tests ran; see the run." % result)
        return md
    found = False
    for path, lines in outputs:
        for label, failed, crashed, count in parse(lines):
            if not failed and not crashed:
                continue
            found = True
            where = os.path.splitext(os.path.basename(path))[0]
            md.append("\n**%s%s**%s" % (where, ", renderer %s" % label if label and label not in where else "",
                                        ": " + count if count else ""))
            if crashed:
                md.append("- crashed or hung (%d): %s" % (len(crashed), code(crashed)))
            extra = [n for n, status, _ in failed if status == "EXTRA"]
            failed = [t for t in failed if t[1] != "EXTRA"]
            if extra:
                # (a test without the original's values: run.py original --save on the original records them)
                md.append("- not in the reference, no values of the original yet (%d): %s" % (len(extra), code(extra)))
            if failed:
                md.append("- differ from the original (%d): %s" % (len(failed), code([n for n, _, _ in failed])))
                md.append("")
                for n, status, detail in failed[:MAX_TESTS]:
                    body = detail[:DETAIL_LINES] + (["  ... %d more" % (len(detail) - DETAIL_LINES)]
                                                    if len(detail) > DETAIL_LINES else [])
                    md.append("<details><summary><code>%s</code> %s%s</summary>\n\n```\n%s\n```\n</details>" %
                              (n, status, " (%d differences)" % len(detail) if detail else "",
                               "\n".join(l[:300] for l in body) or "(not in the engine's log)"))
    if not found:
        # (run.py stopped before the comparison, or failed some other way: the end of its output)
        for path, lines in outputs:
            md.append("\nNo failing test in `%s`; its last lines:\n\n```\n%s\n```" %
                      (os.path.basename(path), "\n".join(l[:300] for l in lines[-25:]) or "(empty)"))
    return md


def post(md, repo, pr, failed):
    def gh(*args, data=None):
        return subprocess.run(["gh", "api", *args] + (["--input", "-"] if data else []), check=True, text=True,
                              capture_output=True, input=json.dumps(data) if data else None).stdout
    ids = gh("--paginate", "repos/%s/issues/%s/comments" % (repo, pr), "--jq",
             '.[] | select(.user.login == "github-actions[bot]" and (.body | startswith("%s"))) | .id' % MARKER).split()
    if ids:
        gh("-X", "PATCH", "repos/%s/issues/comments/%s" % (repo, ids[-1]), data={"body": md})
        print("edited comment %s" % ids[-1])
    elif failed:
        gh("-X", "POST", "repos/%s/issues/%s/comments" % (repo, pr), data={"body": md})
        print("posted a comment")
    else:
        print("passes, and no earlier comment: none posted")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--job", nargs="+", action="append", required=True, metavar="NAME RESULT [OUTPUT ...]")
    ap.add_argument("--url", default="")
    ap.add_argument("--out", required=True)
    ap.add_argument("--post", nargs=2, metavar=("OWNER/REPO", "PR"))
    a = ap.parse_args()
    failed = any(j[1:2] != ["success"] for j in a.job)
    md = [MARKER, "### %s Clean-room tests %s" % ((":x:", "fail") if failed else (":white_check_mark:", "pass"))]
    for j in a.job:
        md.append("")
        md += job_md(j[0], j[1] if len(j) > 1 else "unknown", j[2:])
    if a.url:
        md.append("\n[The run: its summary and logs](%s)" % a.url)
    text = "\n".join(md) + "\n"
    if len(text) > MAX_CHARS:
        text = text[:MAX_CHARS] + "\n\n... (cut: the run has the rest)\n" + ("[The run](%s)\n" % a.url if a.url else "")
    open(a.out, "w", encoding="utf-8").write(text)
    if a.post:
        post(text, a.post[0], a.post[1], failed)
    return 0


if __name__ == "__main__":
    sys.exit(main())
