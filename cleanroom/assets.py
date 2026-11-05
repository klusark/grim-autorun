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


def files():
    out = {}
    out["cr_box.3do"] = F.model3do(*BOX_MODEL)
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
