"""The data of cov_*.lua: a set whose setup has background objects of its own (object_art and object_z in the text
.set, Set::Setup::load): three white bitmaps of different sizes, drawn at the top left."""
import formats as F
import assets

WHITE = F.rgb565(255, 255, 255)


def _white(w, h):
    return F.bitmap(w, h, [WHITE] * (w * h))


def _short_repeats(w, h):
    """Pixels in groups of five: two new values, the same two again, a third new one. The repeat is 4 bytes 4 back, which
    only a short copy of codec 3 takes (0 0 a b and a byte: decompress_codec3's 2-to-5-byte form)."""
    px, k = [], 1
    while len(px) < w * h:
        a, b, c = k, k + 1, k + 2
        px += [a * 9 & 0xFFFF, b * 9 & 0xFFFF, a * 9 & 0xFFFF, b * 9 & 0xFFFF, c * 9 & 0xFFFF]
        k += 3
    return px[:w * h]


def files():
    # cov_art1 (40 x 30) with a z-buffer of the same name: drawn; cov_art2 (20 x 60) without a z-buffer: drawn;
    # cov_art3 (80 x 10) with the z-buffer of another name: ScummVM leaves it out
    setup = dict(assets.CAMERA, name="cov_objart_0", background="cr_flat.bm", zbuffer="cr_flat.zbm",
                 object_art=[("art1", "cov_art1.bm", "art1", "cr_flat.zbm"), ("art2", "cov_art2.bm"),
                             ("art3", "cov_art3.bm", "other", "cr_flat.zbm")])
    return {
        "cov_art1.bm": _white(40, 30),
        "cov_art2.bm": _white(20, 60),
        "cov_art3.bm": _white(80, 10),
        "cov_short.bm": F.bitmap(64, 48, _short_repeats(64, 48), codec=3),
        "cov_objart.set": F.set_file(["cr_pal.cmp"], [setup], [assets.LIGHT],
                                     [("floor", "walk", True, 0.0, assets.rect(-3, -3, 3, 3))]),
    }
