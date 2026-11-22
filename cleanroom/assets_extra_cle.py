"""The set of collision_edge.lua (ScummVM bug 11813: Manny walks into Toto, who stands on the phone just off the floor of
set si, 7 cm from the edges of drill_box1 and drill_box2). cle_edge: one walk floor west of x = 0; the actor that is walked
into stands east of it, off the floor."""
import formats as F
import assets


def files():
    setup = dict(assets.CAMERA, name="cle_edge_0", background="cr_flat.bm", zbuffer="cr_flat.zbm")
    sectors = [("cle_floor", "walk", True, 0.0, assets.rect(-3, -3, 0, 3))]
    return {"cle_edge.set": F.set_file(["cr_pal.cmp"], [setup], [assets.LIGHT], sectors)}
