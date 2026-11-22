"""Snapshots of the screen (cr_snap in Lua): where the text is on a frame.

A test calls cr_snap(key): PrintDebug("CRSNAP:<file>") saves a frame to <file> in the game folder, on the original through
patch.dll (Render_SaveScreenshotBmp, its back buffer at once; on EMI's original, with -gl, grimlaunch's debuglog and patch.dll's
EmiBeforeSwap: the frame drawn after the call, read before its SwapBuffers) and on ScummVM through the test patch (the next
frame drawn),
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

import numpy as np

BRIGHT = 180  # (the backgrounds are at most 120 in any channel; ScummVM's screenshot is grey)

SNAP = re.compile(r'^(V [^|]*\|[^|]*\|)"snap:([A-Za-z0-9_.]+)(:dark|:lit|:count|:mean|:seen)?"$')
DARK = 30  # (cr_snap(key, "dark"): the box of the pixels darker than any background, a shadow)


def read_bmp(path):
    """The pixels of an uncompressed 24- or 32-bit .bmp: an array of rows from the top, each of (r, g, b) (numpy, uint8)."""
    d = open(path, "rb").read()
    if d[:2] != b"BM":
        raise ValueError("%s: not a .bmp" % path)
    off = struct.unpack_from("<I", d, 10)[0]
    w, h, _, bpp, comp = struct.unpack_from("<iiHHI", d, 18)
    if comp not in (0, 3) or bpp not in (24, 32):
        raise ValueError("%s: %d bits, compression %d" % (path, bpp, comp))
    step = bpp // 8
    pitch = (w * step + 3) & ~3
    # (a picture cut short raises ValueError here: fewer bytes than its rows)
    rows = np.frombuffer(d, np.uint8, abs(h) * pitch, off).reshape(abs(h), pitch)[:, :w * step].reshape(abs(h), w, step)
    if h > 0:
        rows = rows[::-1]   # (bottom-up in the file)
    return rows[:, :, 2::-1]   # (b, g, r[, a] in the file)


def bright_box(path, mode=None):
    """mode None: the bright pixels; "dark": the darker than any background; "lit": the others."""
    px = read_bmp(path)
    r, g, b = px[:, :, 0], px[:, :, 1], px[:, :, 2]
    if mode in ("dark", "lit", "mean"):
        dark = (r < DARK) & (g < DARK) & (b < DARK)
        sel = dark if mode == "dark" else ~dark
    else:
        sel = (r >= BRIGHT) & (g >= BRIGHT) & (b >= BRIGHT)
    ys, xs = np.nonzero(sel)
    if not len(xs):
        return None
    box = (int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max()))
    if mode == "mean":
        total = int(r[sel].sum(dtype=np.int64)) + int(g[sel].sum(dtype=np.int64)) + int(b[sel].sum(dtype=np.int64))
        return box + (len(xs), round(total / 3.0 / len(xs), 1))
    if mode == "count":
        return box + (len(xs),)
    return box


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
        try:
            box = bright_box(path, None if mode == "seen" else mode)
        except (ValueError, struct.error, IndexError):
            # (a picture cut short, by a game that crashed while it wrote it: a value of its own, not the end of the run)
            out.append(m.group(1) + "unreadable")
            continue
        if mode == "seen":
            out.append(m.group(1) + ("none" if box is None else '"bright"'))
            continue
        out.append(m.group(1) + ("none" if box is None else " ".join("%.6f" % v for v in box)))
    return out
