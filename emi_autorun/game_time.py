#!/usr/bin/env python3
"""Where the game time of an EMI autorun goes, from the CLOCK lines emi_lib.lua prints every game second
("CLOCK <ms> <x> <z> <cutSceneLevel> <set>").

    python game_time.py logs/whole_1.log [min_seconds]

Prints the game time of each chapter file, and every stretch of at least min_seconds (default 5) in which Guybrush did not move
(less than 0.05 from where the stretch began), with whether a cutscene was up, the set, and the last AUTORUN step before it.
"""
import re
import sys

CLOCK = re.compile(r"CLOCK (\d+) (-?[\d.]+) (-?[\d.]+) (\d+) (.*)")


def main():
    sys.stdout.reconfigure(errors="replace")
    path = sys.argv[1]
    min_s = float(sys.argv[2]) if len(sys.argv) > 2 else 5.0
    chapter = "?"
    last_step = ""
    per_chapter = {}
    order = []
    still = []  # (seconds, start ms, chapter, set, cutscene share, step)
    run = None  # [start ms, x, z, chapter, set, step, samples, cutscene samples]
    prev_t = None
    with open(path, "rb") as f:
        for raw in f:
            line = raw.decode("latin-1").rstrip("\r\n")
            i = line.find("AUTORUN ")
            if i >= 0 and "Starting wait" not in line and "Waited" not in line:
                msg = line[i + 8:]
                m = re.match(r"=== file (\S+) ===", msg)
                if m:
                    chapter = m.group(1)
                    if chapter not in per_chapter:
                        per_chapter[chapter] = 0
                        order.append(chapter)
                last_step = msg[:110]
                continue
            m = CLOCK.search(line)
            if not m:
                continue
            t = int(m.group(1))
            x, z, cs, st = float(m.group(2)), float(m.group(3)), int(m.group(4)), m.group(5)
            if prev_t is not None and t > prev_t:
                per_chapter[chapter] = per_chapter.get(chapter, 0) + t - prev_t
            prev_t = t
            if run and abs(x - run[1]) + abs(z - run[2]) < 0.05 and st == run[4]:
                run[6] += 1
                run[7] += 1 if cs else 0
                continue
            if run:
                secs = (t - run[0]) / 1000.0
                if secs >= min_s:
                    still.append((secs, run[0], run[3], run[4], run[7] / max(run[6], 1), run[5]))
            run = [t, x, z, chapter, st, last_step, 1, 1 if cs else 0]
    print("game time per chapter (s):")
    for c in order:
        print(f"  {per_chapter[c] / 1000:8.0f}  {c}")
    print(f"  {sum(per_chapter.values()) / 1000:8.0f}  all")
    print(f"\nstanding still for {min_s:g} s or more (longest first):")
    total = sum(s[0] for s in still)
    ctl = sum(s[0] * (1 - s[4]) for s in still)
    print(f"  {len(still)} stretches, {total:.0f} s, of which {ctl:.0f} s with no cutscene up")
    for secs, t0, c, st, csh, step in sorted(still, reverse=True)[:60]:
        print(f"  {secs:6.0f} s at {t0 / 1000:7.0f}  {c:24s} {st[:24]:24s} cutscene {csh * 100:3.0f}%  after: {step}")


if __name__ == "__main__":
    main()
