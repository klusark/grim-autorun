#!/usr/bin/env python
"""Compares the frames of the original (tools/framecap.py) with those of ScummVM (DumpFrame): for every frame that both have, the mean error and the
share of pixels that differ by more than a threshold, and one image with the original, ScummVM and the difference side by side. Writes
<outdir>/index.html, the frames sorted by difference (the worst first), and diff_<name>.png.

    python framediff.py <original frames dir> <scummvm frames dir> <outdir> [threshold 0-255, default 40]

(Windows python with Pillow and numpy.)"""
import os, sys, html
import numpy as np
from PIL import Image, ImageFilter

a_dir, b_dir, out = sys.argv[1], sys.argv[2], sys.argv[3]
thr = int(sys.argv[4]) if len(sys.argv) > 4 else 40
os.makedirs(out, exist_ok=True)

names = sorted(set(f[:-4] for f in os.listdir(a_dir) if f.endswith('.png')) & set(f[:-4] for f in os.listdir(b_dir) if f.endswith('.png')))
rows = []
for n in names:
    a = Image.open(os.path.join(a_dir, n + '.png')).convert('RGB')
    b = Image.open(os.path.join(b_dir, n + '.png')).convert('RGB')
    if a.size != b.size:
        # (the engines are run at the same size, 640x480: ScummVM with WIN=640x480, the original made DPI aware. The window of the original has
        # a client area of 640x476, the bottom four rows of the picture are not in it: the same top part of both is compared, nothing is resampled)
        w, h = min(a.width, b.width), min(a.height, b.height)
        if w < 600 or h < 440:
            print('size differs for %s: %s and %s, skipped' % (n, a.size, b.size))
            continue
        a = a.crop((0, 0, w, h))
        b = b.crop((0, 0, w, h))
    A = np.asarray(a).astype(np.int16)
    B = np.asarray(b).astype(np.int16)
    d = np.abs(A - B).max(axis=2)
    mean = float(d.mean())
    share = float((d > thr).mean() * 100)
    heat = np.zeros(A.shape, dtype=np.uint8)
    heat[..., 0] = np.clip(d * 4, 0, 255)
    heat[..., 1] = np.clip(255 - d * 4, 0, 255) // 4
    canvas = Image.new('RGB', (a.width * 3, a.height))
    canvas.paste(a, (0, 0))
    canvas.paste(b, (a.width, 0))
    canvas.paste(Image.fromarray(heat), (a.width * 2, 0))
    canvas.save(os.path.join(out, 'diff_' + n + '.png'))
    rows.append((share, mean, n))
rows.sort(reverse=True)
with open(os.path.join(out, 'index.html'), 'w') as f:
    f.write('<!doctype html><meta charset="utf-8"><title>Frame comparison</title><style>body{font:14px sans-serif;margin:1em}'
            'img{max-width:100%;display:block;margin:.3em 0 1.2em}</style>')
    f.write('<h1>Original | ScummVM | difference</h1><p>%d frames in common, threshold %d. Worst first.</p>' % (len(rows), thr))
    for share, mean, n in rows:
        f.write('<h3>%s: %.1f%% of the pixels differ, mean error %.1f</h3><img src="diff_%s.png">' % (html.escape(n), share, mean, html.escape(n)))
print('%d frames compared; worst: %s' % (len(rows), ', '.join('%s %.1f%%' % (n, s) for s, m, n in rows[:5])))
