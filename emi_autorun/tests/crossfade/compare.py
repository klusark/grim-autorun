"""Compares Guybrush's held poses in a ScummVM capture with the original's (original/A.png B.png C.png, 640x480, Monkey4.exe
v1.1 under OpenGL, 2026-11-11).

    python -I compare.py <dir with A0.png B0.png C0.png>

A = pickup_high alone, B = pickup_low alone, C = both at once (the same priority, full weight). The score of a pose is the mean
absolute difference (0-255) around Guybrush. Measured on 2026-11-11: A and B 2.0 for any ScummVM (the renderers differ that much),
C 2.06 with the original's blend (a weighted sum of the quaternions that is not normalized) and 2.59 before it (ScummVM composed
the two rotations): C must stay at the level of A and B.
"""
import os, sys
import numpy as np
from PIL import Image

LIMIT = 2.3
BOX = (90, 230, 240, 410)
here = os.path.dirname(os.path.abspath(__file__))


def game_area(img):
    a = np.asarray(img.convert('RGB')).astype(int).sum(axis=2)
    cols = np.where(a[a.shape[0] // 2] > 30)[0]
    return img.convert('RGB').crop((cols.min(), 0, cols.max() + 1, img.height)).resize((640, 480), Image.LANCZOS)


ok = True
for pose in 'ABC':
    capf = os.path.join(sys.argv[1], pose + '0.png')
    if not os.path.exists(capf):
        print('FAIL: no capture of pose %s' % pose)
        sys.exit(1)
    o = np.asarray(Image.open(os.path.join(here, 'original', pose + '.png')).convert('RGB').crop(BOX)).astype(float)
    s = np.asarray(game_area(Image.open(capf)).crop(BOX)).astype(float)
    d = float(np.abs(o - s).mean())
    print('pose %s: %.2f (limit %.2f)' % (pose, d, LIMIT))
    ok = ok and d < LIMIT
print('PASS crossfade' if ok else 'FAIL crossfade: a held pose differs from the original')
sys.exit(0 if ok else 1)
