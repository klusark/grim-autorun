#!/usr/bin/env python3
"""Compares the frame traces (FT lines of fullcmp_lib.lua) of two runs of the whole game, chapter by chapter.

  ftrace_cmp.py <log A> <log B> [pos tol m] [yaw tol deg] [lines of context] [chapter prefix]

Each chapter of A is aligned with the same chapter of B at its first frame (the FTCHAPTER lines), so that a difference in one chapter does not hide the
next. For every chapter: the number of frames compared, the first frame in which the set, the cutscene level, the position or the angles of Manny differ
by more than the tolerances, and the lines around it. When a chapter ran more than once in a log (the original restarts a chapter that failed) the last
run is the one compared. Writes a summary table at the end."""
import re
import sys

FT = re.compile(r"FT (\d+) (\d+) (.*?) c(\d+) M (-?[\d.]+) (-?[\d.]+) (-?[\d.]+) (-?[\d.]+) (-?[\d.]+) (-?[\d.]+)")
CH = re.compile(r"FTCHAPTER (\S+) (\d+)")


BIG = 10000000
CHM = re.compile(r"=== chapter (\S+) ===")


def load(path):
    frames = {}
    chapters = []  # (name, first frame) in the order they appear, the last run of a chapter wins
    pending = None
    attempt = 0
    last = -1
    marked = None
    chapter_idx = 0
    waiting_start = False
    for line in open(path, errors="ignore"):
        m = CH.search(line)
        if m:
            # (the chapter starts at the next frame line after "AUTORUN start in", which is logged when the checkpoint of the chapter has been loaded: a
            # load takes a different number of frames in the two engines; a chapter that is not loaded from a save starts at the mark)
            chapters.append((m.group(1), attempt * BIG + int(m.group(2))))
            marked = m.group(1)
            chapter_idx = len(chapters) - 1
            continue
        if "AUTORUN start in" in line and marked is not None:
            waiting_start = True
            continue
        m = CHM.search(line)
        if m:
            # (the log of the script itself: the chapter starts at the next frame line, when the trace has no marks of its own)
            pending = m.group(1)
            continue
        m = FT.search(line)
        if m:
            fr = int(m.group(1))
            if waiting_start and marked is not None:
                # (the frame counter of a loaded game continues from the save: the frames of the load before it are not the chapter)
                chapters[chapter_idx] = (marked, attempt * BIG + fr)
                waiting_start = False
                marked = None
            if fr < last:
                attempt += 1  # (the frame counter starts again: the game was started again from a checkpoint)
            last = fr
            if pending is not None:
                chapters.append((pending, attempt * BIG + fr))
                pending = None
            frames[attempt * BIG + fr] = (int(m.group(2)), m.group(3), int(m.group(4)), float(m.group(5)), float(m.group(6)), float(m.group(7)), float(m.group(8)), float(m.group(9)) % 360.0, float(m.group(10)))
    return frames, chapters


def spans(chapters, last_frame):
    out = {}
    for i, (name, start) in enumerate(chapters):
        end = chapters[i + 1][1] if i + 1 < len(chapters) else last_frame + 1
        out[name] = (start, end)  # the last run of a chapter replaces an earlier one
    return out


def main():
    a, ca = load(sys.argv[1])
    b, cb = load(sys.argv[2])
    ptol = float(sys.argv[3]) if len(sys.argv) > 3 else 0.01
    ytol = float(sys.argv[4]) if len(sys.argv) > 4 else 0.5
    ctx = int(sys.argv[5]) if len(sys.argv) > 5 else 6
    only = sys.argv[6] if len(sys.argv) > 6 else ""
    sa = spans(ca, max(a) if a else 0)
    sb = spans(cb, max(b) if b else 0)
    print("A: %d frames, %d chapter marks; B: %d frames, %d chapter marks" % (len(a), len(ca), len(b), len(cb)))
    rows = []
    for name in sorted(set(sa) & set(sb)):
        if only and not name.startswith(only):
            continue
        (a0, a1), (b0, b1) = sa[name], sb[name]
        n = min(a1 - a0, b1 - b0)
        first = None
        why = ""
        for k in range(n):
            x, y = a.get(a0 + k), b.get(b0 + k)
            if x is None or y is None:
                continue
            if x[1] != y[1]:
                first, why = k, "set %s / %s" % (x[1], y[1])
            elif x[2] != y[2]:
                first, why = k, "cutscene level %d / %d" % (x[2], y[2])
            else:
                dpos = max(abs(x[3] - y[3]), abs(x[4] - y[4]), abs(x[5] - y[5]))
                dyaw = abs(((x[7] - y[7] + 180.0) % 360.0) - 180.0)
                if dpos > ptol:
                    first, why = k, "position %.4f" % dpos
                elif dyaw > ytol:
                    first, why = k, "yaw %.3f" % dyaw
            if first is not None:
                break
        rows.append((name, n, a1 - a0, b1 - b0, first, why))
        if first is not None:
            print("\n== %s: first difference at frame %d of the chapter (A frame %d, B frame %d): %s" % (name, first, a0 + first, b0 + first, why))
            for k in range(max(0, first - 2), min(n, first + ctx)):
                x, y = a.get(a0 + k), b.get(b0 + k)
                if x and y:
                    print("  %6d A %-22s c%d %9.4f %9.4f %9.4f yaw %8.3f | B %-22s c%d %9.4f %9.4f %9.4f yaw %8.3f" % (
                        k, x[1][:22], x[2], x[3], x[4], x[5], x[7], y[1][:22], y[2], y[3], y[4], y[5], y[7]))
    print("\n%-32s %8s %8s %8s  first difference" % ("chapter", "compared", "A len", "B len"))
    same = 0
    for name, n, la, lb, first, why in rows:
        if first is None:
            same += 1
        print("%-32s %8d %8d %8d  %s" % (name, n, la, lb, "none" if first is None else "frame %d: %s" % (first, why)))
    print("\n%d of %d chapters are the same to the end of the shorter run (position %g m, yaw %g deg)" % (same, len(rows), ptol, ytol))


main()
