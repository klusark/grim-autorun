"""Where the test files are: tests/common/ runs on both games, tests/grim/ on Grim only, tests/emi/ on EMI only.

A game's tests are those of common/ and of its own folder, run in the order of their file names (the folders mixed: the
order is the same as when all of them were in one folder). The file names are unique across the folders: the engines
read them as one flat set of files (build/cr_<name>)."""
import os

HERE = os.path.dirname(os.path.abspath(__file__))
TESTS = os.path.join(HERE, "tests")
GAMES = ("grim", "emi")
# (each folder and the games its files run on)
FOLDERS = {"common": GAMES, "grim": ("grim",), "emi": ("emi",)}


def games_of(path):
    """The games a test file runs on: those of its folder."""
    return FOLDERS[os.path.basename(os.path.dirname(os.path.abspath(path)))]


def all_files():
    """Every test file (its path), in the order of the file names."""
    out = {}
    for folder in FOLDERS:
        d = os.path.join(TESTS, folder)
        for f in os.listdir(d) if os.path.isdir(d) else []:
            if f.endswith(".lua"):
                if f in out:
                    raise SystemExit("tests: %s is in %s and in %s" % (f, os.path.dirname(out[f]), d))
                out[f] = os.path.join(d, f)
    return [out[f] for f in sorted(out)]


def files(game):
    """The test files a game runs (their paths), in the order of the file names."""
    return [p for p in all_files() if game in games_of(p)]
