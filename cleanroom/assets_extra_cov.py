"""The data of cov_*.lua: costumes with ANIM components (the object state of a bitmap, by its name, overlay or underlay)
and with a component of an unknown tag; a set whose setup has background objects of its own (object_art and object_z in the text
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
        # ANIM: the object state of cov_art1.bm as an overlay (",1"), of cov_art2.bm as an underlay (",0"); chores
        # 0 art1_on, 1 art1_off, 2 art2_on, 3 both_on (art1 to image 1, art2 to image 1), 4 art1_two (image 2: none)
        "cov_anim.cos": F.costume([("MMDL", -1, "cr_dbox.3do"), ("LUAV", -1, "CR_LV"), ("CMAP", 0, "cr_pal.cmp"),
                                   ("ANIM", -1, "cov_art1.bm,1"), ("ANIM", -1, "cov_art2.bm,0")],
                                  [("art1_on", 100, [(3, [(0, 1)])]), ("art1_off", 100, [(3, [(0, 0)])]),
                                   ("art2_on", 100, [(4, [(0, 1)])]),
                                   ("both_on", 100, [(3, [(0, 1)]), (4, [(0, 1)])]),
                                   ("art1_two", 100, [(3, [(0, 2)])])]),
        # a component of the tag XXXX (ScummVM leaves it out: Costume::loadComponent), no chore keys it
        "cov_unknown.cos": F.costume([("MMDL", -1, "cr_dbox.3do"), ("LUAV", -1, "CR_LV"), ("CMAP", 0, "cr_pal.cmp"),
                                      ("XXXX", -1, "cov_nothing")],
                                     [("lv", 100, [(1, [(0, 7)])])]),
        "cov_short.bm": F.bitmap(64, 48, _short_repeats(64, 48), codec=3),
        "cov_objart.set": F.set_file(["cr_pal.cmp"], [setup], [assets.LIGHT],
                                     [("floor", "walk", True, 0.0, assets.rect(-3, -3, 3, 3))]),
    }
