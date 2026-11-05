"""Writers for the Grim Fandango file formats the clean-room data needs. Every byte comes from this file or from the
descriptions in assets.py; nothing is read from the game's own data.

The layouts follow what the readers of both engines take (ScummVM engines/grim: lab.cpp, bitmap.cpp, colormap.cpp,
localize.cpp, set.cpp; the original v1.01 exe: Resource_OpenArchivesInDir, Polyglot_LoadTable, stdBitmap_LoadResource).
"""
import struct


def lab(members):
    """A LABN archive from a {name: bytes} dict (names are stored as given, sorted)."""
    names = sorted(members)
    strtab = b""
    offs = []
    for n in names:
        offs.append(len(strtab))
        strtab += n.encode("ascii") + b"\0"
    pos = 16 + 16 * len(names) + len(strtab)
    entries = b""
    body = b""
    for n, o in zip(names, offs):
        d = members[n]
        entries += struct.pack("<IIII", o, pos, len(d), 0)
        body += d
        pos += len(d)
    return b"LABN" + struct.pack("<III", 0x00010000, len(names), len(strtab)) + entries + strtab + body


def text_table(entries):
    """grim.tab: 'RCNE' and the lines 'id<TAB>text<CR><LF>' xor 0xdd. Both engines stop at the first empty line, which
    ends the table. The ids are written without the slashes the scripts put round them (/id/)."""
    plain = b"".join(("%s\t%s\r\n" % (k, v)).encode("latin-1") for k, v in entries) + b"\r\n"
    return b"RCNE" + bytes(c ^ 0xDD for c in plain)


def _bm_header(fmt, num_images):
    # 0x00 'BM  F\0\0\0', codec 0 (raw), no palette, image count, x, y, transparent colour, format (1 colour, 5 z buffer),
    # 16 bits a pixel, RGB 565 (bits 5 6 5, shifts 11 5 0) and the loss bits 3 2 3 at 0x40; the header is 0x80 bytes
    h = b"BM  F\0\0\0" + struct.pack("<9I", 0, 0, num_images, 0, 0, 0, fmt, 16, 5)
    h += struct.pack("<6I", 6, 5, 11, 5, 0, 3) + struct.pack("<2I", 2, 3)
    return h + b"\0" * (0x80 - len(h))


def bitmap(width, height, pixels_565, fmt=1):
    """A raw (codec 0) .bm/.zbm of one image; pixels_565 is a list of width*height 16-bit values, row by row."""
    assert len(pixels_565) == width * height
    return _bm_header(fmt, 1) + struct.pack("<II", width, height) + struct.pack("<%dH" % len(pixels_565), *pixels_565)


def rgb565(r, g, b):
    return ((r >> 3) << 11) | ((g >> 2) << 5) | (b >> 3)


def checker(width, height, cell, c0, c1):
    """Background pixels: a checkerboard of two RGB colours (cells of `cell` pixels)."""
    a, b = rgb565(*c0), rgb565(*c1)
    return [a if ((x // cell) + (y // cell)) % 2 == 0 else b for y in range(height) for x in range(width)]


def colormap(colors):
    """A .cmp: 'CMP ', the header words, and 256 RGB triples at 64."""
    pal = bytearray(768)
    for i, (r, g, b) in enumerate(colors[:256]):
        pal[3 * i:3 * i + 3] = bytes((r, g, b))
    h = b"CMP " + struct.pack("<II3f", 0x1E, 4, 1.0, 1.0, 1.0)
    return h + b"\0" * (64 - len(h)) + bytes(pal)


def set_file(colormaps, setups, lights, sectors):
    """A text .set. setups: dicts (name, background, zbuffer, position, interest, roll, fov, nclip, fclip);
    lights: dicts (name, type, position, direction, intensity, umbra, penumbra, color); sectors: tuples
    (name, type, visible, height, [(x, y, z), ...]). Lines end with CR LF (the game's own files do)."""
    v3 = lambda p: "%f\t%f\t%f" % p
    out = ["section: colormaps", "\tnumcolormaps\t%d" % len(colormaps)]
    out += ["\tcolormap\t%s" % c for c in colormaps]
    out += ["", "", "section: setups", "\tnumsetups\t%d" % len(setups), ""]
    for s in setups:
        out += ["\tsetup\t\t%s" % s["name"], "\tbackground\t%s" % s["background"]]
        if s.get("zbuffer"):
            out += ["\tzbuffer\t\t%s" % s["zbuffer"]]
        out += ["\tposition\t%s" % v3(s["position"]), "\tinterest\t%s" % v3(s["interest"]),
                "\troll\t\t%f" % s.get("roll", 0.0), "\tfov\t\t%f" % s.get("fov", 50.0),
                "\tnclip\t\t%f" % s.get("nclip", 0.01), "\tfclip\t\t%f" % s.get("fclip", 100.0), ""]
    out += ["", "section: lights", "\tnumlights\t%d" % len(lights), ""]
    for l in lights:
        out += ["\tlight\t\t%s" % l["name"], "\ttype\t\t%s" % l.get("type", "omni"),
                "\tposition\t%s" % v3(l["position"]), "\tdirection\t%s" % v3(l.get("direction", (0, 0, 0))),
                "\tintensity\t%f" % l.get("intensity", 1.0), "\tumbraangle\t%f" % l.get("umbra", 0.0),
                "\tpenumbraangle\t%f" % l.get("penumbra", 0.0), "\tcolor\t\t%d %d %d" % l.get("color", (255, 255, 255)), ""]
    out += ["", "section: sectors", ""]
    for i, (name, typ, visible, height, pts) in enumerate(sectors):
        out += ["\tsector\t\t%s" % name, "\tID\t\t%d" % i, "\ttype\t\t%s" % typ,
                "\tdefault visibility\t\t%s" % ("visible" if visible else "invisible"),
                "\theight\t\t%.2f" % height, "\tnumvertices\t%d" % len(pts)]
        for j, p in enumerate(pts):
            out += ["\t%s\t%f\t%f\t%f" % (("vertices:" if j == 0 else "         "), p[0], p[1], p[2])]
        out += ["", ""]
    return ("\r\n".join(out) + "\r\n").encode("ascii")


def lua_text(src):
    """Lua source as the engines read it: CR LF line ends (the original's dofile wants them in loose files)."""
    return src.replace("\r\n", "\n").replace("\n", "\r\n").encode("latin-1")


# (the class word and the description the game's own costumes give each tag)
COSTUME_TAGS = {"LUAV": ("int", "Lua Variable"), "MMDL": ("fs", "MAIN RDroid Thing (.3DO)"),
                "MODL": ("fs", "RDroid Thing (.3DO)"), "KEYF": ("fs", "RDroid Keyframe (.KEY)"),
                "CMAP": ("fs", "RDroid Colormap")}


def costume(components, chores):
    """A text .cos. components: [(tag, parent id, name)], ids in order; chores: [(name, length ms, [(component id,
    [(time ms, value), ...]), ...])]."""
    tags = []
    for tag, _, _ in components:
        if tag not in tags:
            tags.append(tag)
    out = ["costume v0.1", "", "", "section tags", "\tnumtags %d" % len(tags), ""]
    out += ["\t%d\t'%s'\t%s\t\t%s" % ((i, t.lower()) + COSTUME_TAGS[t]) for i, t in enumerate(tags)]
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
