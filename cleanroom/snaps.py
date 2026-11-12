"""Snapshots of the screen (cr_snap in Lua): where the text is on a frame.

A test calls cr_snap(key): PrintDebug("CRSNAP:<file>") saves a frame to <file> in the game folder, on the original through
patch.dll (Render_SaveScreenshotBmp, its back buffer at once) and on ScummVM through the test patch (the next frame drawn),
and the log gets `key = "snap:<file>"`. After a run, resolve() replaces each of those values by the box of the bright pixels
of the file (x0 y0 x1 y1, inclusive): the tests draw white text on the dark backgrounds of assets.py, so the box is that of
the text. "none" when nothing is bright, "missing" when the file was not written. cr_snap(key, "dark"): the box of the
pixels darker than any background (a shadow); cr_snap(key, "lit"): the box of the others (what an iris leaves open);
cr_snap(key, "count"): the box of the bright pixels and how many there are (x0 y0 x1 y1 n: how thick a line is);
cr_snap(key, "mean"): the box of the pixels that are not dark, how many there are and their mean brightness ((r + g + b) / 3,
to a tenth: a lit model on a black background, zz_lit.lua); cr_snap(key, "seen"): "bright" when any pixel is bright, else
"none" (whether a white model is drawn white, whatever the one-pixel differences of its box: draw_cmap.lua)."""
import os
import re
import struct

BRIGHT = 180  # (the backgrounds are at most 120 in any channel; ScummVM's screenshot is grey)

SNAP = re.compile(r'^(V [^|]*\|[^|]*\|)"snap:([A-Za-z0-9_.]+)(:dark|:lit|:count|:mean|:seen)?"$')
DARK = 30  # (cr_snap(key, "dark"): the box of the pixels darker than any background, a shadow)


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


def bright_box(path, mode=None):
    """mode None: the bright pixels; "dark": the darker than any background; "lit": the others."""
    w, h, rows = read_bmp(path)
    xs, ys, total = [], [], 0
    for y, row in enumerate(rows):
        for x, (r, g, b) in enumerate(row):
            dark = r < DARK and g < DARK and b < DARK
            if dark if mode == "dark" else not dark if mode in ("lit", "mean") else (r >= BRIGHT and g >= BRIGHT and b >= BRIGHT):
                xs.append(x)
                ys.append(y)
                total += r + g + b
    if not xs:
        return None
    if mode == "mean":
        return min(xs), min(ys), max(xs), max(ys), len(xs), round(total / 3.0 / len(xs), 1)
    if mode == "count":
        return min(xs), min(ys), max(xs), max(ys), len(xs)
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
        mode = m.group(3)[1:] if m.group(3) else None
        box = bright_box(path, None if mode == "seen" else mode)
        if mode == "seen":
            out.append(m.group(1) + ("none" if box is None else '"bright"'))
            continue
        out.append(m.group(1) + ("none" if box is None else " ".join("%.6f" % v for v in box)))
    return out
