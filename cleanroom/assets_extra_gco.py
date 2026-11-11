"""The data of zz_gco*.lua (the engine core and its file formats): costumes with the components the other tests do not
use (sounds, a model on a mesh of another, keyframes with priorities and the pause and fade keys), keyframes, a binary
model with faces, a font with kerning and missing characters, bitmaps of several images and short copies, sets of other
layouts, lip sync files."""
import struct

import formats as F
import assets

u = lambda *v: struct.pack("<%dI" % len(v), *v)
f = lambda *v: struct.pack("<%df" % len(v), *v)

# the tags of formats.COSTUME_TAGS and the streamed sound
TAGS = dict(F.COSTUME_TAGS)
TAGS["IMSS"] = ("imss", "fs", "iMuse Streamed Sound FX")


def costume(components, chores):
    """formats.costume with TAGS (the streamed sound too)."""
    tags = []
    for tag, _, _ in components:
        if tag not in tags:
            tags.append(tag)
    out = ["costume v0.1", "", "", "section tags", "\tnumtags %d" % len(tags), ""]
    out += ["\t%d\t'%s'\t%s\t\t%s" % ((i,) + TAGS[t]) for i, t in enumerate(tags)]
    out += ["", "", "section components", "\tnumcomponents %d" % len(components), ""]
    out += ["\t%d\t%d\t\t0\t\t%d\t\t\t%s" % (i, tags.index(t), parent, name) for i, (t, parent, name) in enumerate(components)]
    out += ["", "", "section chores", "\tnumchores %d" % len(chores), ""]
    out += ["\t%d\t%d\t\t%d\t\t\t%s" % (i, length, len(tracks), name) for i, (name, length, tracks) in enumerate(chores)]
    out += ["", "", "section keys"]
    for i, (name, _, tracks) in enumerate(chores):
        out += ["chore %d\t# %s" % (i, name)]
        for comp, keys in tracks:
            out += ["\t%d\t\t\t%d" % (comp, len(keys))]
            out += ["\t\t%d\t\t\t%d" % k for k in keys]
            out += [""]
    return ("\r\n".join(out) + "\r\n").encode("ascii")


# --- sounds in a costume (zz_gco.lua gco_cos_sound*): the box model, cr_long.wav with its volume, pan, priority and least
# volume (100, 32, 90, 5) and cr_tone.wav without; GCO_LV counts the chore's keys
SND_COSTUME = ([("MMDL", -1, "cr_box.3do"), ("IMLS", -1, "cr_long.wav,100,32,90,5"), ("IMLS", -1, "cr_tone.wav"),
                ("LUAV", -1, "GCO_LV")],
               [("play_long", 100, [(1, [(0, 0)]), (3, [(0, 1)])]),
                ("stop_long", 100, [(1, [(0, 1)])]),
                ("unloop_long", 100, [(1, [(0, 2)])]),
                ("play_tone", 100, [(2, [(0, 0)])]),
                ("bad_key", 100, [(2, [(0, 9)])]),
                # (a chore of 300 ms that starts the long sound: when the chore ends, does the sound go on?)
                ("short_long", 300, [(1, [(0, 0)]), (3, [(0, 2), (300, 3)])])])
# the streamed sound component (imss)
STREAM_COSTUME = ([("MMDL", -1, "cr_box.3do"), ("IMSS", -1, "cr_long.wav"), ("LUAV", -1, "GCO_LV")],
                  [("play", 100, [(1, [(0, 0)]), (2, [(0, 1)])]),
                   ("stop", 100, [(1, [(0, 1)])])])

# --- a model on a mesh of another (zz_gco.lua gco_att_*): cr_two.3do (the white box on the left at -0.7, the two-cel one on
# the right) and on its left mesh a small white box 0.6 m up (gco_hat.3do, same material name cr_white.mat as its parent's)
HAT_BOX = F.box(0.3, 0.3, 0.3)
_q = lambda a, b, c, d: [[a, b, c, d], [d, c, b, a]]
HAT_FACES = _q(1, 5, 7, 3) + _q(0, 4, 5, 1) + _q(2, 3, 7, 6) + _q(0, 1, 3, 2) + _q(4, 6, 7, 5)
HAT_NODES = [("root", -1, -1, (-0.6, 0, 0.6), (0, 0, 0), (0, 0, 0)),
             ("body", 0, 0, (0, 0, 0), (0, 0, 0), (0, 0, 0))]
