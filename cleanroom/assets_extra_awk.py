"""The data of actor_walk2.lua (walking and turning): sets of its own and a costume with rest, walk and turn chores."""
import formats as F
import assets


def _set(name, sectors):
    setup = dict(assets.CAMERA, name=name + "_0", background="cr_flat.bm", zbuffer="cr_flat.zbm")
    return F.set_file(["cr_pal.cmp"], [setup], [assets.LIGHT], sectors)


# a 3 x 3 grid of floors (-2, -0.5, 0.5, 2 on both axes), named awk_g<column><row> from the bottom left: from (-1.5, -1.5)
# to (1, 1.5) the path search reaches the top middle floor first through the left column and then, cheaper, through the
# middle (the corner bridges)
_XS = [-2.0, -0.5, 0.5, 2.0]
AWK_GRID = [("awk_g%d%d" % (i, j), "walk", True, 0.0, assets.rect(_XS[i], _XS[j], _XS[i + 1], _XS[j + 1]))
            for j in range(3) for i in range(3)]

# one 4 x 4 floor of its own, which the tests switch off (MakeSectorActive) and on again
AWK_ONE = [("awk_floor", "walk", True, 0.0, assets.rect(-2, -2, 2, 2))]

# A costume with a Lua Variable component for each of the rest, walk, left turn, right turn and second walk chores: each
# chore counts its global up (1, 2, 3 at 0, 100, 200 ms of a 300 ms chore) while it plays
AWK_GLOBALS = ["AWK_REST", "AWK_WALK", "AWK_LEFT", "AWK_RIGHT", "AWK_WALK2"]
AWK_COSTUME = ([("MMDL", -1, "cr_box.3do")] + [("LUAV", -1, g) for g in AWK_GLOBALS],
               [(n, 300, [(k + 1, [(0, 1), (100, 2), (200, 3)])])
                for k, n in enumerate(["rest", "walk", "left", "right", "walk2"])])


def files():
    return {
        "awk_grid.set": _set("awk_grid", AWK_GRID),
        "awk_one.set": _set("awk_one", AWK_ONE),
        "awk_turn.cos": F.costume(*AWK_COSTUME),
    }
