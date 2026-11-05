"""Writers for the Grim Fandango file formats the clean-room data needs. Every byte comes from this file or from the
descriptions in assets.py; nothing is read from the game's own data.

The layouts follow what the readers of both engines take (ScummVM engines/grim: lab.cpp, bitmap.cpp, colormap.cpp,
localize.cpp, set.cpp; the original v1.01 exe: Resource_OpenArchivesInDir, Polyglot_LoadTable, stdBitmap_LoadResource).
"""
import math
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


def lab_emi(members):
    """An EMI archive (.m4b) from a {name: bytes} dict: LABN, version 0x10000, the count, the size of the name table and its offset
    plus 0x13d0f, then the entries (name offset, start, size, 0) at 20, then the name table (each byte but the zeros xor 0x96), then
    the files (ScummVM lab.cpp parseMonkey4FileTable; the layout of the game's own archives)."""
    names = sorted(members)
    strtab = b""
    offs = []
    for n in names:
        offs.append(len(strtab))
        strtab += n.encode("ascii") + b"\0"
    table_at = 20 + 16 * len(names)
    pos = table_at + len(strtab)
    entries = b""
    body = b""
    for n, o in zip(names, offs):
        d = members[n]
        entries += struct.pack("<IIII", o, pos, len(d), 0)
        body += d
        pos += len(d)
    coded = bytes(b ^ 0x96 if b else 0 for b in strtab)
    return b"LABN" + struct.pack("<IIII", 0x00010000, len(names), len(strtab), table_at + 0x13d0f) + entries + coded + body


def text_table(entries):
    """grim.tab: 'RCNE' and the lines 'id<TAB>text<CR><LF>' xor 0xdd. Both engines stop at the first empty line, which
    ends the table. The ids are written without the slashes the scripts put round them (/id/)."""
    plain = b"".join(("%s\t%s\r\n" % (k, v)).encode("latin-1") for k, v in entries) + b"\r\n"
    return b"RCNE" + bytes(c ^ 0xDD for c in plain)


def text_table_emi(entries):
    """EMI's script.tab: 'RCNE' and the lines 'id<TAB>text<CR><LF>', each byte xor a key from the C runtime's rand() sequence started
    at 0x16 (next = next * 0x343fd + 0x269ec3, key = ((next >> 16) & 0x7fff) / 32767 * 254 + 1, as a float; ScummVM localize.cpp).
    EMI skips empty lines instead of stopping at them."""
    plain = b"".join(("%s\t%s\r\n" % (k, v)).encode("latin-1") for k, v in entries)
    out = bytearray(b"RCNE")
    nxt = 0x16
    for c in plain:
        nxt = (nxt * 0x343FD + 0x269EC3) & 0xFFFFFFFF
        q = _f32(_f32(_f32(((nxt >> 16) & 0x7FFF) / 32767.0) * 254) + 1)   # (in single precision, as the reader does)
        out.append(c ^ (int(q) & 0xFF))
    return bytes(out)


def _f32(x):
    return struct.unpack("<f", struct.pack("<f", x))[0]


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


def tga(width, height, pixels, bpp=24):
    """An uncompressed true-colour .tga, rows from the top (descriptor bit 5); pixels: (r, g, b) or (r, g, b, a) tuples."""
    desc = 0x20 | (8 if bpp == 32 else 0)
    out = bytearray(struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, width, height, bpp, desc))
    for p in pixels:
        out += bytes((p[2], p[1], p[0]) + ((p[3] if len(p) > 3 else 255,) if bpp == 32 else ()))
    return bytes(out)


