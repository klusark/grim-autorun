"""The clean-room data: every file the tests load, described here and written by formats.py.

files() returns {name: bytes} for cleanroom.lab; loose_files() the files that must sit in the game folder itself
(the original reads grim.tab with fopen before it opens any archive)."""
import os

import formats as F

W, H = 640, 480

# The text table: ids are looked up as /id/ (LocalizeString, text objects)
TEXT = [
    ("crt001", "Clean room text one"),
    ("crt002", "Second line, with punctuation: 1, 2; 3."),
    ("crt003", "x"),
    # (lines with a voice: lipsync.lua)
    ("crtv01", "Voice one"),
    ("crtv02", "Voice two"),
    ("crtv03", "Voice three"),
    ("crtv04", "Voice four"),
    # (wider than the screen in cr_font.laf: 107 characters of 5 and 6 pixels)
    ("crt004", "a line of text that is much too long to fit on the screen in one piece, so that it is clamped at both edges"),
]


def rect(x0, y0, x1, y1, z=0.0):
    return [(x0, y0, z), (x1, y0, z), (x1, y1, z), (x0, y1, z)]


# The Remastered's developer commentary (commentary_def.txt, only in ScummVM's Remastered mode): one for cr_flat, its file
# not there, two lines
COMMENTARY = [("cr_flat", "cr_commentary.imu", [(1, "crc_one", 0, 1000), (2, "crc_two", 1000, 2000)])]

# A camera 6 m above the floor looking down at the origin (y up on screen), the same for every set
CAMERA = dict(position=(0.0, -0.5, 6.0), interest=(0.0, 0.0, 0.0), roll=0.0, fov=60.0, nclip=0.01, fclip=100.0)
LIGHT = dict(name="cr_light", type="omni", position=(0.0, 0.0, 3.0), intensity=1.0, color=(255, 255, 255))

# name -> (two background colours, sectors (name, type, visible, height, corners))
SETS = {
    # one open 4 x 4 m floor
    "cr_flat": (((40, 90, 40), (60, 120, 60)), [
        ("floor", "walk", True, 0.0, rect(-2, -2, 2, 2)),
    ]),
    # two floors sharing an edge, a floor 2e-5 away (the containment tolerance of the original, FUN_004a6980), a floor
    # that is off and a wedge of 132.7 degrees
    "cr_edge": (((90, 40, 40), (120, 60, 60)), [
        ("e_left", "walk", True, 0.0, rect(-2, -2, 0, 2)),
        ("e_right", "walk", True, 0.0, rect(0, -2, 2, 2)),
        ("e_gap", "walk", True, 0.0, rect(-2, 2.00002, 2, 4)),
        ("e_off", "walk", False, 0.0, rect(-2, -4, 2, -2.00002)),
        ("e_wedge", "walk", True, 0.0, [(2, -2, 0), (4, -2, 0), (4, 0, 0), (2, 2, 0)]),
    ]),
    # a low floor, a ramp (the name holds "stair": the actor is constrained) and a high floor
    "cr_stair": (((40, 40, 90), (60, 60, 120)), [
        ("lo", "walk", True, 0.0, rect(-2, -3, 2, 0)),
        ("stair_a", "walk", True, 0.0, [(-2, 0, 0), (2, 0, 0), (2, 1.0, 0.5), (-2, 1.0, 0.5)]),
        ("hi", "walk", True, 0.0, rect(-2, 1.0, 2, 3, 0.5)),
        ("hot", "chernobyl", True, 9999.0, rect(1, -3, 2, -2)),
    ]),
    # cr_flat again, with a z-buffer that lets models be drawn (OPEN_SETS)
    "cr_open": (((40, 90, 40), (60, 120, 60)), [
        ("floor", "walk", True, 0.0, rect(-2, -2, 2, 2)),
        # (the plane the shadows fall on, as the game's sets have it: a special sector named shadow1, 1 cm up)
        ("shadow1", "special", True, 9999.0, rect(-3, -3, 3, 3, 0.01)),
    ]),
    # an L of three floors: from one arm to the other the straight line leaves the floor (the path goes through the corner)
    "cr_ell": (((40, 90, 90), (60, 120, 120)), [
        ("ell_a", "walk", True, 0.0, rect(-2, -2, 0, 0)),
        ("ell_b", "walk", True, 0.0, rect(0, -2, 2, 0)),
        ("ell_c", "walk", True, 0.0, rect(0, 0, 2, 2)),
    ]),
}


