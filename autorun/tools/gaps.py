#!/usr/bin/env python3
"""Lists the stretches of a run in which the log has no AUTORUN line for at least N seconds.

  python gaps.py <log>.ts [seconds, default 5] [--chapters <log>]

The side file is made by logts.py (run_all.sh does it). Each gap is shown with the line before it, the line after it and the chapter, longest first.
"""
import re
import sys


def main():
    path = sys.argv[1]
    limit = float(sys.argv[2]) if len(sys.argv) > 2 and not sys.argv[2].startswith("--") else 5.0
    rows = []
    for line in open(path, encoding="utf-8", errors="replace"):
        ms, _, text = line.rstrip("\n").partition("\t")
        if ms.isdigit():
            rows.append((int(ms), text))
    chapter = "start"
    gaps = []
    for i in range(1, len(rows)):
        m = re.search(r"=== chapter (\S+) ===", rows[i - 1][1])
        if m:
            chapter = m.group(1)
        d = (rows[i][0] - rows[i - 1][0]) / 1000.0
        if d >= limit:
            gaps.append((d, chapter, rows[i - 1][1], rows[i][1], rows[i - 1][0] / 1000.0))
    total = sum(g[0] for g in gaps)
    print("%d gaps of %.1f s or more in %d lines, %.0f s in all, run %.0f s" % (len(gaps), limit, len(rows), total, rows[-1][0] / 1000.0 if rows else 0))
    for d, ch, a, b, at in sorted(gaps, reverse=True):
        a = re.sub(r"^Debug: AUTORUN ", "", a)
        b = re.sub(r"^Debug: AUTORUN ", "", b)
        print("%6.1f s at %6.0f s  %-24s | %s\n%34s| %s" % (d, at, ch, a[:110], "", b[:110]))


if __name__ == "__main__":
    main()