# components: 0 the main model, 1 GCO_LV, 2 its colormap, 3 the left mesh (node 1), 4 the hat on it (with a comma and a
# number, as the game's manny_cafe.3do,1), 5 a mesh of the hat, 6 the hat's material, 7 a keyframe on the hat (a
# colormap with no parent, gco_attf.cos, makes the original refuse the costume)
ATT_COMPONENTS = [("MMDL", -1, "cr_two.3do"), ("LUAV", -1, "GCO_LV"), ("CMAP", 0, "cr_pal.cmp"), ("MESH", 0, "mesh 1"),
                  ("MODL", 3, "gco_hat.3do,1"), ("MESH", 4, "mesh 1"), ("MAT ", 4, "cr_white.mat"),
                  ("KEYF", 4, "cr_slide.key")]
ATT_CHORES = [("left_off", 100, [(3, [(0, 0)])]),
              ("left_on", 100, [(3, [(0, 1)])]),
              ("hat_off", 100, [(4, [(0, 0)])]),
              ("hat_on", 100, [(4, [(0, 1)])]),
              # (a key on the main model: when the chore ends, its reset shows it again)
              ("main_off", 200, [(0, [(0, 0)]), (1, [(0, 1), (200, 2)])]),
              ("hat_slide", 500, [(7, [(0, 0)])]),
              ("hat_mesh_off", 100, [(5, [(0, 0)])])]

# --- keyframes with priorities and the other keys (zz_gco.lua gco_kf_*): the drawn box of cr_kbox.cos (assets.DRAW_COMPONENTS)
# with cr_slide.key at priorities 1, 5 (3), gco_up.key at the same (4), gco_side.key at 7, 2 (5), gco_nomark.key (6, text
# without markers), gco_short.key (7, binary: 2 joints of the model's 4, the first record without a name, the second with
# the same joint number), gco_badj.key (8, binary: a joint number past the count)
# gco_up.key: the body node 1 m to +y over 2 s; gco_side.key: 1 m to -x
def _slide(dx, dy, frames=30):
    return [(1, "body", [(0.0, 0, (0, 0, 0), (0, 0, 0), (dx / (frames - 1), dy / (frames - 1), 0), (0, 0, 0)),
                         (frames - 1.0, 0, (dx, dy, 0), (0, 0, 0), (0, 0, 0), (0, 0, 0))])]


UP_KEY = F.keyframe_text(30, 15.0, 4, _slide(0, 1.0), markers=[(5.0, 7)])
SIDE_KEY = F.keyframe_text(30, 15.0, 4, _slide(-1.0, 0), markers=[(5.0, 8)])
NOMARK_KEY = F.keyframe_text(30, 15.0, 4, _slide(0, -1.0))


def _key_bin(joints, records, name, frames=30, fps=15.0):
    """A binary .key whose joint records are given as they are: [(node name, joint number, entries)] (formats.keyframe_binary
    writes one a joint, numbered in order)."""
    h = b"FYEK" + F._fixed(name, 36) + struct.pack("<IIIfIIII", 0, joints, 0, fps, frames, joints, 0, 0)
    h += b"\0" * 64
    for nm, j, entries in records:
        h += F._fixed(nm, 32) + u(j, len(entries), 0)
        for frame, eflags, pos, rot, dpos, drot in entries:
            h += struct.pack("<fI12f", frame, eflags, *(tuple(pos) + tuple(rot) + tuple(dpos) + tuple(drot)))
    return h


_E = _slide(0.5, 0.5)[0][2]
SHORT_KEY = _key_bin(2, [("", 0, []), ("body", 1, _E), ("body", 1, _E)], "gco_short.key")
BADJ_KEY = _key_bin(2, [("root", 0, []), ("body", 5, _E)], "gco_badj.key")

