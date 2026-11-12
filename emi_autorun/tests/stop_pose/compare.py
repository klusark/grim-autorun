"""Stop pose test (ScummVM bug 11794 follow-up): compares the captured A0.png B0.png C0.png with the original's (original/A.png
B.png C.png, 640x480, Monkey4.exe v1.1 under OpenGL, 2026-11-11). A = the test lever never animated (bind pose), B = pull_lever held
still mid-play, C = 1.5 s after StopChore.

    python -I compare.py <dir with A0.png B0.png C0.png>

Checks (mean absolute difference 0-255 over the lever and the hands of the monkeys, which are held still too):
  - C against the original's C below LIMIT_ORIG: measured 4.93 (the renderers differ by about that much; A 5.09, B 4.90);
    the bind pose at C, as ScummVM used to have it, gives 6.83
  - C against this run's B below LIMIT_HELD (the pose is kept after the stop: original 0.65, ScummVM 0.00)
  - C against this run's A above LIMIT_MOVED (the lever did leave the bind pose: original 4.09, ScummVM 2.69; 0 when it goes back)
"""
import os, sys
import numpy as np
from PIL import Image

LIMIT_ORIG = 5.9
LIMIT_HELD = 1.5
LIMIT_MOVED = 1.5
REGION = (60, 150, 600, 350)
here = os.path.dirname(os.path.abspath(__file__))


def game_area(img):
    a = np.asarray(img.convert('RGB')).astype(int).sum(axis=2)
    cols = np.where(a[a.shape[0] // 2] > 30)[0]
    return img.convert('RGB').crop((cols.min(), 0, cols.max() + 1, img.height)).resize((640, 480), Image.LANCZOS)


def region(img):
    return np.asarray(img.crop(REGION)).astype(float)


cap = {}
for pose in 'ABC':
    f = os.path.join(sys.argv[1], pose + '0.png')
    if not os.path.exists(f):
        print('FAIL: no capture of pose %s' % pose)
        sys.exit(1)
    cap[pose] = region(game_area(Image.open(f)))
orig_c = region(Image.open(os.path.join(here, 'original', 'C.png')).convert('RGB'))
d_orig = float(np.abs(cap['C'] - orig_c).mean())
d_held = float(np.abs(cap['C'] - cap['B']).mean())
d_moved = float(np.abs(cap['C'] - cap['A']).mean())
print('C vs original C %.2f (< %.2f), C vs B %.2f (< %.2f), C vs A %.2f (> %.2f)' % (d_orig, LIMIT_ORIG, d_held, LIMIT_HELD, d_moved, LIMIT_MOVED))
ok = d_orig < LIMIT_ORIG and d_held < LIMIT_HELD and d_moved > LIMIT_MOVED
print('PASS stop pose' if ok else 'FAIL stop pose: after the stop the lever is not where the original keeps it')
sys.exit(0 if ok else 1)
