#!/usr/bin/env python3
"""Compares the FTEV lines (fullcmp_lib.lua: the calls that change what the game does, with the frame they were made in) of two runs, chapter by chapter.

  evcmp.py <log A> <log B> [chapter prefix] [lines of context]

For every chapter the first event that is not the same in both (another call, other arguments, or the same call in another frame) with the events around it.
The frames are counted from the start of the chapter (the first frame line after "AUTORUN start in"). An actor in an argument is "u<n>", numbered in the order they
first appear in a run, so that the numbers of the two runs agree as long as the same actors are touched in the same order."""
import re
import sys

CHM = re.compile(r"=== chapter (\S+) ===")
FTE = re.compile(r"FTEV (\d+) (.*)")
FT = re.compile(r"FT (\d+) ")


def load(path):
    chapters = {}
    order = []
    cur = None
    base = None
    waiting = False
    pending = []
    for line in open(path, errors="ignore"):
        m = CHM.search(line)
        if m:
            cur = m.group(1)
            if cur not in chapters:
                order.append(cur)
            chapters[cur] = []
            base = None
            waiting = False
            pending = []
            continue
        if cur is None:
            continue
        if "AUTORUN start in" in line:
            waiting = True
            pending = []
            chapters[cur] = []
            base = None
            continue
        m = FT.search(line)
        if m and "FTEV" not in line:
            if base is None:
                base = int(m.group(1))
                for fr, txt in pending:
                    chapters[cur].append((fr - base, txt))
                pending = []
            continue
        m = FTE.search(line)
        if m:
            fr = int(m.group(1))
            if base is None:
                pending.append((fr, m.group(2).strip()))
            else:
                chapters[cur].append((fr - base, m.group(2).strip()))
    return chapters, order


def main():
    a, oa = load(sys.argv[1])
    b, ob = load(sys.argv[2])
    only = sys.argv[3] if len(sys.argv) > 3 else ""
    ctx = int(sys.argv[4]) if len(sys.argv) > 4 else 4
    rows = []
    for name in oa:
        if name not in b or (only and not name.startswith(only)):
            continue
        x, y = a[name], b[name]
        n = min(len(x), len(y))
        first = None
        for i in range(n):
            if x[i] != y[i]:
                first = i
                break
        if first is None and len(x) != len(y) and n > 0:
            first = n
        rows.append((name, len(x), len(y), first))
        if first is not None:
            print("\n== %s: first event that differs: number %d (frame %s / %s)" % (
                name, first, x[first][0] if first < len(x) else "-", y[first][0] if first < len(y) else "-"))
            for i in range(max(0, first - ctx), min(max(len(x), len(y)), first + ctx + 1)):
                l = "%6d %-60s" % (x[i][0], x[i][1][:60]) if i < len(x) else " " * 67
                r = "%6d %s" % (y[i][0], y[i][1][:60]) if i < len(y) else ""
                print("  %s %s| %s" % ("*" if i == first else " ", l, r))
    print("\n%-32s %8s %8s  first difference" % ("chapter", "A events", "B events"))
    for name, la, lb, first in rows:
        print("%-32s %8d %8d  %s" % (name, la, lb, "none" if first is None else "event %d" % first))


main()
