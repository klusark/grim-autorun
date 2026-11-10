"""The clean-room data of Escape from Monkey Island: the files the EMI tests load, written by formats.py into local.m4b.

EMI's world has y up: the original finds the sector of a point in the x-z plane (a floor in Grim's x-y plane holds every point;
see emi_sets.lua). The sets are Grim's (assets.SETS) turned over: a Grim point (x, y, z) is the EMI point (x, z, y). They are
binary .setb (formats.set_binary): the original reads a text .set only in its own format, which has no colormaps or z-buffers,
and ScummVM reads only Grim's text format. Their backgrounds are .til (formats.til; the original crashes drawing a set without one)."""
import math

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
    # cr_flat with two shadows (emi_attach.lua's eat_shadow): one from the light, one from a point of its own
    out["cr_shadows.setb"] = F.set_binary([dict(CAMERA, name="cr_shadows_0", background="cr_flat.til")], [LIGHT],
                                          emi_sectors(A.SETS["cr_flat"][1]),
                                          shadows=[("cr_shadow1", LIGHT["name"], (0.0, 3.0, 0.0), ["floor"], (20, 20, 20)),
                                                   ("cr_shadow2", "", (1.0, 4.0, 1.0), ["floor"], (40, 0, 0))])
    # two setups, to switch between
    two = [dict(CAMERA, name="two_a", background="cr_flat.til"),
           dict(CAMERA, name="two_b", background="cr_edge.til", position=(1.0, 6.0, -0.5), fov=40.0)]
    out["cr_two.setb"] = F.set_binary(two, [LIGHT], emi_sectors(A.SETS["cr_flat"][1]))
    out.update(costumes())
    out.update(A.BIN_FILES)
    out["cr_font.laf"] = A.FONT
    # sounds (formats.aiff, EMI's .aif): a short tone and a long one
    out["cr_tone.aif"] = F.aiff(0.5)
    out["cr_long.aif"] = F.aiff(3.0, freq=220.0)
    # voices (SayLine plays "<message id>.wVC"): MCMP with the RIFF header stored and VIMA blocks, as the game's; crtv01
    # with a lip sync file (A.lipsync's phonemes), crtv02 without one
    for name in ("crtv01", "crtv02"):
        out[name + ".wVC"] = F.mcmp(*F.wav_split(F.wav(1.0, freq=200.0)))
    out["crtv01.lip"] = F.lip([(0, 0x64), (20, 0x6F), (40, 0x66)], 62)
    _extras(out, "files")
    return out


def _extras(out, what):
    """Adds the files() (the archive's) or loose_files() (beside it) of every assets_emi_extra_*.py: test data written side
    by side stays apart; a name made twice stops the build."""
    import glob
    import importlib
    import os
    for path in sorted(glob.glob(os.path.join(os.path.dirname(os.path.abspath(__file__)), "assets_emi_extra_*.py"))):
        mod = importlib.import_module(os.path.splitext(os.path.basename(path))[0])
        if not hasattr(mod, what):
            continue
        extra = getattr(mod, what)()
        clash = sorted(set(extra) & set(out))
        if clash:
            raise SystemExit("%s: names already made: %s" % (os.path.basename(path), ", ".join(clash)))
        out.update(extra)


# A box 0.6 x 1.8 x 0.6 m (y up): its lower corners follow the joint "root", its upper ones "body" (0.9 m up)
EBOX_VERTS = [(x, y, z) for y in (0.0, 1.8) for x in (-0.3, 0.3) for z in (-0.3, 0.3)]
EBOX_TRIS = [(0, 1, 3), (0, 3, 2), (4, 6, 7), (4, 7, 5), (0, 4, 5), (0, 5, 1),
             (2, 3, 7), (2, 7, 6), (0, 2, 6), (0, 6, 4), (1, 5, 7), (1, 7, 3)]
IDENTITY = (0.0, 0.0, 0.0, 1.0)


