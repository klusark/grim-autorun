"""Tests of the python tools of the autorun that need no game: logts.py (the stamps of the AUTORUN lines) and gaps.py (the stretches without one)."""
import os
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
TOOLS = os.path.join(HERE, "..", "tools")


def _read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


class LogTs(unittest.TestCase):
    def test_passes_everything_and_stamps_only_autorun_lines(self):
        text = b"Debug: other\nDebug: AUTORUN one\nWARNING: FPS 100\nDebug: AUTORUN two\n"
        with tempfile.TemporaryDirectory() as d:
            side = os.path.join(d, "x.ts")
            out = subprocess.run([sys.executable, os.path.join(TOOLS, "logts.py"), side], input=text, capture_output=True, check=True).stdout
            self.assertEqual(out, text)
            rows = [l.split("\t", 1) for l in _read(side).splitlines()]
            self.assertEqual([r[1] for r in rows], ["Debug: AUTORUN one", "Debug: AUTORUN two"])
            self.assertLessEqual(int(rows[0][0]), int(rows[1][0]))


class Gaps(unittest.TestCase):
    def run_gaps(self, rows, limit):
        with tempfile.TemporaryDirectory() as d:
            p = os.path.join(d, "x.ts")
            with open(p, "w", encoding="utf-8") as f:
                for ms, text in rows:
                    f.write("%d\t%s\n" % (ms, text))
            return subprocess.run([sys.executable, os.path.join(TOOLS, "gaps.py"), p, str(limit)], capture_output=True, text=True, check=True).stdout

    def test_finds_a_gap_with_its_lines_and_chapter(self):
        rows = [(0, "Debug: AUTORUN === chapter ch01 ==="), (100, "Debug: AUTORUN a"), (6100, "Debug: AUTORUN b"), (6200, "Debug: AUTORUN c")]
        out = self.run_gaps(rows, 5)
        self.assertIn("1 gaps of 5.0 s", out)
        self.assertIn("6.0 s", out)
        self.assertIn("ch01", out)
        self.assertIn("a", out.splitlines()[1])
        self.assertIn("b", out.splitlines()[2])

    def test_nothing_below_the_limit(self):
        rows = [(0, "Debug: AUTORUN a"), (4900, "Debug: AUTORUN b")]
        self.assertIn("0 gaps", self.run_gaps(rows, 5))
        self.assertIn("1 gaps", self.run_gaps(rows, 4))


if __name__ == "__main__":
    unittest.main()