KF_COMPONENTS = assets.DRAW_COMPONENTS + [("KEYF", 0, "cr_slide.key"), ("KEYF", 0, "gco_up.key,1,5"),
                                         ("KEYF", 0, "gco_side.key,7,2"), ("KEYF", 0, "gco_nomark.key"),
                                         ("KEYF", 0, "gco_short.key"), ("KEYF", 0, "gco_badj.key")]
KF_CHORES = ([("slide", 2000, [(3, [(0, 0)])]),          # 0
              ("slide_up", 2000, [(3, [(0, 0)]), (4, [(0, 0)])]),  # 1: two at one priority
              ("slide_side", 2000, [(3, [(0, 0)]), (5, [(0, 0)])]),  # 2: two at different priorities
              ("pause", 100, [(3, [(0, 5)])]),           # 3
              ("unpause", 100, [(3, [(0, 6)])])] +       # 4
             [("fade_in_%d" % k, 1000, [(3, [(0, k)])]) for k in (7, 8, 9, 10)] +    # 5-8
             [("fade_out_%d" % k, 1000, [(3, [(0, k)])]) for k in (11, 12, 13, 14)] +  # 9-12
             [("bad_key", 100, [(3, [(0, 20)])]),        # 13
              ("nomark", 2000, [(6, [(0, 0)])]),         # 14
              ("short", 2000, [(7, [(0, 0)])]),          # 15
              ("badj", 2000, [(8, [(0, 0)])]),           # 16
              ("stop", 100, [(3, [(0, 4)]), (4, [(0, 4)]), (5, [(0, 4)])])])  # 17


# --- a binary model with faces and a material (zz_gco_fmt.lua): the drawn box of cr_dbox.3do (assets.DRAW_BOX and
# DRAW_FACES) in the LDOM format, with the texture vertices and the material index of each face
def model3do_faces(name, meshes, nodes, materials, faces):
    """formats.model3do with materials and faces: faces {mesh index: [(material index, [vertex indices])]}, each face with
    the texture vertices 0-3 (the corners) and lighting mode 0 (MeshFace::loadBinary: 4 bytes, type, geometry, light,
    texture modes, vertex count, 4 bytes, the texture and material pointers (nonzero: their indices follow), 12 bytes, the
    extra light, 12 bytes, the normal, the vertex indices, the texture vertex indices, the material index)."""
    s32 = lambda t, n: t.encode("ascii")[:n - 1].ljust(n, b"\0")
    lo, hi, centre, radius = F.model_bounds(meshes, nodes)
    out = b"LDOM" + u(len(materials)) + b"".join(s32(m, 32) for m in materials) + s32(name, 32) + u(0) + u(1) + u(len(meshes))
    corners = [(0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0)]
    for i, (mname, verts) in enumerate(meshes):
        mf = faces.get(i, [])
        mr = max([sum(c * c for c in v) ** 0.5 for v in verts] or [0.0])
        ntv = len(corners) if mf else 0
        out += s32(mname, 32) + u(0) + u(4, 0, 0, len(verts), ntv, len(mf))
        out += b"".join(f(*v) for v in verts)
        out += b"".join(f(*c) for c in corners[:ntv])
        out += b"".join(f(1.0) for _ in verts)
        out += u(*([0] * len(verts))) if verts else b""
        for mat, vs in mf:
            out += u(0, 0, 4, 0, 0, len(vs), 0, 1, 1) + b"\0" * 12 + f(0.0) + b"\0" * 12 + f(0.0, 0.0, 1.0)
            out += u(*vs) + u(*[j % 4 for j in range(len(vs))]) + u(mat)
        out += b"".join(f(0.0, 0.0, 1.0) for _ in verts)
        out += u(0, 0) + f(mr) + b"\0" * 24
    children = [[j for j, n in enumerate(nodes) if n[2] == i] for i in range(len(nodes))]
    depth = []
    for i, n in enumerate(nodes):
        depth.append(0 if n[2] < 0 else depth[n[2]] + 1)
    out += u(0) + u(len(nodes))
    for i, (nname, mesh, parent, pos, pivot, rot) in enumerate(nodes):
        sibs = children[parent] if parent >= 0 else [j for j, n in enumerate(nodes) if n[2] < 0]
        k = sibs.index(i)
        sibling = sibs[k + 1] if k + 1 < len(sibs) else -1
        child = children[i][0] if children[i] else -1
        out += s32(nname, 64) + u(0, 0, 1) + struct.pack("<i", mesh) + u(depth[i], 1 if parent >= 0 else 0,
                                                                         len(children[i]), 1 if child >= 0 else 0,
                                                                         1 if sibling >= 0 else 0)
        out += f(*pivot) + f(*pos) + f(*rot) + b"\0" * 48
        for link in (parent, child, sibling):
            if link >= 0:
                out += u(link)
    out += f(radius) + f(*lo) + f(*hi) + f(*centre) + f(0.0, 0.0, 0.0)
    return out


