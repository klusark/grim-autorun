"""The data of emi_emd.lua (EMI's models and costumes, ScummVM engines/grim/emi/costume/, animationemi.cpp, modelemi.cpp,
costumeemi.cpp, skeleton.cpp, layer.cpp): a skeleton of three joints (emd_root, emd_body 0.9 m up, emd_head 0.5 m above
it), a second one (emd_tall: the body 1.5 m up), meshes on them (two textures: a .tga and a .sur of three; one without
bones; one cut off in its face count), animations of one joint each (translations, rotations, priorities, keys that end
before the animation, a joint the skeleton lacks), and the costumes that play them: anim keys (play, stop, pause, loop,
no loop, the fades), texi keys (the texture of the .sur), Lua code tracks, the tracks ScummVM skips (shad, awgt).
Also a set with every kind of light (emd_lights.set) and a .til of three layers (NewLayer's frames)."""
import gzip
import math
import struct

import assets as A
import assets_emi as E
import formats as F

ID = (0.0, 0.0, 0.0, 1.0)
Q = math.sqrt(0.5)
LV = "!luavEMD_LV"

# a box 0.6 x 1.8 x 0.6 m: its lower corners on emd_root, its upper ones on emd_body
BOX_V = E.EBOX_VERTS
BOX_T = E.EBOX_TRIS
BONES = [("emd_root", [0, 1, 2, 3]), ("emd_body", [4, 5, 6, 7])]


def _s(s):
    b = s.encode("ascii") + b"\0"
    return struct.pack("<I", len(b)) + b


def mesh(name, vertices, faces, textures, bones=None, cut=False):
    """An EMI mesh (.meshb, type 19) as formats.meshb, with textures of its own: textures [(file, flags)], faces
    [(texture index or None, [triangles])]; cut: the file ends in the face count."""
    xs, ys, zs = zip(*vertices)
    lo, hi = (min(xs), min(ys), min(zs)), (max(xs), max(ys), max(zs))
    centre = tuple((a + b) / 2 for a, b in zip(lo, hi))
    radius = max(math.sqrt(sum((v[i] - centre[i]) ** 2 for i in range(3))) for v in vertices)
    out = _s(name) + struct.pack("<4f", radius, *centre) + struct.pack("<6f", *(lo + hi))
    out += struct.pack("<III", 1, 0, len(textures))
    for t, flags in textures:
        out += _s(t) + struct.pack("<I", flags)
    out += struct.pack("<II", 19, len(vertices))
    out += b"".join(struct.pack("<3f", *v) for v in vertices)
    out += struct.pack("<3f", 0.0, 1.0, 0.0) * len(vertices)
    out += bytes((255, 255, 255, 255)) * len(vertices)
    out += b"".join(struct.pack("<2f", (v[0] + 0.3) / 0.6, (v[2] + 0.3) / 0.6) for v in vertices)
    out += struct.pack("<I", len(faces))
    if cut:
        # (half of the face count: the reader runs into the end of the file there)
        return out[:-2]
    for tex, tris in faces:
        out += struct.pack("<II", 0x304, 0 if tex is None else 1)
        if tex is not None:
            out += struct.pack("<I", tex)
        out += struct.pack("<I", 3 * len(tris)) + b"".join(struct.pack("<3H", *t) for t in tris)
    if bones:
        out += struct.pack("<II", 1, len(bones)) + b"".join(_s(j) for j, _ in bones)
        infos = sorted((v, i) for i, (_, vs) in enumerate(bones) for v in vs)
        out += struct.pack("<I", len(infos)) + b"".join(struct.pack("<IIf", 1, i, 1.0) for _, i in infos)
    else:
        out += struct.pack("<I", 0)
    return out


def sur(textures):
    """A .sur (several textures as one material, as the game's: a copyright line, VERSION, a TEX: line each,
    END_OF_SECTION)."""
    lines = ["Copyright (c) clean room", "VERSION\t1.0"] + ["TEX:\t\t\t%s" % t for t in textures] + ["END_OF_SECTION", ""]
    return "\r\n".join(lines).encode("ascii")


