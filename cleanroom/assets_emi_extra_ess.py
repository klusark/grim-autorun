"""The sets of emi_sort_sector.lua (bug 11816: an actor drawn in front of a building it is behind): walk sectors with sort
planes (formats.set_binary's sixth sector item, one int per setup), which the original's Actor_GetEffectiveSortOrder
(0x4257b0) reads for an actor that follows the boxes. Grim points turned over as assets_emi does (a Grim (x, y, z) is the
EMI (x, z, y)), so rect(x0, y0, x1, y1) is the EMI floor x in [x0, x1], z in [y0, y1]."""
import assets as A
import assets_emi as E
import formats as F


def _emi(sectors):
    return [(n, t, v, h, [E.emi_point(p) for p in pts]) + tuple(rest) for n, t, v, h, pts, *rest in sectors]


def _setups(name, count):
    return [dict(E.CAMERA, name="%s_%d" % (name, i), background="cr_flat.til") for i in range(count)]


# ess_over (3 setups): o_mid is loaded first and lies over the shared edge of o_left and o_right, so a point in it is in two
# sectors; o_right has two planes only (setup 2 reads 0 on the original: the 32 inline planes are zeroed); o_neg's planes
# are negative; o_door is off when the set loads (as the game's tourist boxes, turned on with box_on)
OVER = [
    ("o_mid", "walk", True, 0.0, A.rect(-1, -1, 1, 1), (30, 31, 32)),
    ("o_left", "walk", True, 0.0, A.rect(-4, -2, 0, 2), (10, 11, 12)),
    ("o_right", "walk", True, 0.0, A.rect(0, -2, 4, 2), (20, 21)),
    ("o_neg", "walk", True, 0.0, A.rect(-4, 2, 4, 4), (-1, -2, -3)),
    ("o_door", "walk", False, 0.0, A.rect(4, -1, 5, 1), (50, 51, 52)),
]

# ess_ramp: a low floor, a ramp up 0.5 m over 1 m (not named stair) and a high floor, one plane each
RAMP = [
    ("r_lo", "walk", True, 0.0, A.rect(-2, -3, 2, 0), (5,)),
    ("r_ramp", "walk", True, 0.0, [(-2, 0, 0), (2, 0, 0), (2, 1.0, 0.5), (-2, 1.0, 0.5)], (6,)),
    ("r_hi", "walk", True, 0.0, A.rect(-2, 1.0, 2, 3, 0.5), (7,)),
]

# ess_tall: a floor whose height (the original's plane tolerance) is 0.1 next to one with the default (0: 0.005)
TALL = [
    ("t_tall", "walk", True, 0.1, A.rect(-2, -2, 0, 2), (40,)),
    ("t_flat", "walk", True, 0.0, A.rect(0, -2, 2, 2), (41,)),
]


# ess_hot (Lucre's long_cheatbox, bug 11816): two walk columns joined by a walk bridge at the north end, and a hot box
# (0x8000, as the game's cheat boxes: height 9999, no planes) filling the gap south of the bridge. The straight way from one
# column to the other crosses the hot box; the way through walk sectors goes round by the bridge.
HOT = [
    ("h_a", "walk", True, 0.0, A.rect(-3, -3, -1, 3), (10,)),
    ("h_b", "walk", True, 0.0, A.rect(-1, 1, 1, 3), (20,)),
    ("h_c", "walk", True, 0.0, A.rect(1, -3, 3, 3), (30,)),
    ("h_hot", "hot", True, 9999.0, A.rect(-1, -3, 1, 1)),
]

# ess_stairs: the middle floor is a walk sector of type 0x1200 (Lucre's stair_east_a, stair_north), not named stair
STAIRS = [
    ("w_a", "walk", True, 0.0, A.rect(-3, -3, -1, 3), (10,)),
    ("w_mid", "walk_stair", True, 0.0, A.rect(-1, -3, 1, 3), (20,)),
    ("w_c", "walk", True, 0.0, A.rect(1, -3, 3, 3), (30,)),
]


# ess_apart: Lucre's sector213 and sector143 (luc.setb, EMI coordinates as the game has them, moved by (+30, 0, +200)):
# 12 m apart, not touching. ScummVM's Sector::getBridgesTo clipped a bridge only where it crossed an edge segment of the
# other sector, not the edge's line, so it gave sector213's west edge as a bridge to sector143 and the A* walked across
# the gap (in Lucre: over the long_cheatbox behind the port authority building, with no walk sector, drawn in front).
APART = [
    ("a_213", "walk", True, 0.0, [(-12.825, 0.0, 12.839), (-16.272, 0.0, 1.429), (-7.162, 0.0, 0.207), (-0.289, 0.0, 4.192),
                                  (-2.529, 0.0, 12.204)], (10,)),
    ("a_143", "walk", True, 0.0, [(11.199, 0.0, -10.292), (15.542, 0.0, -14.403), (18.330, 0.0, -13.561)], (20,)),
]


# ess_lift: two floors side by side, for a walk past another actor that stands 3.5 m off the walker's line (bug 11816's
# second way: ScummVM's Actor::getTangentPos moved a path point in Grim's x-y plane, which in EMI is a side view, so the
# point went up or down and the walker left the floor)
LIFT = [
    ("l_a", "walk", True, 0.0, A.rect(-4, -2, 0, 2), (10,)),
    ("l_b", "walk", True, 0.0, A.rect(0, -2, 4, 2), (20,)),
]


def files():
    return {
        "ess_over.setb": F.set_binary(_setups("ess_over", 3), [E.LIGHT], _emi(OVER)),
        "ess_ramp.setb": F.set_binary(_setups("ess_ramp", 1), [E.LIGHT], _emi(RAMP)),
        "ess_tall.setb": F.set_binary(_setups("ess_tall", 1), [E.LIGHT], _emi(TALL)),
        "ess_hot.setb": F.set_binary(_setups("ess_hot", 1), [E.LIGHT], _emi(HOT)),
        "ess_stairs.setb": F.set_binary(_setups("ess_stairs", 1), [E.LIGHT], _emi(STAIRS)),
        "ess_apart.setb": F.set_binary(_setups("ess_apart", 1), [E.LIGHT], APART),
        "ess_lift.setb": F.set_binary(_setups("ess_lift", 1), [E.LIGHT], _emi(LIFT)),
    }