# --- fonts (zz_gco_font.lua): the characters 0-127, each glyph a frame of 0xff with a 0x80 (outline) inside; upper case
# kerned 3 pixels wider than its picture and starting a column in, digits as wide as their picture. (A glyph that
# starts above the line, startingLine < -baseline, makes ScummVM's BitmapFont::render write above its surface: the
# software renderer crashes, font.cpp:397-412.) (A font whose first character is not 0 crashes the original: it takes the glyph of character c from
# the code table at c - first, ScummVM by looking c up in it.) perm: the code table with a, b, c in a cycle (the codes
# 98, 99, 97 at the places of a, b, c), and a 3 pixels wide, b 9, c 13: which glyph "a" gets
def font_kerned(perm=False):
    codes = list(range(0, 128))
    if perm:
        codes[97:100] = [98, 99, 97]
    recs = b""
    data = b""
    height, base = 10, 8
    for c in codes:
        w = 4 if c == 32 else 6 if 48 <= c <= 57 else 7 if 65 <= c <= 90 else 5
        if perm and 97 <= c <= 99:
            w = {97: 3, 98: 9, 99: 13}[c]
        kern = w + 3 if 65 <= c <= 90 else w if 48 <= c <= 57 else w + 1
        col = 1 if 65 <= c <= 90 else 0
        line = -base
        pix = bytearray(w * height)
        for y in range(height):
            for x in range(w):
                edge = x == 0 or y == 0 or x == w - 1 or y == height - 1
                pix[y * w + x] = 0xFF if edge else (0x80 if (x + y + c) % 3 == 0 else 0)
        recs += struct.pack("<IbbbBII", len(data), kern, col, line, 0, w, height)
        data += bytes(pix)
    head = struct.pack("<8I", len(codes), len(data), height + 2, base, 2, 0, codes[0], codes[-1])
    return head + struct.pack("<%dH" % len(codes), *codes) + recs + data


# --- bitmaps (zz_gco_fmt.lua): gco_noise.bm, compressed (codec 3) with short copies (runs of 3 to 6 bytes within 256 bytes);
# gco_two.bm / gco_two.zbm: two images each (the second white, 64 x 48), for a bitmap component that shows image 2
def _noise_pixels(w, h):
    out = []
    seed = 12345
    while len(out) < w * h:
        seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
        v = F.rgb565(200, (seed >> 8) & 0xFF, 50)
        n = 2 + (seed >> 20) % 3
        out += [v] * n
        if (seed >> 4) % 4 == 0 and len(out) > 8:
            out += out[-8:-4]
    return out[:w * h]


def bitmap_images(width, height, images, fmt=1):
    """A raw .bm/.zbm of several images (each 8 bytes, width and height, then its pixels)."""
    out = F._bm_header(fmt, len(images))
    for px in images:
        out += u(width, height) + struct.pack("<%dH" % len(px), *px)
    return out


# --- sets (zz_gco_set.lua)
_CAM = dict(assets.CAMERA)


def _setup(name, bg="cr_flat.bm", z="cr_flat.zbm"):
    return dict(_CAM, name=name, background=bg, zbuffer=z)


def _lines(s):
    return ("\r\n".join(s) + "\r\n").encode("ascii")


def _sector_lines(name, typ, pts, ident, height=0.0):
    out = ["\tsector\t\t%s" % name if name else "\tsector", "\tID\t\t%d" % ident, "\ttype\t\t%s" % typ,
           "\tdefault visibility\t\tvisible", "\theight\t\t%.2f" % height, "\tnumvertices\t%d" % len(pts)]
    for j, p in enumerate(pts):
        out += ["\t%s\t%f\t%f\t%f" % (("vertices:" if j == 0 else "         "), p[0], p[1], p[2])]
    return out + ["", ""]