def til(width, height, pixels, compress=True):
    """EMI's tiled bitmap (.til), the format of its backgrounds (ScummVM bitmap.cpp BitmapData::loadTile; the layout of the game's
    own files): 'TIL0', the offset of the bitmap part, the counts of the coordinates, layers and polygons, 16 zero bytes, the
    coordinates (screen x and y from -1 to 1, then u and v), the layers (first polygon, count), the polygons (tile, first
    coordinate, count). Then a 128-byte 'BM  F' header (the number of tiles at 16, 2 and the bits per pixel 32 at 32, the bits
    and shifts of r g b at 40) and the tiles: width, height (256, 256), then 256 x 256 pixels of 4 bytes, a b g r (r in the top
    byte). The image is cut into tiles of 256 x 256 from the top left. pixels: (r, g, b) tuples, rows from the top. The game's
    files are gzipped; compress=False writes it plain."""
    import gzip
    T = 256
    coords, polys, tiles = [], [], []
    for ty in range(0, height, T):
        for tx in range(0, width, T):
            w, h = min(T, width - tx), min(T, height - ty)
            x0, x1 = tx / (width / 2.0) - 1, (tx + w) / (width / 2.0) - 1
            y0, y1 = 1 - ty / (height / 2.0), 1 - (ty + h) / (height / 2.0)
            u1, v1 = w / float(T), h / float(T)
            polys.append((len(tiles), len(coords), 4))
            coords += [(x0, y0, 0.0, 0.0), (x1, y0, u1, 0.0), (x1, y1, u1, v1), (x0, y1, 0.0, v1)]
            tile = bytearray(T * T * 4)
            for y in range(h):
                row = pixels[(ty + y) * width + tx:(ty + y) * width + tx + w]
                tile[y * T * 4:y * T * 4 + w * 4] = b"".join(bytes((255, b, g, r)) for r, g, b in row)
            tiles.append(bytes(tile))
    head = b"TIL0" + struct.pack("<IIII", 0, len(coords), 1, len(polys)) + b"\0" * 16
    body = b"".join(struct.pack("<4f", *c) for c in coords) + struct.pack("<II", 0, len(polys))
    body += b"".join(struct.pack("<III", *p) for p in polys)
    bmoff = len(head) + len(body)
    head = head[:4] + struct.pack("<I", bmoff) + head[8:]
    bm = bytearray(128)
    bm[0:5] = b"BM  F"
    struct.pack_into("<I", bm, 16, len(tiles))
    struct.pack_into("<IIIIIIII", bm, 32, 2, 32, 8, 8, 8, 24, 16, 8)
    data = head + body + bytes(bm) + b"".join(struct.pack("<II", T, T) + t for t in tiles)
    return gzip.compress(data, mtime=0) if compress else data


