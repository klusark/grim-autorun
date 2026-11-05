"""The clean-room data: every file the tests load, described here and written by formats.py.

files() returns {name: bytes} for cleanroom.lab; loose_files() the files that must sit in the game folder itself
(the original reads grim.tab with fopen before it opens any archive)."""
import formats as F

W, H = 640, 480

# The text table: ids are looked up as /id/ (LocalizeString, text objects)
TEXT = [
    ("crt001", "Clean room text one"),
    ("crt002", "Second line, with punctuation: 1, 2; 3."),
    ("crt003", "x"),
    # (wider than the screen in cr_font.laf: 107 characters of 5 and 6 pixels)
    ("crt004", "a line of text that is much too long to fit on the screen in one piece, so that it is clamped at both edges"),
]


def rect(x0, y0, x1, y1, z=0.0):
    return [(x0, y0, z), (x1, y0, z), (x1, y1, z), (x0, y1, z)]


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
}


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
    for m in list(HEADER_MODELS) + ["cr_meshx", "cr_nodex", "cr_float"] + list(FORMAT_MODELS):
        out[m + ".cos"] = F.costume([("MMDL", -1, m + ".3do"), ("LUAV", -1, "CR_LV")], BOX_COSTUME[1])
    # a small bitmap of its own for object states and images: the original frees a bitmap with the object state that used
    # it, and a set whose background it was crashes when loaded afterwards
    out["cr_obj.bm"] = F.bitmap(64, 48, F.checker(64, 48, 8, (200, 50, 50), (50, 50, 200)))
    # a font: space 4 pixels, digits 6, upper case 8, the rest 5 (an advance of one more pixel each)
    out["cr_font.laf"] = F.font(lambda c: 4 if c == 32 else 6 if 48 <= c <= 57 else 8 if 65 <= c <= 90 else 5)
    out["cr_box.cos"] = F.costume(*BOX_COSTUME)
    out["cr_luav.cos"] = F.costume(*LUAV_COSTUME)
    out["cr_pal.cmp"] = F.colormap([(i, i, i) for i in range(256)])
    zfar = F.bitmap(W, H, [0xFFFF] * (W * H), fmt=5)
    for name, (colours, sectors) in SETS.items():
        out[name + ".bm"] = F.bitmap(W, H, F.checker(W, H, 40, *colours))
        out[name + ".zbm"] = zfar
        setup = dict(CAMERA, name=name + "_0", background=name + ".bm", zbuffer=name + ".zbm")
        out[name + ".set"] = F.set_file(["cr_pal.cmp"], [setup], [LIGHT], sectors)
    # a set of three setups (cameras): above, from the south at an angle and rolled, and from the east with a narrow fov
    out["cr_cams.bm"] = F.bitmap(W, H, F.checker(W, H, 80, (90, 90, 40), (120, 120, 60)))
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
    return out


def loose_files():
    return {"grim.tab": F.text_table(TEXT),
            # (three lines for TextFileGetLine; the second starts at 7)
            "cr_lines.txt": b"line1\r\nline2\r\nline3\r\n",
            # (a file the dofile test runs)
            "cr_dofile_target.lua": F.lua_text('CR_DOFILE = "yes"\n')}
