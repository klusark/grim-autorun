"""The data of zz_rnd.lua (the renderers): bitmaps with a transparent colour, of two images and placed by their header,
a z-buffer image, materials with transparent texels, fonts of other sizes and with an outline colour, a set seen straight
from above and a set with more lights than a renderer takes."""
import struct

import formats as F
import assets

W, H = assets.W, assets.H
WHITE = F.rgb565(255, 255, 255)
GREY = F.rgb565(150, 150, 150)
KEY = 0xF81F  # (the transparent colour of the game's bitmaps: magenta)


def bitmap_images(width, height, images, fmt=1, x=0, y=0):
    """A .bm/.zbm of several images (raw, codec 0) placed at x, y (the header's words at 0x14 and 0x18, where an object
    state draws it). images: lists of width*height 16-bit values."""
    h = b"BM  F\0\0\0" + struct.pack("<9I", 0, 0, len(images), x, y, 0, fmt, 16, 5)
    h += struct.pack("<6I", 6, 5, 11, 5, 0, 3) + struct.pack("<2I", 2, 3)
    out = h + b"\0" * (0x80 - len(h))
    for px in images:
        assert len(px) == width * height
        out += struct.pack("<II", width, height) + struct.pack("<%dH" % len(px), *px)
    return out


def _holed(width, height, colour, x0, y0, x1, y1):
    """A bitmap of one colour with a rectangle of the transparent colour (x0 <= x < x1, y0 <= y < y1)."""
    return [KEY if x0 <= x < x1 and y0 <= y < y1 else colour for y in range(height) for x in range(width)]


def material_pixels(width, height, pixels, alpha):
    """A .mat of one cel as formats.material, with the texture's pixels given (colour indices, row by row: 0 is the
    transparent index) and its third word (ScummVM's Texture::_hasAlpha) set to `alpha`."""
    u = lambda *v: struct.pack("<%dI" % len(v), *v)
    f = lambda *v: struct.pack("<%df" % len(v), *v)
    out = b"MAT " + u(0x32, 2, 1, 1) + u(8, 8) + b"\0" * 48
    out += u(8, 255) + f(1.0, 1.0, 1.0, 1.0) + u(0, 0, 0, 0)
    out += u(width, height, alpha, 0, 0, 1) + bytes(pixels)
    return out


def font_outlined(width, height, base=None):
    """A .laf as formats.font, every character width x height, its frame in the outline colour 0x80 and its bits in 255."""
    base = height - 2 if base is None else base
    recs = b""
    data = b""
    for c in range(256):
        pix = bytearray(width * height)
        for y in range(height):
            for x in range(width):
                edge = x == 0 or y == 0 or x == width - 1 or y == height - 1
                bit = (c >> ((x + y) % 8)) & 1
                pix[y * width + x] = 0x80 if edge else 255 if bit else 0
        recs += struct.pack("<IbbbBII", len(data), width + 1, 0, -base, 0, width, height)
        data += bytes(pix)
    head = struct.pack("<8I", 256, len(data), height + 2, base, 2, 0, 0, 255)
    return head + struct.pack("<256H", *range(256)) + recs + data


def _box_model(name, mat):
    return F.model3do_text(name, [("body", assets.DRAW_BOX)], assets.BOX_MODEL[2], materials=[mat],
                           faces={0: [(0, f) for f in assets.DRAW_FACES]}, lighting=0)


_W15 = (15, 15, 15)