def checker_rgb(width, height, cell, c0, c1):
    """A checker board of two (r, g, b) colours."""
    return [c0 if ((x // cell) + (y // cell)) % 2 == 0 else c1 for y in range(height) for x in range(width)]


SECTOR_TYPES = {"walk": 0x1000, "funnel": 0x1100, "camera": 0x2000, "special": 0x4000, "chernobyl": 0x8000, "hot": 0x8000}
LIGHT_TYPES = {"omni": 1, "spot": 2, "direct": 3, "ambient": 4}


def _fixed(s, n):
    b = s.encode("ascii")
    assert len(b) < n, s
    return b + b"\0" * (n - len(b))


def _counted(s):
    b = s.encode("ascii") + b"\0"
    return struct.pack("<I", len(b)) + b


def set_binary(setups, lights, sectors, shadows=()):
    """EMI's binary .setb (ScummVM set.cpp Set::loadBinary; the original prefers it to a text .set). The same arguments as
    set_file, without colormaps or z-buffers. A setup is: name[128], background (counted string), position, a rotation
    quaternion (x y z w), fov, nclip, fclip; its "rotation" key (default no rotation) is the quaternion. A light: name[32],
    position, quaternion, type, intensity, 0, colour (3 ints), falloff near and far, umbra and penumbra (radians). A sector:
    the vertices, name (counted), id, a visible byte, type, the sort planes (none), height. Then the shadows (none)."""
    f = lambda *v: struct.pack("<%df" % len(v), *v)
    out = struct.pack("<I", len(setups))
    for s in setups:
        out += _fixed(s["name"], 128) + _counted(s.get("background", "")) + f(*s["position"])
        out += f(*s.get("rotation", (0.0, 0.0, 0.0, 1.0))) + f(s.get("fov", 50.0), s.get("nclip", 0.01), s.get("fclip", 100.0))
    out += struct.pack("<I", len(lights))
    for l in lights:
        out += _fixed(l["name"], 32) + f(*l["position"]) + f(*l.get("rotation", (0.0, 0.0, 0.0, 1.0)))
        out += struct.pack("<if", LIGHT_TYPES[l.get("type", "omni")], l.get("intensity", 1.0)) + struct.pack("<i", 0)
        out += struct.pack("<3i", *l.get("color", (255, 255, 255)))
        out += f(l.get("falloff_near", 0.0), l.get("falloff_far", 100.0), l.get("umbra", 0.0), l.get("penumbra", 0.0))
    out += struct.pack("<I", len(sectors))
    for i, (name, typ, visible, height, pts) in enumerate(sectors):
        out += struct.pack("<I", len(pts)) + b"".join(f(*p) for p in pts)
        out += _counted(name) + struct.pack("<IBII", i, 1 if visible else 0, SECTOR_TYPES[typ], 0) + f(height)
    out += struct.pack("<I", len(shadows))
    assert not shadows
    return out


def lua_text(src):
    """Lua source as the engines read it: CR LF line ends (the original's dofile wants them in loose files)."""
    return src.replace("\r\n", "\n").replace("\n", "\r\n").encode("latin-1")


# (each tag as the game's costumes write it: the original compares the four letters exactly, MMDL and mmdl are not the same;
# the class word and the description are the ones of the game's costumes)
COSTUME_TAGS = {"LUAV": ("luav", "int", "Lua Variable"), "MMDL": ("MMDL", "fs", "MAIN RDroid Thing (.3DO)"),
                "MODL": ("MODL", "fs", "RDroid Thing (.3DO)"), "KEYF": ("KEYF", "fs", "RDroid Keyframe (.KEY)"),
                "CMAP": ("cmap", "fs", "RDroid Colormap"), "MESH": ("MESH", "fs", "RDroid Thing Mesh"),
                "IMLS": ("imls", "fs", "iMuse Resident Sound FX"), "MAT ": ("MAT ", "fs", "RDroid Animated Material"),
                "BKND": ("BKND", "fs", "General Bitmap"), "SPRT": ("sprt", "fs", "Sprite")}


def costume(components, chores):
    """A text .cos. components: [(tag, parent id, name)], ids in order; chores: [(name, length ms, [(component id,
    [(time ms, value), ...]), ...])]."""
    tags = []
    for tag, _, _ in components:
        if tag not in tags:
            tags.append(tag)
    out = ["costume v0.1", "", "", "section tags", "\tnumtags %d" % len(tags), ""]
    out += ["\t%d\t'%s'\t%s\t\t%s" % ((i,) + COSTUME_TAGS[t]) for i, t in enumerate(tags)]
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


def _rotation(pitch, yaw, roll):
    """The rotation of a node, as ScummVM builds it (Quaternion::fromEuler(yaw, pitch, roll, EO_ZXY)): yaw about z, then
    pitch about x, then roll about y, in degrees."""
    def rz(a):
        c, s = math.cos(a), math.sin(a)
        return [[c, -s, 0], [s, c, 0], [0, 0, 1]]
    def rx(a):
        c, s = math.cos(a), math.sin(a)
        return [[1, 0, 0], [0, c, -s], [0, s, c]]
    def ry(a):
        c, s = math.cos(a), math.sin(a)
        return [[c, 0, s], [0, 1, 0], [-s, 0, c]]
    mul = lambda a, b: [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]
    return mul(mul(rz(math.radians(yaw)), rx(math.radians(pitch))), ry(math.radians(roll)))


def model_bounds(meshes, nodes):
    """The bounding box (lo, hi), centre and radius of a model as the original works them out (rdModel3_CalcBoundingBoxes):
    every vertex through its node's transform, the centre the middle of the box, the radius half its diagonal. A vertex v
    of a node is at parent * [R | pos] * (pivot + v), as ScummVM draws it."""
    world = []
    allv = []
    for name, mesh, parent, pos, pivot, rot in nodes:
        r = _rotation(*rot)
        if parent >= 0:
            pr, pt = world[parent]
            r2 = [[sum(pr[i][k] * r[k][j] for k in range(3)) for j in range(3)] for i in range(3)]
            t2 = tuple(pt[i] + sum(pr[i][k] * pos[k] for k in range(3)) for i in range(3))
        else:
            r2, t2 = r, tuple(pos)
        world.append((r2, t2))
        if mesh >= 0:
            for v in meshes[mesh][1]:
                p = [v[k] + pivot[k] for k in range(3)]
                allv.append(tuple(t2[i] + sum(r2[i][k] * p[k] for k in range(3)) for i in range(3)))
    allv = allv or [(0.0, 0.0, 0.0)]
    lo = tuple(min(v[i] for v in allv) for i in range(3))
    hi = tuple(max(v[i] for v in allv) for i in range(3))
    centre = tuple((lo[i] + hi[i]) / 2 for i in range(3))
    radius = sum((hi[i] - lo[i]) ** 2 for i in range(3)) ** 0.5 / 2
    return lo, hi, centre, radius


def model3do(name, meshes, nodes, header=None):
    """A binary .3do (LDOM) without materials or faces: what a model gives an actor besides its picture (the bounding box
    and radius for collisions and GetActorRect, the hierarchy for chores and keyframes).
    meshes: [(name, [(x, y, z), ...])]; nodes: [(name, mesh index or -1, parent index or -1, pos, pivot, (pitch, yaw, roll))],
    a parent before its children.
    header: values for the end of the file instead of the ones from the vertices (radius, lo, hi, centre, insert), to tell an
    engine that reads them from one that works them out from the mesh. The original ignores them: rdModel3_LoadPostProcess
    works out the box from the vertices through the node transforms, the centre as its middle and the radius as half its
    diagonal. The default header is that (model_bounds)."""
    f = lambda *v: struct.pack("<%df" % len(v), *v)
    u = lambda *v: struct.pack("<%dI" % len(v), *v)
    s32 = lambda t, n: t.encode("ascii")[:n - 1].ljust(n, b"\0")
    lo, hi, centre, radius = model_bounds(meshes, nodes)
    out = b"LDOM" + u(0) + s32(name, 32) + u(0) + u(1) + u(len(meshes))
    for mname, verts in meshes:
        mr = max([sum(c * c for c in v) ** 0.5 for v in verts] or [0.0])
        out += s32(mname, 32) + u(0) + u(4, 3, 0, len(verts), 0, 0)
        out += b"".join(f(*v) for v in verts)            # vertices
        out += b"".join(f(1.0) for _ in verts)           # vertex intensities
        out += u(*([0] * len(verts))) if verts else b""  # (skipped by the readers)
        out += b"".join(f(0.0, 0.0, 1.0) for _ in verts)  # vertex normals
        out += u(0, 0) + f(mr) + b"\0" * 24             # shadow, -, radius, -
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
        # (the parent, child and sibling words are pointers in the original's memory: nonzero means "an index follows")
        out += s32(nname, 64) + u(0, 0, 1) + struct.pack("<i", mesh) + u(depth[i], 1 if parent >= 0 else 0,
                                                                         len(children[i]), 1 if child >= 0 else 0,
                                                                         1 if sibling >= 0 else 0)
        out += f(*pivot) + f(*pos) + f(*rot) + b"\0" * 48
        for link in (parent, child, sibling):
            if link >= 0:
                out += u(link)
    h = dict(radius=radius, lo=lo, hi=hi, centre=centre, insert=(0.0, 0.0, 0.0))
    h.update(header or {})
    out += f(h["radius"]) + f(*h["lo"]) + f(*h["hi"]) + f(*h["centre"]) + f(*h["insert"])
    return out


def model3do_text(name, meshes, nodes, radius=None, insert=(0.0, 0.0, 0.0), materials=(), faces=None, lighting=3):
    """The same model as model3do, in the text .3do format (the one the original's rdModel3_LoadEntryText parses when a file
    does not start with LDOM). It has no bounding box or centre, only a radius (by default the one the original works out:
    it replaces the one of the file in rdModel3_LoadPostProcess, as it does a binary header's).
    materials: the .mat names; faces: {mesh index: [(material index, [vertex indices])]}, each face with the texture
    vertices of the corners of the texture; lighting: the lighting mode of every mesh and face (0: none, the colours of
    the texture as they are; 3: lit)."""
    g = lambda v: "%.6f" % v
    faces = faces or {}
    out = ["section: header", "3do 2.1", "section: modelresource", "materials %d" % len(materials)]
    out += ["%d: %s" % (i, m) for i, m in enumerate(materials)]
    out += ["section: geometrydef",
           "radius " + g(model_bounds(meshes, nodes)[3] if radius is None else radius),
           "insert offset " + " ".join(g(v) for v in insert), "geosets 1", "geoset 0", "meshes %d" % len(meshes)]
    corners = [(0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0)]
    for i, (mname, verts) in enumerate(meshes):
        mr = max([sum(c * c for c in v) ** 0.5 for v in verts] or [0.0])
        mf = faces.get(i, [])
        out += ["mesh %d" % i, "name " + mname, "radius " + g(mr), "shadow 0", "geometrymode 4",
                "lightingmode %d" % lighting, "texturemode 0", "vertices %d" % len(verts)]
        out += ["%d: %s 1.0" % (k, " ".join(g(c) for c in v)) for k, v in enumerate(verts)]
        out += ["texture vertices %d" % (len(corners) if mf else 0)]
        out += ["%d: %s %s" % (k, g(u), g(v)) for k, (u, v) in enumerate(corners)] if mf else []
        out += ["vertex normals"]
        out += ["%d: 0.0 0.0 1.0" % k for k in range(len(verts))]
        out += ["faces %d" % len(mf)]
        for k, (mat, vs) in enumerate(mf):
            out.append("%d: %d 0x0000 4 %d 0 0.0000 %d %s" % (k, mat, lighting, len(vs),
                                                            " ".join("%d, %d" % (v, j % 4) for j, v in enumerate(vs))))
        out += ["face normals"]
        out += ["%d: 0.0 0.0 1.0" % k for k in range(len(mf))]
    children = [[j for j, n in enumerate(nodes) if n[2] == i] for i in range(len(nodes))]
    out += ["section: hierarchydef", "hierarchy nodes %d" % len(nodes)]
    for i, (nname, mesh, parent, pos, pivot, rot) in enumerate(nodes):
        sibs = children[parent] if parent >= 0 else [j for j, n in enumerate(nodes) if n[2] < 0]
        k = sibs.index(i)
        sibling = sibs[k + 1] if k + 1 < len(sibs) else -1
        child = children[i][0] if children[i] else -1
        out += ["%d: 0x0 0x1 %d %d %d %d %d %s %s" % (i, mesh, parent, child, sibling, len(children[i]),
                                                     " ".join(g(v) for v in tuple(pos) + tuple(rot) + tuple(pivot)), nname)]
    return ("\r\n".join(out) + "\r\n").encode("ascii")


def material(width, height, index=255, cels=1, indices=None):
    """A .mat of one 8-bit texture of colour index `index` (of the colormap the model is drawn with: cr_pal.cmp is a grey
    ramp, 255 white), `cels` cels on it. The layout of rdMaterial_LoadFile (and of what ScummVM reads, MaterialData::initGrim):
    'MAT ', 0x32, flags 2 (no palette), the cels, the textures, 14 words of the texture format (the first the bits a pixel);
    a cel: flags 8 (it has a texture), a colour, four 1.0, then 16 bytes, the fourth word the texture; a texture: width,
    height, flags, two words, the mipmap levels (1), and its pixels."""
    u = lambda *v: struct.pack("<%dI" % len(v), *v)
    f = lambda *v: struct.pack("<%df" % len(v), *v)
    # (the first two words of the format go into each texture's surface description: the second is its bits a pixel, which
    # the original divides by)
    indices = list(indices or [index] * cels)
    out = b"MAT " + u(0x32, 2, len(indices), len(indices)) + u(8, 8) + b"\0" * 48
    for i, c in enumerate(indices):
        out += u(8, c) + f(1.0, 1.0, 1.0, 1.0) + u(0, 0, 0, i)
    for c in indices:
        out += u(width, height, 0, 0, 0, 1) + bytes([c]) * (width * height)
    return out


def keyframe_text(frames, fps, joints, nodes, markers=(), flags=0, type_=0):
    """A text .key (rdKeyframe_LoadEntry; ScummVM KeyframeAnim::loadText). joints: the number of joints (the model's nodes);
    nodes: [(joint index, node name, [(frame, flags, pos, (pitch, yaw, roll), dpos, (dpitch, dyaw, droll)), ...])] (the
    name is matched with the model's node names); markers: [(frame, value)], at most 8."""
    g = lambda v: "%.6f" % v
    out = ["section: header", "flags 0x%x" % flags, "type 0x%x" % type_, "frames %d" % frames, "fps " + g(fps),
           "joints %d" % joints]
    if markers:
        out += ["section: markers", "markers %d" % len(markers)] + ["%s %d" % (g(f), v) for f, v in markers]
    out += ["section: keyframe nodes", "nodes %d" % len(nodes)]
    for index, name, entries in nodes:
        out += ["node %d" % index, "mesh name " + name, "entries %d" % len(entries)]
        for i, (frame, eflags, pos, rot, dpos, drot) in enumerate(entries):
            out.append("%d: %s 0x%x %s" % (i, g(frame), eflags, " ".join(g(v) for v in tuple(pos) + tuple(rot))))
            out.append(" ".join(g(v) for v in tuple(dpos) + tuple(drot)))
    return ("\r\n".join(out) + "\r\n").encode("ascii")


def box(sx, sy, sz, z0=0.0):
    """The 8 corners of a box centred on the z axis, from z0 up."""
    return [(x, y, z) for x in (-sx / 2, sx / 2) for y in (-sy / 2, sy / 2) for z in (z0, z0 + sz)]


def font(widths, height=10, base=8):
    """A .laf bitmap font of 256 characters: character c is widths(c) pixels wide and `height` high; its picture is a frame
    with the bits of c inside (our own glyphs; only the sizes matter to the tests). Header: count, data size, line height,
    baseline, 2, 0, first and last character, the 256 codes, a 16-byte record a character, one byte a pixel (0 or 255)."""
    recs = b""
    data = b""
    for c in range(256):
        w = widths(c)
        pix = bytearray(w * height)
        for y in range(height):
            for x in range(w):
                edge = x == 0 or y == 0 or x == w - 1 or y == height - 1
                bit = (c >> ((x + y) % 8)) & 1
                pix[y * w + x] = 255 if edge or bit else 0
        recs += struct.pack("<IbbbBII", len(data), w + 1, 0, -base, 0, w, height)
        data += bytes(pix)
    head = struct.pack("<8I", 256, len(data), height + 2, base, 2, 0, 0, 255)
    return head + struct.pack("<256H", *range(256)) + recs + data