def til_layers(n, colours):
    """A .til of n layers, each one tile of 256 x 256 in a colour of its own (formats.til with one polygon a layer)."""
    T = 256
    coords, polys, tiles = [], [], []
    for k in range(n):
        polys.append((k, len(coords), 4))
        coords += [(-1.0, 1.0, 0.0, 0.0), (1.0, 1.0, 1.0, 0.0), (1.0, -1.0, 1.0, 1.0), (-1.0, -1.0, 0.0, 1.0)]
        r, g, b = colours[k]
        tiles.append(bytes((255, b, g, r)) * (T * T))
    head = b"TIL0" + struct.pack("<IIII", 0, len(coords), n, len(polys)) + b"\0" * 16
    body = b"".join(struct.pack("<4f", *c) for c in coords)
    body += b"".join(struct.pack("<II", k, 1) for k in range(n))
    body += b"".join(struct.pack("<III", *p) for p in polys)
    bmoff = len(head) + len(body)
    head = head[:4] + struct.pack("<I", bmoff) + head[8:]
    bm = bytearray(128)
    bm[0:5] = b"BM  F"
    struct.pack_into("<I", bm, 16, len(tiles))
    struct.pack_into("<IIIIIIII", bm, 32, 2, 32, 8, 8, 8, 24, 16, 8)
    data = head + body + bytes(bm) + b"".join(struct.pack("<II", T, T) + t for t in tiles)
    return gzip.compress(data, mtime=0)


def _tr(joint, a, b, seconds=1.0, priority=1):
    return (joint, 3, priority, [(a, 0.0), (b, seconds)])


def _rot(joint, q, seconds=1.0, priority=1):
    return (joint, 4, priority, [(ID, 0.0), (q, seconds)])


BODY = (0.0, 0.9, 0.0)