# the lights of cr_lit.set (zz_lit.lua), all white: an omni light 3 m above the origin, a direct one straight down, a spot
# 3 m above pointing down (umbra 15, penumbra 25 degrees). Colour 15 15 15, as the game's sets have it (ScummVM divides
# the intensity by 15: 255 would light 17 times over)
_W15 = (15, 15, 15)
LIT_LIGHTS = [dict(name="cr_omni", type="omni", position=(0.0, 0.0, 3.0), intensity=1.0, color=_W15),
              dict(name="cr_dir", type="direct", position=(0.0, 0.0, 0.0), direction=(0.0, 0.0, -1.0), intensity=1.0,
                   color=_W15),
              dict(name="cr_spot", type="spot", position=(0.0, 0.0, 3.0), direction=(0.0, 0.0, -1.0), intensity=1.0,
                   umbra=15.0, penumbra=25.0, color=_W15)]

# the sets whose z-buffer is far (0): the models in them are drawn
OPEN_SETS = {"cr_open"}

# A costume without a model: one Lua Variable component, whose global CR_LV takes the value of each key when the chore reaches it
LUAV_COSTUME = (
    [("LUAV", -1, "CR_LV")],
    [("keys", 1000, [(0, [(0, 1), (100, 2), (250, 3), (1000, 4)])]),
     ("short", 50, [(0, [(0, 10), (50, 11)])]),
     ("loop", 300, [(0, [(0, 20), (150, 21)])]),
     ("zero", 0, [(0, [(0, 30)])])],
)


# A model without a picture: a root, a body box 0.4 x 0.3 x 1.8 m, a head node at 1.7 m, an arm node off to the side
BOX_MODEL = ("cr_box.3do", [("body", F.box(0.4, 0.3, 1.8))],
             [("root", -1, -1, (0, 0, 0), (0, 0, 0), (0, 0, 0)),
              ("body", 0, 0, (0, 0, 0), (0, 0, 0), (0, 0, 0)),
              ("head", -1, 1, (0, 0, 1.7), (0, 0, 0), (0, 0, 0)),
              ("arm", -1, 1, (0.3, 0.1, 1.2), (0, 0, 0), (0, 0, 30))])
# the same chores as LUAV_COSTUME, on the model costume (the Lua Variable is component 1)
BOX_COSTUME = ([("MMDL", -1, "cr_box.3do"), ("LUAV", -1, "CR_LV")],
               [(name, length, [(1, keys) for _, keys in tracks]) for name, length, tracks in LUAV_COSTUME[1]])

# A talking costume: the box model and a Lua Variable (CR_LV) set by each chore at its start, so that a test sees which
# chore plays. Chore 0 is stop_talk (100), 1-9 the lip sync shapes (1-9, what LipSync's phoneme table names), 10 the mumble
# (50); SetActorTalkChore(a, i + 1, i) gives the actor shape i
TALK_COSTUME = ([("MMDL", -1, "cr_box.3do"), ("LUAV", -1, "CR_LV")],
                [("stop_talk", 100, [(1, [(0, 100)])])] +
                [("talk_%d" % i, 100, [(1, [(0, i)])]) for i in range(1, 10)] +
                [("mumble", 100, [(1, [(0, 50)])])])

# The body box again, with a header (radius, bounding box, centre) that is not the one of its vertices. The original works
# them out from the mesh (rdModel3_LoadPostProcess) whatever the header says; ScummVM since dc7e5c2 reads the header (and
# before it put the sphere at the actor's feet, half the box height up for the actor that moves only)
HEADER_MODELS = {
    # the centre 0.5 m to the side (+x) and 0.2 m up
    "cr_ctrx": dict(centre=(0.5, 0.0, 0.2)),
    # the centre 3 m up: far above another actor's centre
    "cr_ctrz": dict(centre=(0.0, 0.0, 3.0)),
    # a bounding box 2 x 2 m and a radius of 1 m, the centre where the mesh has it
    "cr_bbig": dict(radius=1.0, lo=(-1.0, -1.0, 0.0), hi=(1.0, 1.0, 1.8)),
    # the centre and the bounding box off to -x, the radius small
    "cr_bside": dict(radius=0.3, lo=(-1.2, -0.15, 0.0), hi=(-0.8, 0.15, 1.8), centre=(-1.0, 0.0, 0.9)),
}



def _body(pos=(0, 0, 0), pivot=(0, 0, 0), rot=(0, 0, 0)):
    """BOX_MODEL's nodes with the body node moved, pivoted or turned (pitch, yaw, roll)."""
    return [BOX_MODEL[2][0], ("body", 0, 0, pos, pivot, rot)] + BOX_MODEL[2][2:]


# A wide body (1 x 0.2 x 1.8 m) for a turn about z to show in the bounding box
WIDE_BODY = [("body", F.box(1.0, 0.2, 1.8))]

