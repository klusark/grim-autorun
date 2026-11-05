"""Snapshots of the screen (cr_snap in Lua): where the text is on a frame.

A test calls cr_snap(key): PrintDebug("CRSNAP:<file>") saves a frame to <file> in the game folder, on the original through
patch.dll (Render_SaveScreenshotBmp, its back buffer at once) and on ScummVM through the test patch (the next frame drawn),
and the log gets `key = "snap:<file>"`. After a run, resolve() replaces each of those values by the box of the bright pixels
of the file (x0 y0 x1 y1, inclusive): the tests draw white text on the dark backgrounds of assets.py, so the box is that of
the text. "none" when nothing is bright, "missing" when the file was not written."""
import os
import re
import struct

BRIGHT = 180  # (the backgrounds are at most 120 in any channel; ScummVM's screenshot is grey)

SNAP = re.compile(r'^(V [^|]*\|[^|]*\|)"snap:([A-Za-z0-9_.]+)"$')


def read_bmp(path):
    """(width, height, rows of (r, g, b)) of an uncompressed 24- or 32-bit .bmp."""
    d = open(path, "rb").read()
    if d[:2] != b"BM":
        raise ValueError("%s: not a .bmp" % path)
    off = struct.unpack_from("<I", d, 10)[0]
    w, h, _, bpp, comp = struct.unpack_from("<iiHHI", d, 18)
    if comp not in (0, 3) or bpp not in (24, 32):
        raise ValueError("%s: %d bits, compression %d" % (path, bpp, comp))
    step = bpp // 8
    pitch = (w * step + 3) & ~3
    rows = []
    for y in range(abs(h)):
        src = (abs(h) - 1 - y) if h > 0 else y
        p = off + src * pitch
        rows.append([(d[p + x * step + 2], d[p + x * step + 1], d[p + x * step]) for x in range(w)])
    return w, abs(h), rows


def bright_box(path):
    w, h, rows = read_bmp(path)
    xs, ys = [], []
    for y, row in enumerate(rows):
        for x, (r, g, b) in enumerate(row):
            if r >= BRIGHT and g >= BRIGHT and b >= BRIGHT:
                xs.append(x)
                ys.append(y)
    if not xs:
        return None
    return min(xs), min(ys), max(xs), max(ys)


def clear(folder):
    if os.path.isdir(folder):
        for f in os.listdir(folder):
            if f.startswith("crsnap") and f.endswith(".bmp"):
                os.remove(os.path.join(folder, f))


def resolve(lines, folder):
    out = []
    for l in lines:
        m = SNAP.match(l)
        if not m:
            out.append(l)
            continue
        path = os.path.join(folder, m.group(2))
        if not os.path.exists(path):
            out.append(m.group(1) + "missing")
            continue
        box = bright_box(path)
        out.append(m.group(1) + ("none" if box is None else " ".join("%.6f" % v for v in box)))
    return out