def files():
    out = {}
    out["emd.sklb"] = F.sklb([("emd_root", "no_parent", (0.0, 0.0, 0.0), ID), ("emd_body", "emd_root", BODY, ID),
                              ("emd_head", "emd_body", (0.0, 0.5, 0.0), ID)])
    out["emd_tall.sklb"] = F.sklb([("emd_root", "no_parent", (0.0, 0.0, 0.0), ID), ("emd_body", "emd_root", (0.0, 1.5, 0.0), ID)])
    # textures: emd_t0..2 (the .sur's) and emd_skin
    for i, c in enumerate([(200, 40, 40), (40, 200, 40), (40, 40, 200)]):
        out["emd_t%d.tga" % i] = F.tga(16, 16, [c] * 256, bpp=32)
    out["emd_skin.tga"] = F.tga(16, 16, [(220, 220, 220)] * 256, bpp=32)
    out["emd_eyes.sur"] = sur(["emd_t0.tga", "emd_t1.tga", "emd_t2.tga"])
    # the box: its sides on emd_skin (flags 0), its top and bottom on the .sur (flags 0x401: additive and one unknown);
    # its name with a backslash, as some of the game's
    sides, ends = BOX_T[4:], BOX_T[:4]
    out["emd_box.meshb"] = mesh("emd\\box", BOX_V, [(0, sides), (1, ends)], [("emd_skin.tga", 0), ("emd_eyes.sur", 0x401)],
                                bones=BONES)
    # without bones (on a skeleton all the same), and cut off after its face count
    out["emd_nob.meshb"] = mesh("emd_nob", BOX_V, [(None, BOX_T)], [("emd_skin.tga", 0)])
    # (a mesh cut off in its face count crashes Monkey4.exe at 0x450928: not made)
    # animations (1 s unless said)
    out["emd_up.animb"] = F.animb("emd_up", 1.0, [_tr("emd_body", BODY, (0.0, 1.9, 0.0))])
    out["emd_side.animb"] = F.animb("emd_side", 1.0, [_tr("emd_body", BODY, (1.0, 0.9, 0.0))])
    out["emd_turn.animb"] = F.animb("emd_turn", 1.0, [_rot("emd_root", (0.0, Q, 0.0, Q))])
    out["emd_tilt.animb"] = F.animb("emd_tilt", 1.0, [_rot("emd_root", (Q, 0.0, 0.0, Q))])
    # both a rotation and a translation of emd_body, at priority 3 (the layers below get nothing)
    out["emd_hi.animb"] = F.animb("emd_hi", 1.0, [_rot("emd_body", (0.0, 0.0, Q, Q), priority=3),
                                                  _tr("emd_body", BODY, (0.0, 0.9, 1.0), priority=3)])
    # 2 s long, its keys end at 1 s
    out["emd_hold.animb"] = F.animb("emd_hold", 2.0, [_tr("emd_body", BODY, (0.0, 1.4, 0.0)), _rot("emd_root", (0.0, Q, 0.0, Q))])
    # a joint the skeleton does not have, and one it has
    out["emd_ghost.animb"] = F.animb("emd_ghost", 1.0, [_tr("emd_nojoint", BODY, (0.0, 2.0, 0.0)),
                                                        _tr("emd_body", BODY, (0.0, 1.2, 0.0))])
    ch = []
    wear = ("wear", 1000.0, [("!skelemd.skl", 0, -1, [(0.0, 1)]), ("!meshemd_box.mesh", 1, -1, [(0.0, 1)]), (LV, 0, -1, [(0.0, 1)])])
    ch.append(wear)
    A_ = lambda n: "!animemd_%s.anim" % n
    # (each anim chore also counts on EMD_LV)
    ch.append(("up", 1.5, [(A_("up"), 0, -1, [(0.0, 1)]), (LV, 0, -1, [(0.0, 2)])]))
    ch.append(("side", 1.5, [(A_("side"), 0, -1, [(0.0, 1)])]))
    ch.append(("turn", 1.5, [(A_("turn"), 0, -1, [(0.0, 1)])]))
    ch.append(("tilt", 1.5, [(A_("tilt"), 0, -1, [(0.0, 1)])]))
    ch.append(("hi", 1.5, [(A_("hi"), 0, -1, [(0.0, 1)])]))
    ch.append(("hold", 2.5, [(A_("hold"), 0, -1, [(0.0, 1)])]))
    ch.append(("ghost", 1.5, [(A_("ghost"), 0, -1, [(0.0, 1)])]))
    # loop key (3) at 0 in a chore of 3 s; then no loop (4) at 2.2 s
    ch.append(("loopkey", 3.0, [(A_("up"), 0, -1, [(0.0, 3), (2.2, 4)])]))
    # play, pause at 0.3, play at 0.6, stop at 1.0, play at 1.2
    ch.append(("pausekey", 2.0, [(A_("up"), 0, -1, [(0.0, 1), (0.3, 2), (0.6, 1), (1.0, 0), (1.2, 1)])]))
    # play and pause at once (the animation stays before its start)
    ch.append(("frozen", 1.0, [(A_("up"), 0, -1, [(0.0, 1), (0.0, 2)])]))
    # fade in (5..9) and out (10..14) keys
    ch.append(("fadein1", 1.5, [(A_("up"), 0, -1, [(0.0, 5), (0.0, 1)])]))
    ch.append(("fadeins", 2.0, [(A_("side"), 0, -1, [(0.0, 6), (0.0, 1), (0.3, 7), (0.6, 8), (0.9, 9)])]))
    ch.append(("fadeout1", 2.0, [(A_("up"), 0, -1, [(0.0, 3), (0.2, 10)])]))
    ch.append(("fadeouts", 3.0, [(A_("side"), 0, -1, [(0.0, 3), (0.1, 11), (0.3, 1), (0.4, 12), (0.6, 1), (0.7, 13),
                                                        (0.9, 1), (1.0, 14), (1.5, 1)])]))
    # fades out, ends, and is played again (played while fading out)
    ch.append(("replay", 2.0, [(A_("up"), 0, -1, [(0.0, 1), (0.1, 14), (0.5, 1)])]))
    # a key the component does not know
    ch.append(("badkey", 1.0, [(A_("up"), 0, -1, [(0.0, 1), (0.2, 15)])]))
    # an animation that is not there
    ch.append(("noanim", 1.0, [(A_("missing"), 0, -1, [(0.0, 1)]), (LV, 0, -1, [(0.0, 3)])]))
    # the texture of the .sur (texi: 0, 1, 2, then 5 and 3, which it has not), and a texi of a material the actor lacks
    ch.append(("eyes", 1.0, [("!texiemd_eyes.sur", 0, -1, [(0.0, 0), (0.1, 1), (0.2, 2), (0.3, 5), (0.4, 3), (0.5, 1)]),
                             ("!texiemd_nomat.sur", 0, -1, [(0.0, 1)]), (LV, 0, -1, [(0.0, 4), (0.5, 5)])]))
    # Lua code (luac): the code is the component's name
    ch.append(("code", 0.5, [("!luacEMD_LC = EMD_LC + 1", 0, -1, [(0.0, 1), (0.1, 1), (0.2, 0)]),
                             ("!luacEMD_LS = tostring(EMD_LC)", 0, -1, [(0.3, 1)])]))
    # the tracks ScummVM skips (shad, awgt; a snd2 track hangs Monkey4.exe), each in a chore of its own between Lua Variable keys
    for tag, track in (("shad", ("!shademd_box.mesh", 1, -1, [(0.0, 1)])), ("awgt", ("!awgtanimweight", 1, -1, [(0.0, 0.5)]))):
        ch.append(("skip_" + tag, 0.5, [(LV, 0, -1, [(0.0, 6)]), track, (LV, 0, -1, [(0.2, 7)])]))
    # a second wear chore, on the other skeleton (and the mesh without bones), and an endless Lua Variable chore
    ch.append(("wear_tall", 1000.0, [("!skelemd_tall.skl", 0, -1, [(0.0, 1)]), ("!meshemd_nob.mesh", 1, -1, [(0.0, 1)])]))
    ch.append(("idle", 1000.0, [(LV, 0, -1, [(0.0, 8)])]))
    out["emd_anim.cosb"] = F.cosb(ch)
    # a costume worn on top of another (its tracks have no parent: the first goes to the previous costume's first)
    out["emd_over.cosb"] = F.cosb([("over", 1.0, [(LV, 0, -1, [(0.0, 11)]), ("!animemd_up.anim", 0, -1, [(0.0, 1)])]),
                                   ("over2", 1.0, [(LV, 0, -1, [(0.0, 12)])])])
    # two meshes, the second a child of the first (a child of a visible mesh is not drawn on its own); a mesh file that is
    # not there
    out["emd_twin.cosb"] = F.cosb([("wear", 1000.0, [("!skelemd.skl", 0, -1, [(0.0, 1)]), ("!meshemd_box.mesh", 1, -1, [(0.0, 1)]),
                                                     ("!meshemd_nob.mesh", 1, 1, [(0.0, 1)]), (LV, 0, -1, [(0.0, 31)])])])
    out["emd_nomesh.cosb"] = F.cosb([("wear", 1000.0, [("!skelemd.skl", 0, -1, [(0.0, 1)]),
                                                       ("!meshemd_missing.mesh", 1, -1, [(0.0, 1)]), (LV, 0, -1, [(0.0, 41)])])])
    # every kind of light: an ambient one, two spots (ScummVM lights a vertex by the direction from it to the light: the one
    # pointing down at the actor lights nothing; the one pointing up, 0.7 m above the box, has the lower corners between
    # its umbra (5 degrees) and penumbra (30), the upper ones outside), an omni that reaches no farther than 0.5 m, a direct
    # one, and a bright omni (intensity 4)
    rad = math.radians
    down, up = (-Q, 0.0, 0.0, Q), (Q, 0.0, 0.0, Q)
    spot = dict(type="spot", intensity=1.0, color=(255, 200, 200), falloff_near=1.0, falloff_far=20.0, umbra=rad(5),
                penumbra=rad(30))
    lights = [dict(name="emd_amb", type="ambient", position=(0.0, 0.0, 0.0), intensity=0.3, color=(255, 255, 255)),
              dict(spot, name="emd_spot", position=(0.0, 4.0, 0.0), rotation=down),
              dict(spot, name="emd_spot_up", position=(0.0, 2.5, 0.0), rotation=up),
              dict(name="emd_near", type="omni", position=(3.0, 1.0, 3.0), intensity=1.0, falloff_near=0.1, falloff_far=0.5),
              dict(name="emd_dir", type="direct", position=(0.0, 5.0, 0.0), rotation=down, intensity=0.5),
              dict(name="emd_bright", type="omni", position=(0.0, 1.0, 2.0), intensity=4.0, falloff_near=10.0, falloff_far=50.0)]
    # (the camera 6 m in front of the actor, 1 m up, unrotated: looking at it along +z, as ScummVM turns z over)
    out["emd_lights.setb"] = F.set_binary([dict(E.CAMERA, name="emd_lights_0", background="cr_flat.til", position=(0.0, 1.0, -6.0))],
                                          lights,
                                          E.emi_sectors(A.SETS["cr_flat"][1]))
    # the same camera, one omni light and no ambient one
    out["emd_dark.setb"] = F.set_binary([dict(E.CAMERA, name="emd_dark_0", background="cr_flat.til", position=(0.0, 1.0, -6.0))],
                                        [dict(name="emd_omni", type="omni", position=(0.0, 1.0, -2.0), intensity=1.0)],
                                        E.emi_sectors(A.SETS["cr_flat"][1]))
    out["emd_layers.til"] = til_layers(3, [(255, 0, 0), (0, 255, 0), (0, 0, 255)])
    return out
