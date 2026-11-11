"""The data of zz_gl1.lua (the Lua builtins' rarer branches): a set for PutActorAtInterest and a font 13 pixels high."""
import formats as F
import assets


# PutActorAtInterest picks the point of the visible walk sectors nearest the setup's interest (the origin) that is not in a
# hot (chernobyl) sector: the floor holds the origin, but a hot sector covers it; a walk sector that is off is nearer than
# the far one
GL1_HOT = [
    ("gl1_floor", "walk", True, 0.0, assets.rect(-2, -2, 2, 2)),
    ("gl1_hotspot", "chernobyl", True, 9999.0, assets.rect(-1, -1, 1, 1)),
    ("gl1_off", "walk", False, 0.0, assets.rect(-2, 2.5, 2, 3)),
    ("gl1_far", "walk", True, 0.0, assets.rect(3, -1, 4, 1)),
]


def files():
    setup = dict(assets.CAMERA, name="gl1_hot_0", background="cr_flat.bm", zbuffer="cr_flat.zbm")
    return {
        "gl1_hot.set": F.set_file(["cr_pal.cmp"], [setup], [assets.LIGHT], GL1_HOT),
        # (cr_font.laf's widths, 11 pixels high: a line of 13, the height ScummVM draws 6 pixels higher, the computer font's)
        "gl1_font13.laf": F.font(lambda c: 4 if c == 32 else 6 if 48 <= c <= 57 else 8 if 65 <= c <= 90 else 5, height=11),
    }