# The two formats of a model: binary (LDOM, F.model3do) and text (F.model3do_text). The original works out the bounding box,
# centre and radius from the vertices through the full node transforms after either (rdModel3_LoadPostProcess), and reads
# neither the binary header nor the text radius. ScummVM reads the binary header; from a text model it reads the radius and
# works out the box from the vertices moved by each mesh's position only (Model::loadText), without the node's rotation.
# name: (format, meshes, nodes, binary header or text radius)
FORMAT_MODELS = {
    # the body box in text: the same as cr_box.3do
    "cr_tbox": ("text", BOX_MODEL[1], BOX_MODEL[2], None),
    # the radius of the file 3 m, in either format (the box where the mesh has it)
    "cr_trad": ("text", BOX_MODEL[1], BOX_MODEL[2], 3.0),
    "cr_brad": ("binary", BOX_MODEL[1], BOX_MODEL[2], dict(radius=3.0)),
    # the body node 0.5 m to +x, and the box 1 m up by its vertices, in text (cr_nodex and cr_float are the binary ones)
    "cr_tnodex": ("text", BOX_MODEL[1], _body(pos=(0.5, 0, 0)), None),
    "cr_tfloat": ("text", [("body", F.box(0.4, 0.3, 0.6, 1.0))], BOX_MODEL[2], None),
    # the wide body, as it is and turned 90 degrees about z (yaw): 0.2 m along x and 1 m along y
    "cr_wide": ("binary", WIDE_BODY, BOX_MODEL[2], None),
    "cr_rot": ("binary", WIDE_BODY, _body(rot=(0, 90, 0)), None),
    "cr_trot": ("text", WIDE_BODY, _body(rot=(0, 90, 0)), None),
    # the body box turned 90 degrees about x (pitch): lying along y, 0.3 m high
    "cr_rotx": ("binary", BOX_MODEL[1], _body(rot=(90, 0, 0)), None),
    "cr_trotx": ("text", BOX_MODEL[1], _body(rot=(90, 0, 0)), None),
    # the body node's pivot 0.5 m to +x
    "cr_piv": ("binary", BOX_MODEL[1], _body(pivot=(0.5, 0, 0)), None),
    "cr_tpiv": ("text", BOX_MODEL[1], _body(pivot=(0.5, 0, 0)), None),
    # the pivot 0.5 m to +x and a yaw of 90 degrees: the box to +y if the turn is about the node (as ScummVM draws it)
    "cr_prot": ("binary", BOX_MODEL[1], _body(pivot=(0.5, 0, 0), rot=(0, 90, 0)), None),
    "cr_tprot": ("text", BOX_MODEL[1], _body(pivot=(0.5, 0, 0), rot=(0, 90, 0)), None),
}



# A model with a picture: a box 1 x 0.6 x 0.5 m (cr_dbox, white; cr_gbox, grey: 150, under the bright level of snaps.py, so
# that a text over it can be measured) whose top and four sides are drawn, both ways round (no face is culled), without
# lighting (the colours of the texture as they are). Its nodes are those of BOX_MODEL (the keyframes move "body").
DRAW_BOX = F.box(1.0, 0.6, 0.5)
# (the corners of F.box: x, then y, then z, each low then high: index = 4 * (x high) + 2 * (y high) + (z high))
_q = lambda a, b, c, d: [[a, b, c, d], [d, c, b, a]]
DRAW_FACES = _q(1, 5, 7, 3) + _q(0, 4, 5, 1) + _q(2, 3, 7, 6) + _q(0, 1, 3, 2) + _q(4, 6, 7, 5)


def _draw_model(name, mat):
    return F.model3do_text(name, [("body", DRAW_BOX)], BOX_MODEL[2], materials=[mat],
                           faces={0: [(0, f) for f in DRAW_FACES]}, lighting=0)


# A keyframe of 2 s (30 frames at 15 a second) that slides the body node 1 m to +x and turns it 90 degrees (yaw), and the
# same back; the markers at frames 10 and 20
SLIDE_NODES = [
    (1, "body", [(0.0, 0, (0, 0, 0), (0, 0, 0), (1.0 / 29, 0, 0), (0, 90.0 / 29, 0)),
                 (29.0, 0, (1.0, 0, 0), (0, 90.0, 0), (0, 0, 0), (0, 0, 0))]),
]
SLIDE_KEY = F.keyframe_text(30, 15.0, 4, SLIDE_NODES, markers=[(10.0, 1), (20.0, 2)])
# the same in the binary format (formats.keyframe_binary), and a binary one that gives 30 frames a second (ScummVM plays
# every keyframe at 15)
SLIDE_NAMES = {0: "root", 2: "head", 3: "arm"}
SLIDE_KEY_BIN = F.keyframe_binary(30, 15.0, 4, SLIDE_NODES, markers=[(10.0, 1), (20.0, 2)], name="cr_slide_b.key",
                                  names=SLIDE_NAMES)
