#!/usr/bin/env python3
"""A contact sheet of crops of PNG frames (the frames of tools/pngdiff.py), scaled up by whole numbers:
  pngsheet.py <out.png> <x0> <y0> <x1> <y1> <scale> <columns> <frame.png>...   (the frames in rows of <columns>)"""
import struct
import sys
import zlib

sys.path.insert(0, __file__.rsplit("/", 1)[0] if "/" in __file__ else ".")
from pngdiff import read_png  # noqa: E402


def write_png(path, w, h, rows):
    raw = b"".join(b"\x00" + bytes(r) for r in rows)

    def chunk(kind, data):
        c = struct.pack(">I", len(data)) + kind + data
        return c + struct.pack(">I", zlib.crc32(kind + data) & 0xffffffff)

    open(path, "wb").write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)) +
                           chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b""))


out = sys.argv[1]
x0, y0, x1, y1, scale, cols = [int(v) for v in sys.argv[2:8]]
files = sys.argv[8:]
cw, ch = (x1 - x0) * scale, (y1 - y0) * scale
gap = 4
rowsN = (len(files) + cols - 1) // cols
W, H = cols * cw + (cols - 1) * gap, rowsN * ch + (rowsN - 1) * gap
canvas = [bytearray(b"\x40\x40\x40" * W) for _ in range(H)]
for n, f in enumerate(files):
    w, h, bpp, rows = read_png(f)
    ox, oy = (n % cols) * (cw + gap), (n // cols) * (ch + gap)
    for y in range(y0, y1):
        line = rows[y]
        for x in range(x0, x1):
            px = bytes(line[x * bpp:x * bpp + 3])
            for dy in range(scale):
                row = canvas[oy + (y - y0) * scale + dy]
                for dx in range(scale):
                    p = (ox + (x - x0) * scale + dx) * 3
                    row[p:p + 3] = px
write_png(out, W, H, canvas)
print(out, W, H)
