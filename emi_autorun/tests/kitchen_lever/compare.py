"""Compares captured ScummVM frames of the kitchen lever with the original's (original/oNN.png, 640x480, Monkey4.exe v1.1 under
OpenGL, captured the same way on 2026-11-11).

    python -I compare.py <dir with sNN.png>

Each original frame is matched with the ScummVM frame that looks most like it around the stove's hub (the lever passes through it,
the monkeys hold its ends): the pose of the cycle is not the same at the same moment of the two captures. The score is the mean
over the original frames of the best match's mean absolute difference (0-255) in that region. Values measured on 2026-11-11:
the original against itself 0, ScummVM with the fix 6.85 (worst frame 8.94), ScummVM before it 9.02 (worst 11.90): there the
lever's bone kept its bind offset, 0.354 nearer to the camera, so the lever looked longer and the monkeys' hands missed its ends.
"""
import glob, os, sys
import numpy as np
from PIL import Image

LIMIT = 7.9            # between 6.85 (fixed) and 9.02 (bug)
REGION = (330, 230, 560, 330)

here = os.path.dirname(os.path.abspath(__file__))


def game_area(img):
    # (the window capture has the black bars of the 4:3 picture on the sides: the columns that are not black, the full height)
    a = np.asarray(img.convert('RGB')).astype(int).sum(axis=2)
    row = a[a.shape[0] // 2]
    cols = np.where(row > 30)[0]
    x0, x1 = cols.min(), cols.max() + 1
    return img.convert('RGB').crop((x0, 0, x1, img.height)).resize((640, 480), Image.LANCZOS)


def region(img):
    return np.asarray(img.crop(REGION)).astype(float)


orig = [region(Image.open(f).convert('RGB')) for f in sorted(glob.glob(os.path.join(here, 'original', 'o*.png')))]
cap = [region(game_area(Image.open(f))) for f in sorted(glob.glob(os.path.join(sys.argv[1], 's*.png')))]
if len(orig) < 8 or len(cap) < 8:
    print('FAIL: too few frames (original %d, captured %d)' % (len(orig), len(cap)))
    sys.exit(1)
best = [min(np.abs(o - c).mean() for c in cap) for o in orig]
score = float(np.mean(best))
print('score %.2f (worst frame %.2f), limit %.2f' % (score, max(best), LIMIT))
if score < LIMIT:
    print('PASS kitchen lever')
    sys.exit(0)
print('FAIL kitchen lever: the lever or the monkeys are not where the original has them')
sys.exit(1)