SLIDE_KEY_FAST = F.keyframe_binary(30, 30.0, 4, SLIDE_NODES, markers=[(10.0, 1), (20.0, 2)], name="cr_slide_f.key",
                                   names=SLIDE_NAMES)

# component ids: 0 the model, 1 the Lua Variable (BOX_COSTUME's chores use 1), 2 the colormap, 3 the keyframe
DRAW_COMPONENTS = [("MMDL", -1, "cr_dbox.3do"), ("LUAV", -1, "CR_LV"), ("CMAP", 0, "cr_pal.cmp")]
KEY_CHORES = [("slide_once", 2000, [(3, [(0, 0)])]),
              ("slide_loop", 2000, [(3, [(0, 1)])]),
              ("slide_hold", 2000, [(3, [(0, 2)])]),
              ("slide_fade", 2000, [(3, [(0, 3)])]),
              ("slide_stop", 100, [(3, [(0, 4)])]),
              ("slide_late", 2000, [(3, [(500, 0)]), (1, [(0, 50), (500, 51), (2000, 52)])])]


# Two drawn boxes (0.6 x 0.6 x 0.5 m) on one model, 0.7 m either side of the root: the left one white (cr_white.mat), the
# right one with a material of two cels, white then grey (cr_two.mat). cr_comp.cos switches what is seen through the
# components: the material (its cel), a mesh (the right box shown or not), a sprite on the left box (white, 0.4 m square,
# 1 m up), the bitmap of an object state.
SMALL_BOX = F.box(0.6, 0.6, 0.5)
TWO_NODES = [("root", -1, -1, (0, 0, 0), (0, 0, 0), (0, 0, 0)),
             ("left", 0, 0, (-0.7, 0, 0), (0, 0, 0), (0, 0, 0)),
             ("right", 1, 0, (0.7, 0, 0), (0, 0, 0), (0, 0, 0))]
COMP_COMPONENTS = [("MMDL", -1, "cr_two.3do"), ("LUAV", -1, "CR_LV"), ("CMAP", 0, "cr_pal.cmp"), ("MAT ", 0, "cr_two.mat"),
                   ("MESH", 0, "mesh 2"), ("MESH", 0, "mesh 1"), ("SPRT", 5, "cr_white.mat,40,40,0,100,0"),
                   ("BKND", -1, "cr_obj.bm")]
COMP_CHORES = [("cel_grey", 100, [(3, [(0, 1)])]),
               ("cel_white", 100, [(3, [(0, 0)])]),
               ("hide_right", 100, [(4, [(0, 0)])]),
               ("show_right", 100, [(4, [(0, 1)])]),
               ("sprite_on", 100, [(6, [(0, 1)])]),
               ("sprite_off", 100, [(6, [(0, 0)])]),
               ("bitmap", 200, [(7, [(0, 1), (100, 2)])])]


# A head that turns: a grey body (0.3 x 0.3 x 0.5 m), a neck node at 0.5 m and on it a white bar 0.9 x 0.15 x 0.15 m along
# x (the head node at 1 m): seen from above, the box of the bar changes when the head yaws (SetActorHead with the joints
# 1, 2, 3: body, neck, head)
HEAD_NODES = [("root", -1, -1, (0, 0, 0), (0, 0, 0), (0, 0, 0)),
              ("body", 0, 0, (0, 0, 0), (0, 0, 0), (0, 0, 0)),
              ("neck", -1, 1, (0, 0, 0.5), (0, 0, 0), (0, 0, 0)),
              ("head", 1, 2, (0, 0, 0.5), (0, 0, 0), (0, 0, 0))]


# A precompiled Lua chunk (formats.lua_chunk): CR_BIN = "yes", CR_BIN_N = 42, CR_BIN_X = 3.5 and CR_BIN_F, a function that
# returns 7 (a nested function of the chunk); one local in the debug information. BIN_FILES: the chunk, one cut short and
# one of an older version (lua5.lua's lex_binary)
BIN_CHUNK = F.lua_chunk(F.lua_function(
    [3, 0, "PUSHCONSTANT", 0, "SETGLOBAL", 1, "PUSHNUMBER", 42, "SETGLOBAL", 2, "PUSHCONSTANT", 3, "SETGLOBAL", 4,
     "PUSHCONSTANT", 5, "SETGLOBAL", 6, "ENDCODE"],
    ["yes", "CR_BIN", "CR_BIN_N", 3.5, "CR_BIN_X",
     F.lua_function([1, 0, "PUSHNUMBER", 7, "RETCODE", 0], line=3), "CR_BIN_F"],
    locals_=[(1, "cr_unused")]))