def files():
    out = {}
    # white 64 x 48 with a 16 x 16 hole of the transparent colour in its middle; plain white 64 x 48
    out["rnd_key.bm"] = bitmap_images(64, 48, [_holed(64, 48, WHITE, 24, 16, 40, 32)])
    out["rnd_plain.bm"] = bitmap_images(64, 48, [[WHITE] * (64 * 48)])
    # two images (white, then grey with a hole) at 200, 150, with a z-buffer of two images (0, some of them the transparent
    # colour, which ScummVM reads as 0)
    out["rnd_anim.bm"] = bitmap_images(64, 48, [[WHITE] * (64 * 48), _holed(64, 48, GREY, 0, 0, 32, 48)], x=200, y=150)
    out["rnd_anim.zbm"] = bitmap_images(64, 48, [[0] * (64 * 48), _holed(64, 48, 0, 0, 0, 8, 8)], fmt=5, x=200, y=150)
    # a costume without a model: its bitmap component (BKND) shows image 1, 2 or none of rnd_anim.bm
    out["rnd_bk.cos"] = F.costume([("LUAV", -1, "CR_LV"), ("BKND", -1, "rnd_anim.bm")],
                                  [("img1", 100, [(1, [(0, 1)])]), ("img2", 100, [(1, [(0, 2)])]),
                                   ("img0", 100, [(1, [(0, 0)])])])
    # the white draw box with a checker of white and transparent (index 0) texels, the material marked as having alpha
    # or not
    checker = [0 if (x + y) % 2 else 255 for y in range(8) for x in range(8)]
    out["rnd_holes.mat"] = material_pixels(8, 8, checker, 1)
    out["rnd_holes0.mat"] = material_pixels(8, 8, checker, 0)
    for n in ("rnd_holes", "rnd_holes0"):
        out[n + ".3do"] = _box_model(n + ".3do", n + ".mat")
        out[n + ".cos"] = F.costume([("MMDL", -1, n + ".3do"), ("LUAV", -1, "CR_LV"), ("CMAP", 0, "cr_pal.cmp")],
                                    assets.BOX_COSTUME[1])
    # the draw box with its faces in two materials by turns, white and grey (the shader renderer draws the faces of one
    # material at once)
    mixed = {0: [(k % 2, f) for k, f in enumerate(assets.DRAW_FACES)]}
    out["rnd_mixed.3do"] = F.model3do_text("rnd_mixed.3do", [("body", assets.DRAW_BOX)], assets.BOX_MODEL[2],
                                           materials=["cr_white.mat", "cr_grey.mat"], faces=mixed, lighting=0)
    out["rnd_mixed.cos"] = F.costume([("MMDL", -1, "rnd_mixed.3do"), ("LUAV", -1, "CR_LV"), ("CMAP", 0, "cr_pal.cmp")],
                                     assets.BOX_COSTUME[1])
    # fonts: 5 x 6, 20 x 20 and 40 x 40 characters with an outline (ScummVM's GL renderers round the size of a character
    # cell up to 16, 32 or 64)
    out["rnd_f5.laf"] = font_outlined(5, 6)
    out["rnd_f20.laf"] = font_outlined(20, 20)
    out["rnd_f40.laf"] = font_outlined(40, 40)
    # cr_lit (black, the far z-buffer of cr_open) seen from straight above: the camera's x and y are the interest's
    down = dict(assets.CAMERA, name="rnd_down_0", background="cr_lit.bm", zbuffer="cr_open.zbm", position=(0.0, 0.0, 6.0),
                interest=(0.0, 0.0, 0.0))
    out["rnd_down.set"] = F.set_file(["cr_pal.cmp"], [down], [assets.LIGHT], assets.SETS["cr_open"][1])
    # cr_lit with 34 omni lights in a ring 2 m out and 2 m up (ScummVM's GL renderers take 8, TinyGL 32)
    import math
    lights = [dict(name="rnd_l%d" % i, type="omni", position=(2 * math.cos(i * 0.1848), 2 * math.sin(i * 0.1848), 2.0),
                   intensity=1.0, color=_W15) for i in range(34)]
    out["rnd_lights.set"] = F.set_file(["cr_pal.cmp"], [dict(assets.CAMERA, name="rnd_lights_0", background="cr_lit.bm",
                                                              zbuffer="cr_open.zbm")], lights, assets.SETS["cr_open"][1])
    return out
