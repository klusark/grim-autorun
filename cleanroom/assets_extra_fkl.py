"""The set of fake_links.lua (ScummVM's fake bridges between Grim floors that do not touch; EMI's are emi_sort_sector.lua's
ess_apart, bug 11816). ScummVM's Sector::getBridgesTo cut a bridge only where it crossed an edge segment of the other floor,
not the edge's line: fkl_tri's slanted sides cross the line y = 0 at x = 4 and x = 6, beyond their own ends, so fkl_low's
whole top edge (and even its bottom edge) stayed a "bridge" to fkl_tri, 1 m away. The real way goes round by fkl_west and
fkl_top. The same replay over the game's 134 sets: 598 such links between walk floors more than 0.5 m off, in 80 sets."""
import formats as F
import assets


def _set(name, sectors):
    setup = dict(assets.CAMERA, name=name + "_0", background="cr_flat.bm", zbuffer="cr_flat.zbm")
    return F.set_file(["cr_pal.cmp"], [setup], [assets.LIGHT], sectors)


# fkl_low: a long floor below y = 0; fkl_tri: a triangle pointing down at (5, 1), 1 m above it; fkl_west and fkl_top: the
# way round, west and over the top. Floors that touch share their corners, as the game's do: the original's planner goes
# from a floor to the next through the next one's corners that lie in it (Planner_CollectSharedCorners), so without
# (3, 3) and (7, 3) in fkl_top there is no way from fkl_tri up into fkl_top.
FKL_FAKE = [
    ("fkl_low", "walk", True, 0.0, assets.rect(0, -2, 10, 0)),
    ("fkl_tri", "walk", True, 0.0, [(5, 1, 0), (7, 3, 0), (3, 3, 0)]),
    ("fkl_west", "walk", True, 0.0, [(-2, -2, 0), (0, -2, 0), (0, 0, 0), (0, 3, 0), (-2, 3, 0)]),
    ("fkl_top", "walk", True, 0.0, [(-2, 3, 0), (0, 3, 0), (3, 3, 0), (7, 3, 0), (8, 3, 0), (8, 4, 0), (-2, 4, 0)]),
]


# fkl_hot: two walk columns joined by a walk bridge at the north end, the gap south of the bridge a chernobyl sector (0x8000
# in the original's parser, no walk bit; height 9999 as the game's). The original's planner (BuildPath 0x4a9430, FindPath,
# FindExitPoints) takes planes with the walk bit only; ScummVM's Actor::walkTo took Grim's hot sectors too (since 2011:
# "Walk only on Walk and Hot sectors"). Touching floors share their corners.
FKL_HOT = [
    ("fkl_ha", "walk", True, 0.0, [(-3, -3, 0), (-1, -3, 0), (-1, 1, 0), (-1, 3, 0), (-3, 3, 0)]),
    ("fkl_hb", "walk", True, 0.0, assets.rect(-1, 1, 1, 3)),
    ("fkl_hc", "walk", True, 0.0, [(1, -3, 0), (3, -3, 0), (3, 3, 0), (1, 3, 0), (1, 1, 0)]),
    ("fkl_hhot", "chernobyl", True, 9999.0, assets.rect(-1, -3, 1, 1)),
]


def files():
    return {"fkl_fake.set": _set("fkl_fake", FKL_FAKE), "fkl_hot.set": _set("fkl_hot", FKL_HOT)}