BIN_FILES = {"cr_bin.lua": BIN_CHUNK, "cr_bin_short.lua": BIN_CHUNK[:40],
             "cr_bin_old.lua": BIN_CHUNK[:4] + bytes([0x30]) + BIN_CHUNK[5:]}


# a font: space 4 pixels, digits 6, upper case 8, the rest 5 (an advance of one more pixel each); EMI's data has it too
FONT = F.font(lambda c: 4 if c == 32 else 6 if 48 <= c <= 57 else 8 if 65 <= c <= 90 else 5)


def _mode2_frames(F, grey, white):
    """The Blocky16 mode 2 frames of cr_mode2.snm (movie_modes.lua): frame A, every block delta buffer 0 (grey) but a white
    one at block (10, 10), becomes delta buffer 1 (swap 1); then 44 frames B (no swap) that draw each code once, white or
    grey, many of them copies out of A: what is white is the fingerprint (cr_snap "count")."""
    import struct
    h, i, u = (lambda v: struct.pack("<h", v)), (lambda v: struct.pack("<I", v)), (lambda v: struct.pack("<H", v))
    W, G = u(white), u(grey)
    params = (white, grey, white, grey)          # (0xf9 and 0xfb white)
    table = {0: grey, 1: white}
    a = F.blocky2(640, 480, {(10, 10): b"\xfe" + W})
    l3 = lambda *c: b"".join(c)
    b = {
        # copies of A's white block (80..87, 80..87): the whole of it, half of it, by the motion table around it
        (20, 10): b"\xf5" + h(-80),
        (30, 10): b"\xf5" + h(84 - 240),
        # (the table's entries: 0x64 is (-3, -2), 0x9d (-6, 3), 0xb5 (4, 6), 0x4d (0, -5), 0x8a (2, 1); 0 (0, 0), 0x10 far)
        (10, 10): bytes([0x64]), (11, 10): bytes([0x9d]), (10, 9): bytes([0xb5]), (10, 11): bytes([0x4d]), (9, 10): bytes([0x8a]),
        (13, 10): bytes([0]), (12, 10): bytes([0xf4]), (10, 12): bytes([0x10]),
        # colours
        (40, 10): b"\xfe" + W, (41, 10): b"\xfd\x01", (42, 10): b"\xf9", (43, 10): b"\xfa", (44, 10): b"\xfb", (45, 10): b"\xfc",
        # four 4 x 4 of 2 x 2 blocks
        (50, 10): b"\xff" + l3(
            b"\xfe" + W,
            b"\xff" + b"\xff" + W + G + W + W + b"\xf8" + G + W + G + W + b"\xf7\x01\x00\x01\x01" + b"\xfe" + W,
            b"\xff" + b"\xfd\x01" + b"\xf9" + b"\xfa" + b"\xf6",
            b"\xff" + b"\xf5" + h(80 - 404) + bytes([5]) + b"\xfb" + b"\xfc"),
        (51, 10): b"\xff" + l3(b"\xfd\x01", b"\xf9", b"\xf8\x03" + i(white | grey << 16), b"\xf7\x46" + u(0x0001)),
        (52, 10): b"\xff" + l3(b"\xf6", b"\xf5" + h(80 - 416), bytes([0x20]), b"\xfb"),
        (53, 10): b"\xff" + l3(b"\xfa", b"\xfe" + G, b"\xfc", b"\xf8\x80" + i(grey | white << 16)),
        # the 8 x 8 blocks cut by an edge of the interpolation table
        (60, 20): b"\xf8\x00" + i(white | grey << 16), (61, 20): b"\xf8\x25" + i(white | grey << 16),
        (62, 20): b"\xf8\x80" + i(white | grey << 16), (63, 20): b"\xf8\xff" + i(white | grey << 16),
        (64, 20): b"\xf7\xc8" + u(0x0001), (65, 20): b"\xf7\x10" + u(0x0100),
    }
    return [(2, (a, 1, params, table))] + [(2, (F.blocky2(640, 480, b), 0, params, table))] * 44


