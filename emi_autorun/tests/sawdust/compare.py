"""compare.py <ScummVM capture>: the forest path with the sawdust piles (ScummVM #11870) against the original's frame
(original.png, Monkey4.exe v1.1 -gl, 640x480). The capture's game area (black bars cut off) is scaled to 640x480 and the path region
(y 270-420) compared: mean absolute difference 0-255. Measured 2026-11-26: master 1.9 (the piles match the original exactly)."""
import sys
from PIL import Image
import numpy as np
cap = Image.open(sys.argv[1]).convert('RGB')
g = np.asarray(cap.convert('L'))
cols = np.where(g.max(axis=0) > 20)[0]
cap = cap.crop((cols[0], 0, cols[-1] + 1, cap.height)).resize((640, 480), Image.LANCZOS)
orig = Image.open(__file__.replace('compare.py', 'original.png')).convert('RGB')
box = (0, 270, 640, 420)
d = np.mean(np.abs(np.asarray(cap.crop(box)).astype(float) - np.asarray(orig.crop(box)).astype(float)))
print(('PASS' if d < 6 else 'FAIL') + ': the sawdust path differs from the original by %.2f (limit 6)' % d)
sys.exit(0 if d < 6 else 1)