def _head(setups):
    v3 = lambda p: "%f\t%f\t%f" % p
    out = ["section: colormaps", "\tnumcolormaps\t1", "\tcolormap\tcr_pal.cmp", "", "", "section: setups",
           "\tnumsetups\t%d" % len(setups), ""]
    for s in setups:
        out += ["\tsetup\t\t%s" % s["name"], "\tbackground\t%s" % s["background"], "\tzbuffer\t\t%s" % s["zbuffer"],
                "\tposition\t%s" % v3(s["position"]), "\tinterest\t%s" % v3(s["interest"]), "\troll\t\t%f" % s["roll"],
                "\tfov\t\t%f" % s["fov"], "\tnclip\t\t%f" % s["nclip"], "\tfclip\t\t%f" % s["fclip"], ""]
    return out


def _light_lines(name, typ="omni"):
    return ["\tlight\t\t%s" % name if name else "\tlight", "\ttype\t\t%s" % typ, "\tposition\t0.0\t0.0\t3.0",
            "\tdirection\t0.0\t0.0\t-1.0", "\tintensity\t1.0", "\tumbraangle\t0.0", "\tpenumbraangle\t0.0",
            "\tcolor\t\t15 15 15", ""]


def sets():
    out = {}
    # only colormaps and setups: no lights, no sectors
    out["gco_nolight.set"] = _lines(_head([_setup("gco_nolight_0")]))
    # lights and an empty sectors section
    out["gco_nosect.set"] = _lines(_head([_setup("gco_nosect_0")]) + ["", "section: lights", "\tnumlights\t1", ""] +
                                   _light_lines("gco_l") + ["", "section: sectors"])
    # a light without a name, two named; a funnel sector, a sector without a name, a thin floor (4 x 1 m) next to the main one
    lights = _light_lines("gco_omni") + _light_lines(None, "direct") + _light_lines("gco_spot", "spot")
    sects = (_sector_lines("gco_floor", "walk", assets.rect(-2, -2, 2, 2), 0) +
             _sector_lines("gco_funnel", "funnel", assets.rect(-1, -1, 1, 1), 1) +
             _sector_lines(None, "walk", assets.rect(3, -2, 4, 2), 2) +
             _sector_lines("gco_thin", "walk", assets.rect(-2, 3, 2, 4), 3))
    out["gco_kinds.set"] = _lines(_head([_setup("gco_kinds_0"), _setup("gco_kinds_1")]) +
                                  ["", "section: lights", "\tnumlights\t3", ""] + lights + ["", "section: sectors", ""] + sects)
    # an object states section before the setups
    out["gco_objs.set"] = _lines(["section: colormaps", "\tnumcolormaps\t1", "\tcolormap\tcr_pal.cmp", "", "",
                                  "section: objectstates", "\ttot_objects 1", "\tobject\tcr_obj.bm", ""] +
                                 _head([_setup("gco_objs_0")])[5:] + ["", "section: lights", "\tnumlights\t1", ""] +
                                 _light_lines("gco_l") + ["", "section: sectors", ""] +
                                 _sector_lines("gco_floor", "walk", assets.rect(-2, -2, 2, 2), 0))
    return out


