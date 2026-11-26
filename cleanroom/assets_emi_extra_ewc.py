"""The set of emi_walk_corner.lua: Melee Town's sector1 (mel.setb, EMI coordinates as the game has them), whose vertex 2 is
the sharp corner a cutscene walk drove Guybrush into (ScummVM's walker stopped there for good when a step started exactly on
the edge that blocked it)."""
import assets_emi as E
import formats as F

CORNER = [
    ("c_floor", "walk", True, 0.0, [(14.3661003, 0.58, 1.80877995), (17.7865009, 0.58, 2.12584996),
                                    (17.8278008, 0.58, 3.15728998), (14.4153996, 0.58, 2.61813998)]),
]


def files():
    return {
        "ewc_corner.setb": F.set_binary([dict(E.CAMERA, name="ewc_corner_0", background="cr_flat.til")], [E.LIGHT], CORNER),
    }