def files():
    out = {}
    out["cr_box.3do"] = F.model3do(*BOX_MODEL)
    for m, h in HEADER_MODELS.items():
        out[m + ".3do"] = F.model3do(m + ".3do", BOX_MODEL[1], BOX_MODEL[2], h)
    # with the header the original works out: a box off the actor's origin, by its vertices or by its node, and one that
    # floats 1 m up (the centres that dc7e5c2 put where the original has them)
    out["cr_meshx.3do"] = F.model3do("cr_meshx.3do", [("body", [(x + 0.5, y, z) for x, y, z in F.box(0.4, 0.3, 1.8)])],
                                     BOX_MODEL[2])
    out["cr_nodex.3do"] = F.model3do("cr_nodex.3do", BOX_MODEL[1],
                                     [BOX_MODEL[2][0], ("body", 0, 0, (0.5, 0, 0), (0, 0, 0), (0, 0, 0))] + BOX_MODEL[2][2:])
    out["cr_float.3do"] = F.model3do("cr_float.3do", [("body", F.box(0.4, 0.3, 0.6, 1.0))], BOX_MODEL[2])
    for m, (fmt, meshes, nodes, h) in FORMAT_MODELS.items():
        if fmt == "text":
            out[m + ".3do"] = F.model3do_text(m + ".3do", meshes, nodes, h)
        else:
            out[m + ".3do"] = F.model3do(m + ".3do", meshes, nodes, h)
    out["cr_white.mat"] = F.material(8, 8, 255)
    out["cr_grey.mat"] = F.material(8, 8, 150)
    out["cr_dbox.3do"] = _draw_model("cr_dbox.3do", "cr_white.mat")
    out["cr_gbox.3do"] = _draw_model("cr_gbox.3do", "cr_grey.mat")
    # (zz_lit.lua: the white draw box lit, lighting mode 3, its vertices at light level 1, a half and 0)
    for n, level in (("cr_lbox", 1.0), ("cr_lbox_half", 0.5), ("cr_lbox_dark", 0.0)):
        out[n + ".3do"] = F.model3do_text(n + ".3do", [("body", DRAW_BOX)], BOX_MODEL[2], materials=["cr_white.mat"],
                                          faces={0: [(0, f) for f in DRAW_FACES]}, lighting=3, vertex_light=level)
        out[n + ".cos"] = F.costume([("MMDL", -1, n + ".3do"), ("LUAV", -1, "CR_LV"), ("CMAP", 0, "cr_pal.cmp")],
                                    BOX_COSTUME[1])
    out["cr_slide.key"] = SLIDE_KEY
    out["cr_slide_b.key"] = SLIDE_KEY_BIN
    out["cr_slide_f.key"] = SLIDE_KEY_FAST
    out["cr_two.mat"] = F.material(8, 8, indices=[255, 150])
    out["cr_two.3do"] = F.model3do_text("cr_two.3do", [("left", SMALL_BOX), ("right", SMALL_BOX)], TWO_NODES,
                                        materials=["cr_white.mat", "cr_two.mat"],
                                        faces={0: [(0, f) for f in DRAW_FACES], 1: [(1, f) for f in DRAW_FACES]}, lighting=0)
    out["cr_comp.cos"] = F.costume(COMP_COMPONENTS, COMP_CHORES)
    out["cr_head.3do"] = F.model3do_text("cr_head.3do", [("body", F.box(0.3, 0.3, 0.5)), ("head", F.box(0.9, 0.15, 0.15))],
                                         HEAD_NODES, materials=["cr_grey.mat", "cr_white.mat"],
                                         faces={0: [(0, f) for f in DRAW_FACES], 1: [(1, f) for f in DRAW_FACES]},
                                         lighting=0)
    out["cr_head.cos"] = F.costume([("MMDL", -1, "cr_head.3do"), ("LUAV", -1, "CR_LV"), ("CMAP", 0, "cr_pal.cmp")],
                                   BOX_COSTUME[1])
    out["cr_dbox.cos"] = F.costume(DRAW_COMPONENTS, BOX_COSTUME[1])
    out["cr_gbox.cos"] = F.costume([("MMDL", -1, "cr_gbox.3do")] + DRAW_COMPONENTS[1:], BOX_COSTUME[1])
    out["cr_kbox.cos"] = F.costume(DRAW_COMPONENTS + [("KEYF", 0, "cr_slide.key")], KEY_CHORES)
    out["cr_kbbox.cos"] = F.costume(DRAW_COMPONENTS + [("KEYF", 0, "cr_slide_b.key")], KEY_CHORES)
    out["cr_kfbox.cos"] = F.costume(DRAW_COMPONENTS + [("KEYF", 0, "cr_slide_f.key")], KEY_CHORES)
    for m in list(HEADER_MODELS) + ["cr_meshx", "cr_nodex", "cr_float"] + list(FORMAT_MODELS):
        out[m + ".cos"] = F.costume([("MMDL", -1, m + ".3do"), ("LUAV", -1, "CR_LV")], BOX_COSTUME[1])
    # a small bitmap of its own for object states and images: the original frees a bitmap with the object state that used
    # it, and a set whose background it was crashes when loaded afterwards
    # (compressed, codec 3, as the game's bitmaps: formats.codec3)
    out["cr_obj.bm"] = F.bitmap(64, 48, F.checker(64, 48, 8, (200, 50, 50), (50, 50, 200)), codec=3)
    # sounds (formats.wav: 16-bit PCM): a short tone and a long one
    out["cr_tone.wav"] = F.wav(0.5)
    out["cr_long.wav"] = F.wav(3.0, freq=220.0)
    # movies (formats.snm): 160 x 120, 15 frames a second; white for 90 frames (6 s), and one that goes from grey to white
    out["cr_white.snm"] = F.snm(160, 120, [F.rgb565(255, 255, 255)] * 90)
    out["cr_steps.snm"] = F.snm(160, 120, [F.rgb565(v, v, v) for v in range(130, 255, 25)])
    # the other Blocky16 modes (movie_modes.lua): the whole screen (640 x 480: the original leaves the last frame of an
    # earlier movie, which a smaller one would not cover), 2 grey frames, raw, then 45 white ones (3 s) in mode 6, 8, 5, 3 or
    # 4 (3 and 4 copy the delta buffers, which start white)
    grey, white = F.rgb565(60, 60, 60), F.rgb565(255, 255, 255)
    for m in (6, 8, 5, 3, 4):
        out["cr_mode%d.snm" % m] = F.snm(640, 480, [grey, grey] + [(m, white)] * 45, fill=white)
    out["cr_mode2.snm"] = F.snm(640, 480, [grey, grey] + _mode2_frames(F, grey, white), fill=grey)
    # music (formats.imus): the files iMUSE's state and sequence tables name for ImSetState / ImSetSequence (the name and
    # ".IMC"). Two states that loop; the file of states 1002-1007 with a hook 8 jump in the middle; a sequence that plays once
    # and ends with the "_end" marker
    # (1008 is compressed as the game's music is, formats.mcmp: the iMUS header stored, the sound in VIMA blocks; 2001 is
    # in MCMP blocks stored as they are)
    out["1001 - Manny's Office.IMC"] = F.imus(2.0, freq=262.0)
    out["1008 - Domino's Office.IMC"] = F.mcmp(*F.imus_split(F.imus(2.0, freq=294.0)))
    out["1002 - Mr. Frustration.IMC"] = F.imus(2.0, freq=330.0, hook_jump=(8, 100))
    out["2001 - Climb Rope.IMC"] = F.mcmp(*F.imus_split(F.imus(1.0, freq=392.0, loop=False, marker="_end")), vima_blocks=False)
    # (the font, FONT)
    out["cr_font.laf"] = FONT
    out["cr_box.cos"] = F.costume(*BOX_COSTUME)
    out["cr_luav.cos"] = F.costume(*LUAV_COSTUME)
    out.update(BIN_FILES)
    out["cr_talk.cos"] = F.costume(*TALK_COSTUME)
    # voices (SayLine plays "<message id>.wav" and lip syncs it with "<message id>.lip"), stored as the game's are: MCMP
    # with the RIFF header and the samples in VIMA blocks. crtv01 has a lip sync file (d, o, f: shapes 2, 7, 4), crtv02 has
    # none (the mumble), crtv03 only a lip sync file, crtv04 a lip sync file of silence only
    for name in ("crtv01", "crtv02", "crtv04"):
        out[name + ".wav"] = F.mcmp(*F.wav_split(F.wav(1.0, freq=200.0)))
    out["crtv01.lip"] = F.lip([(0, 0x64), (20, 0x6F), (40, 0x66)], 62)
    out["crtv03.lip"] = F.lip([(0, 0x64)], 62)
    out["crtv04.lip"] = F.lip([], 62)
    out["cr_pal.cmp"] = F.colormap([(i, i, i) for i in range(256)])
    # The z-buffers: 0xffff everywhere (the background is in front of every model: nothing is drawn; ScreenToWorld gives
    # points on the floor) or, for the sets of OPEN_SETS, 0 (the background is the farthest: the models are drawn;
    # ScreenToWorld gives NaN on the original)
    znear = F.bitmap(W, H, [0xFFFF] * (W * H), fmt=5)
    zfar = F.bitmap(W, H, [0] * (W * H), fmt=5)
    for name, (colours, sectors) in SETS.items():
        out[name + ".bm"] = F.bitmap(W, H, F.checker(W, H, 40, *colours))
        out[name + ".zbm"] = zfar if name in OPEN_SETS else znear
        setup = dict(CAMERA, name=name + "_0", background=name + ".bm", zbuffer=name + ".zbm")
        out[name + ".set"] = F.set_file(["cr_pal.cmp"], [setup], [LIGHT], sectors)
    # zz_lit.lua: cr_open with a black background and LIT_LIGHTS
    out["cr_lit.bm"] = F.bitmap(W, H, F.checker(W, H, 40, (0, 0, 0), (0, 0, 0)))
    out["cr_lit.set"] = F.set_file(["cr_pal.cmp"], [dict(CAMERA, name="cr_lit_0", background="cr_lit.bm", zbuffer="cr_open.zbm")],
                                   LIT_LIGHTS, SETS["cr_open"][1])
    # a set of three setups (cameras): above, from the south at an angle and rolled, and from the east with a narrow fov
    # (compressed, codec 3)
    out["cr_cams.bm"] = F.bitmap(W, H, F.checker(W, H, 80, (90, 90, 40), (120, 120, 60)), codec=3)
    setups = [dict(CAMERA, name="cams_top", background="cr_cams.bm", zbuffer="cr_flat.zbm"),
              dict(name="cams_south", background="cr_cams.bm", zbuffer="cr_flat.zbm", position=(0.0, -5.0, 2.5),
                   interest=(0.0, 0.0, 0.5), roll=5.0, fov=45.0, nclip=0.05, fclip=50.0),
              dict(name="cams_east", background="cr_cams.bm", position=(6.0, 0.5, 1.5), interest=(0.0, 0.0, 0.0),
                   roll=0.0, fov=30.0, nclip=0.1, fclip=40.0)]
    out["cr_cams.set"] = F.set_file(["cr_pal.cmp"], setups, [LIGHT], [
        ("floor", "walk", True, 0.0, rect(-3, -3, 3, 3)),
        ("cam_south", "camera", True, 0.0, rect(-3, -3, 3, 0)),
        ("special_spot", "special", True, 0.0, rect(-1, -1, 1, 1)),
    ])
    _extras(out, "files")
    return out


