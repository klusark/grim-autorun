"""The clean-room data of Escape from Monkey Island: the files the EMI tests load, written by formats.py into local.m4b.

EMI's world has y up: the original finds the sector of a point in the x-z plane (a floor in Grim's x-y plane holds every point;
see emi_sets.lua). The sets are Grim's (assets.SETS) turned over: a Grim point (x, y, z) is the EMI point (x, z, y). They are
binary .setb (formats.set_binary): the original reads a text .set only in its own format, which has no colormaps or z-buffers,
and ScummVM reads only Grim's text format. Their backgrounds are .til (formats.til; the original crashes drawing a set without one)."""
import assets as A
import formats as F


def emi_point(p):
    x, y, z = p
    return (x, z, y)


def emi_sectors(sectors):
    return [(n, t, v, h, [emi_point(p) for p in pts]) for n, t, v, h, pts in sectors]


# The camera of assets.CAMERA, unrotated (the quaternion of an EMI setup is not worked out yet)
CAMERA = dict(position=emi_point(A.CAMERA["position"]), fov=A.CAMERA["fov"], nclip=A.CAMERA["nclip"], fclip=A.CAMERA["fclip"])
LIGHT = dict(A.LIGHT, position=emi_point(A.LIGHT["position"]))


def files():
    out = {}
    # (the ones the original loads at start: without them its resource list goes wrong and a later load can hang it, walking a
    # list without end)
    out["default.tga"] = F.tga(64, 64, [(128, 128, 128)] * (64 * 64))
    for n in ("pixeltest.til", "dfltroom.til"):
        out[n] = F.til(256, 256, [(128, 128, 128)] * (256 * 256))
    for name, (colours, sectors) in A.SETS.items():
        out[name + ".til"] = F.til(A.W, A.H, F.checker_rgb(A.W, A.H, 40, *colours))
        out[name + ".setb"] = F.set_binary([dict(CAMERA, name=name + "_0", background=name + ".til")], [LIGHT],
                                           emi_sectors(sectors))
    # cr_flat as Grim has it, the floor in the x-y plane
    out["cr_xyflat.setb"] = F.set_binary([dict(CAMERA, name="cr_xyflat_0", background="cr_flat.til")], [LIGHT],
                                         A.SETS["cr_flat"][1])
    # two setups, to switch between
    two = [dict(CAMERA, name="two_a", background="cr_flat.til"),
           dict(CAMERA, name="two_b", background="cr_edge.til", position=(1.0, 6.0, -0.5), fov=40.0)]
    out["cr_two.setb"] = F.set_binary(two, [LIGHT], emi_sectors(A.SETS["cr_flat"][1]))
    return out
