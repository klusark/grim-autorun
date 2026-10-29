#!/usr/bin/env python3
"""Number of pixels that differ between two PNG frames (8 bit RGB/RGBA, no interlace), and the box around them:
  pngdiff.py <a.png> <b.png>             one pair
  pngdiff.py <dir> <name a> <name b>...  the frames <dir>/<prefix>_<a>.png against <dir>/<prefix>_<b>.png for every prefix (sNN_v0 / sNN_v1 ...)"""
import glob
import os
import struct
import sys
import zlib


def read_png(path):
    data = open(path, "rb").read()
    pos = 8
    idat = b""
    while pos < len(data):
        n, kind = struct.unpack(">I4s", data[pos:pos + 8])
        chunk = data[pos + 8:pos + 8 + n]
        if kind == b"IHDR":
            w, h, depth, ctype = struct.unpack(">IIBB", chunk[:10])
        elif kind == b"IDAT":
            idat += chunk
        pos += 12 + n
    bpp = {2: 3, 6: 4}[ctype]
    raw = zlib.decompress(idat)
    stride = w * bpp
    rows = []
    prev = bytearray(stride)
    p = 0
    for _ in range(h):
        f = raw[p]
        line = bytearray(raw[p + 1:p + 1 + stride])
        p += 1 + stride
        for i in range(stride):
            a = line[i - bpp] if i >= bpp else 0
            b = prev[i]
            c = prev[i - bpp] if i >= bpp else 0
            if f == 1:
                line[i] = (line[i] + a) & 255
            elif f == 2:
                line[i] = (line[i] + b) & 255
            elif f == 3:
                line[i] = (line[i] + ((a + b) >> 1)) & 255
            elif f == 4:
                pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
                pr = a if pa <= pb and pa <= pc else (b if pb <= pc else c)
                line[i] = (line[i] + pr) & 255
        rows.append(line)
        prev = line
    return w, h, bpp, rows


def diff(a, b):
    wa, ha, bpp, ra = read_png(a)
    wb, hb, _, rb = read_png(b)
    count = 0
    x0 = y0 = 10 ** 9
    x1 = y1 = -1
    for y in range(ha):
        if ra[y] == rb[y]:
            continue
        for x in range(wa):
            if ra[y][x * bpp:x * bpp + 3] != rb[y][x * bpp:x * bpp + 3]:
                count += 1
                x0, x1 = min(x0, x), max(x1, x)
                y0, y1 = min(y0, y), max(y1, y)
    return count, (x0, y0, x1, y1)


if len(sys.argv) == 3:
    print(diff(sys.argv[1], sys.argv[2]))
else:
    d, na, nb = sys.argv[1], sys.argv[2], sys.argv[3]
    for fa in sorted(glob.glob(os.path.join(d, "*_" + na + ".png"))):
        fb = fa[:-len(na) - 4] + nb + ".png"
        if os.path.exists(fb):
            n, box = diff(fa, fb)
            print(os.path.basename(fa), "->", os.path.basename(fb), n, box if n else "")