def _extras(out, what):
    """Adds the files() or loose_files() of every assets_extra_*.py: test data written side by side stays apart (each
    file its own); a name made twice stops the build."""
    import glob
    import importlib
    for path in sorted(glob.glob(os.path.join(os.path.dirname(os.path.abspath(__file__)), "assets_extra_*.py"))):
        mod = importlib.import_module(os.path.splitext(os.path.basename(path))[0])
        if not hasattr(mod, what):
            continue
        extra = getattr(mod, what)()
        clash = sorted(set(extra) & set(out))
        if clash:
            raise SystemExit("%s: names already made: %s" % (os.path.basename(path), ", ".join(clash)))
        out.update(extra)


PATCH_OLD = F.lua_text('CR_PATCHED = "no"\nCR_PATCH_LINE = 1\n')
PATCH_NEW = F.lua_text('CR_PATCHED = "yes"\nCR_PATCH_LINE = 2\nCR_PATCH_MORE = "added"\n')


def loose_files():
    out = _loose_files()
    _extras(out, "loose_files")
    return out


def _loose_files():
    return {"grim.tab": F.text_table(TEXT),
            # (ScummVM's patch files, patchr.lua: the file, a patch for another file, then one for it: "no" becomes "yes",
            # and a line more)
            "cr_patch_target.lua": PATCH_OLD,
            "cr_patch_target.lua.patchr": F.patchr(PATCH_OLD, PATCH_NEW, target=b"another file"),
            "cr_patch_target.lua_1.patchr": F.patchr(PATCH_OLD, PATCH_NEW),
            # (three lines for TextFileGetLine; the second starts at 7)
            "cr_lines.txt": b"line1\r\nline2\r\nline3\r\n",
            # (a file the dofile test runs)
            "cr_dofile_target.lua": F.lua_text('CR_DOFILE = "yes"\n'),
            # (a file that is also in cr_extra.lab, with another value: which of the two is read)
            "cr_dup.lua": F.lua_text('CR_DUP = "loose"\n'),
            # an archive in the game folder beside the loose files (both engines open every .lab of the folder)
            "cr_extra.lab": F.lab({
                "cr_lab_only.lua": F.lua_text('CR_LAB = "lab"\n'),
                "cr_dup.lua": F.lua_text('CR_DUP = "lab"\n'),
                "cr_lab_box.cos": F.costume(*BOX_COSTUME),
                "cr_lab_text.txt": b"from the lab\r\n",
            })}