def costumes():
    """EMI costumes (formats.cosb) and what they use. cr_lv.cos: Lua Variable tracks only (CR_LV), as Grim's
    LUAV_COSTUME: "keys" (1 s, CR_LV 1 at 0, 2 at 0.1 s, 3 at 0.25 s, 4 at 1 s), "short" (0.05 s), "loop" (0.3 s), "endless"
    (a length of 1000: no end). cr_ebox.cos: a skeleton (root, body), the box mesh on it, "wear_default" (endless: the
    skeleton and the mesh), "lift" (1 s: the animation cr_ebox_lift, which moves body 0.5 m up and turns root a quarter
    about y, and CR_LV 7 at its start)."""
    out = {}
    lv = "!luavCR_LV"
    out["cr_lv.cosb"] = F.cosb([
        ("keys", 1.0, [(lv, 0, -1, [(0.0, 1), (0.1, 2), (0.25, 3), (1.0, 4)])]),
        ("short", 0.05, [(lv, 0, -1, [(0.0, 10), (0.05, 11)])]),
        ("loop", 0.3, [(lv, 0, -1, [(0.0, 20), (0.15, 21)])]),
        ("endless", 1000.0, [(lv, 0, -1, [(0.0, 30)])]),
    ])
    out["cr_ebox.sklb"] = F.sklb([("root", "no_parent", (0.0, 0.0, 0.0), IDENTITY), ("body", "root", (0.0, 0.9, 0.0), IDENTITY)])
    out["cr_ebox.meshb"] = F.meshb("cr_ebox", EBOX_VERTS, EBOX_TRIS,
                                   bones=[("root", [0, 1, 2, 3]), ("body", [4, 5, 6, 7])])
    q = math.sqrt(0.5)
    out["cr_ebox_lift.animb"] = F.animb("cr_ebox_lift", 1.0, [
        ("body", 3, 1, [((0.0, 0.9, 0.0), 0.0), ((0.0, 1.4, 0.0), 1.0)]),
        ("root", 4, 1, [(IDENTITY, 0.0), ((0.0, q, 0.0, q), 1.0)]),
    ])
    # a sprite (formats.sprb) on a texture of its own, and the box mesh with its faces on a texture (cr_etex.mesh): the
    # sprite costume shows the sprite and a textured box
    out["cr_tex.tga"] = F.tga(32, 32, [(220, 220, 220)] * (32 * 32), bpp=32)
    out["cr_spr.sprb"] = F.sprb("cr_spr.spr", "cr_tex.tga", 0.5, 0.5, (0.0, 1.0, 0.0))
    out["cr_etex.meshb"] = F.meshb("cr_etex", EBOX_VERTS, EBOX_TRIS, bones=[("root", [0, 1, 2, 3]), ("body", [4, 5, 6, 7])],
                                   texture="cr_tex.tga", textured=True)
    out["cr_esprite.cosb"] = F.cosb([
        ("wear_default", 1000.0, [("!skelcr_ebox.skl", 0, -1, [(0.0, 1)]), ("!meshcr_etex.mesh", 1, -1, [(0.0, 1)]),
                                  ("!sprtcr_spr.spr", 0, -1, [(0.0, 1)]), (lv, 0, -1, [(0.0, 9)])]),
        ("hide", 1.0, [("!sprtcr_spr.spr", 0, -1, [(0.0, 0)]), (lv, 0, -1, [(0.0, 8)])]),
    ])
    out["cr_ebox.cosb"] = F.cosb([
        ("wear_default", 1000.0, [("!skelcr_ebox.skl", 0, -1, [(0.0, 1)]), ("!meshcr_ebox.mesh", 1, -1, [(0.0, 1)])]),
        ("lift", 1.0, [("!animcr_ebox_lift.anim", 0, -1, [(0.0, 1)]), (lv, 0, -1, [(0.0, 7)])]),
    ])
    return out


def loose_files():
    """The files beside the archive. The movies (formats.bik, as the .m4b of Movies/: both engines open Movies/<name>.m4b
    as a file, and with no SMUSH subtitle header the Bink data start at 0): 160 x 120 at 15 frames a second, white for 90
    frames (6 s), and 5 frames from grey to white."""
    out = {"Movies/cr_white.m4b": F.bik(160, 120, [(255, 255, 255)] * 90),
           "Movies/cr_steps.m4b": F.bik(160, 120, [(v, v, v) for v in range(130, 255, 25)])}
    out.update(music())
    _extras(out, "loose_files")
    return out


def music():
    """EMI's music, as the game's sits beside its archives (emi_music.lua): Textures/FullMonkeyMap.imt (formats.imt) with
    states 1 to 110 (ScummVM wants at least 100), the odd ones A\\cr_one.m4b in sync group 1, the even ones A\\cr_loop.m4b in
    group 2; the files (formats.emi_music: MP3 frames of silence, 3 s) in both music sets, Textures/spago and
    Textures/mego; cr_loop's .jmm loops from 2 s back to 0.5 s."""
    out = {"Textures/FullMonkeyMap.imt": F.imt([(i, 1 if i % 2 else 2, "state", "A\\cr_one.m4b" if i % 2 else "A\\cr_loop.m4b")
                                                for i in range(1, 111)])}
    for d in ("spago", "mego"):
        out["Textures/%s/A/cr_one.m4b" % d] = F.emi_music(3.0)
        out["Textures/%s/A/cr_one.jmm" % d] = F.jmm(0.0)
        out["Textures/%s/A/cr_loop.m4b" % d] = F.emi_music(3.0)
        out["Textures/%s/A/cr_loop.jmm" % d] = F.jmm(0.0, 2000.0, 500.0)
    return out