def files():
    out = {}
    out["gco_snd.cos"] = costume(*SND_COSTUME)
    out["gco_stream.cos"] = costume(*STREAM_COSTUME)
    out["gco_hat.3do"] = F.model3do_text("gco_hat.3do", [("body", HAT_BOX)], HAT_NODES, materials=["cr_white.mat"],
                                         faces={0: [(0, x) for x in HAT_FACES]}, lighting=0)
    out["gco_att.cos"] = costume(ATT_COMPONENTS, ATT_CHORES)
    out["gco_up.key"] = UP_KEY
    out["gco_side.key"] = SIDE_KEY
    out["gco_nomark.key"] = NOMARK_KEY
    out["gco_short.key"] = SHORT_KEY
    out["gco_badj.key"] = BADJ_KEY
    out["gco_kf.cos"] = costume(KF_COMPONENTS, KF_CHORES)
    out["gco_bbox.3do"] = model3do_faces("gco_bbox.3do", [("body", assets.DRAW_BOX)], assets.BOX_MODEL[2], ["cr_white.mat"],
                                         {0: [(0, x) for x in assets.DRAW_FACES]})
    out["gco_bbox.cos"] = costume([("MMDL", -1, "gco_bbox.3do"), ("LUAV", -1, "GCO_LV"), ("CMAP", 0, "cr_pal.cmp")],
                                  [("noop", 100, [(1, [(0, 1)])])])
    out["gco_font.laf"] = font_kerned()
    out["gco_perm.laf"] = font_kerned(perm=True)
    out["gco_noise.bm"] = F.bitmap(64, 48, _noise_pixels(64, 48), codec=3)
    white = F.rgb565(255, 255, 255)
    out["gco_two.bm"] = bitmap_images(64, 48, [F.checker(64, 48, 8, (200, 50, 50), (50, 50, 200)), [white] * (64 * 48)])
    out["gco_two.zbm"] = bitmap_images(64, 48, [[0xFFFF] * (64 * 48), [0] * (64 * 48)], fmt=5)
    # a bitmap component on gco_two.bm: image 1, 2, then hidden
    out["gco_bmp.cos"] = costume([("MMDL", -1, "cr_box.3do"), ("LUAV", -1, "GCO_LV"), ("BKND", -1, "gco_two.bm")],
                                 [("image1", 100, [(2, [(0, 1)])]), ("image2", 100, [(2, [(0, 2)])]),
                                  ("hide", 100, [(2, [(0, 0)])])])
    # (a bitmap no object state has, and not a file either)
    out["gco_bmpx.cos"] = costume([("MMDL", -1, "cr_box.3do"), ("LUAV", -1, "GCO_LV"), ("BKND", -1, "gco_nostate.bm")],
                                  [("missing", 100, [(2, [(0, 1)])])])
    # (the parts of gco_att.cos one by one: which of them the original does not load)
    for k, n in (("a", 5), ("b", 6), ("c", 7), ("d", 8)):  # (d: all of them)
        comps = ATT_COMPONENTS[:n]
        out["gco_att%s.cos" % k] = costume(comps, [("noop", 100, [(1, [(0, 1)])])])
    out["gco_atte.cos"] = costume(ATT_COMPONENTS[:4] + [("MODL", 3, "gco_hat.3do")], [("noop", 100, [(1, [(0, 1)])])])
    out["gco_attf.cos"] = costume(ATT_COMPONENTS[:3] + [("CMAP", -1, "cr_pal.cmp")], [("noop", 100, [(1, [(0, 1)])])])
    # (the keyframe costume without the binary keyframes of other layouts, and with each of them alone)
    out["gco_kfa.cos"] = costume(KF_COMPONENTS[:7], KF_CHORES[:15] + [KF_CHORES[17]])
    out["gco_kfs.cos"] = costume(KF_COMPONENTS[:3] + [("KEYF", 0, "gco_short.key")], [("short", 2000, [(3, [(0, 0)])])])
    # (cr_slide.key alone, with chore 0 as gco_kfa.cos's; and with gco_up.key at the same priority)
    out["gco_kfx.cos"] = costume(KF_COMPONENTS[:4], [KF_CHORES[0]])
    out["gco_kfy.cos"] = costume(KF_COMPONENTS[:5], KF_CHORES[:2])
    out["gco_kfb.cos"] = costume(KF_COMPONENTS[:3] + [("KEYF", 0, "gco_badj.key")], [("badj", 2000, [(3, [(0, 0)])])])
    out.update(sets())
    # voices: gcov01 with a lip sync file of an unknown phoneme (0x99) between two known ones, gcov02 with a lip sync file
    # of no entries
    for name in ("gcov01", "gcov02"):
        out[name + ".wav"] = F.mcmp(*F.wav_split(F.wav(1.0, freq=200.0)))
    out["gcov01.lip"] = F.lip([(0, 0x99), (20, 0x64), (40, 0x6F)], 62)
    out["gcov02.lip"] = b"LIP!" + struct.pack("<i", 0)
    return out
