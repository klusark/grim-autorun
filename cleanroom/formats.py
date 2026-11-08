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


def _bm_header(fmt, num_images, codec=0):
    # 0x00 'BM  F\0\0\0', the codec (0 raw, 3 compressed), no palette, image count, x, y, transparent colour, format (1
    # colour, 5 z buffer), 16 bits a pixel, RGB 565 (bits 5 6 5, shifts 11 5 0) and the loss bits 3 2 3 at 0x40; the
    # header is 0x80 bytes
    h = b"BM  F\0\0\0" + struct.pack("<9I", codec, 0, num_images, 0, 0, 0, fmt, 16, 5)
    h += struct.pack("<6I", 6, 5, 11, 5, 0, 3) + struct.pack("<2I", 2, 3)
    return h + b"\0" * (0x80 - len(h))


def bitmap(width, height, pixels_565, fmt=1, codec=0):
    """A .bm/.zbm of one image; pixels_565 is a list of width*height 16-bit values, row by row. Codec 0 stores them, codec
    3 compresses them (`codec3`): the size of the compressed data, then the data."""
    assert len(pixels_565) == width * height
    raw = struct.pack("<%dH" % len(pixels_565), *pixels_565)
    if codec == 3:
        packed = codec3(raw)
        return _bm_header(fmt, 1, 3) + struct.pack("<III", width, height, len(packed)) + packed
    return _bm_header(fmt, 1) + struct.pack("<II", width, height) + raw


def codec3(data):
    """The LZ compression of the game's bitmaps (ScummVM bitmap.cpp, decompress_codec3): flag bits, least significant
    first, from 16-bit little-endian words that sit in the stream where the previous word's last bit was used. A 1 bit is
    a byte as it is. 0 0 a b and a byte o: copy 2a + b + 3 bytes from o - 256 back. 0 1 and two bytes: a 12-bit offset
    from 4096 back, and the length less 3 in the low 4 bits; a length field of 0 takes the length less 1 from a third byte,
    and a third byte of 0 ends the data. Matches are found greedily (longest first), in a 4096-byte window."""
    out = bytearray(2)
    flag = [0, 0, 0]  # the word's position, its value, its bits used

    def bit(b):
        flag[1] |= b << flag[2]
        flag[2] += 1
        if flag[2] == 16:
            out[flag[0]:flag[0] + 2] = struct.pack("<H", flag[1])
            flag[0], flag[1], flag[2] = len(out), 0, 0
            out.extend(b"\0\0")

    where = {}
    i, n = 0, len(data)
    while i < n:
        best_len, best_off = 0, 0
        for j in reversed(where.get(data[i:i + 3], [])):
            if i - j > 4096:
                break
            k = 0
            while i + k < n and k < 256 and data[j + k] == data[i + k]:
                k += 1
            if k > best_len:
                best_len, best_off = k, i - j
                if k == 256:
                    break
        if best_len >= 3:
            if best_off <= 256 and best_len <= 6:
                bit(0); bit(0)
                bit((best_len - 3) >> 1); bit((best_len - 3) & 1)
                out.append(256 - best_off)
            else:
                o = 4096 - best_off
                bit(0); bit(1)
                # (a length field of 0 means a third byte: a long copy of 3 takes one)
                if 4 <= best_len <= 18:
                    out.extend(bytes([o & 0xFF, ((o >> 4) & 0xF0) | (best_len - 3)]))
                else:
                    out.extend(bytes([o & 0xFF, (o >> 4) & 0xF0, best_len - 1]))
            step = best_len
        else:
            bit(1)
            out.append(data[i])
            step = 1
        for m in range(i, min(i + step, n - 2)):
            where.setdefault(data[m:m + 3], []).append(m)
        i += step
    # (the end: a long copy whose third byte is 0)
    bit(0); bit(1)
    out.extend(b"\0\0\0")
    out[flag[0]:flag[0] + 2] = struct.pack("<H", flag[1])
    return bytes(out)


def codec3_decode(comp, size):
    """decompress_codec3 (to check `codec3`)."""
    pos, res = 2, bytearray()
    val, left = struct.unpack("<H", comp[0:2])[0], 16

    def get():
        nonlocal val, left, pos
        b = val & 1
        val >>= 1
        left -= 1
        if left == 0:
            val = struct.unpack("<H", comp[pos:pos + 2])[0]
            left = 16
            pos += 2
        return b

    while True:
        if get():
            res.append(comp[pos])
            pos += 1
            continue
        if not get():
            ln = 2 * get()
            ln += get() + 3
            off = comp[pos] - 0x100
            pos += 1
        else:
            off = (comp[pos] | (comp[pos + 1] & 0xF0) << 4) - 0x1000
            ln = (comp[pos + 1] & 0xF) + 3
            pos += 2
            if ln == 3:
                ln = comp[pos] + 1
                pos += 1
                if ln == 1:
                    return bytes(res[:size])
        for _ in range(ln):
            res.append(res[off])


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


# Lua 3.1 bytecode (ScummVM engines/grim/lua/lundump.cpp, lopcodes.h): what luac writes and the game's own scripts are.
# The opcodes the chunk of assets.BIN_CHUNK uses (their numbers in lopcodes.h's order).
LUA_OP = {"ENDCODE": 0, "PUSHNUMBER": 3, "PUSHCONSTANT": 8, "SETGLOBAL": 74, "RETCODE": 123}


def _lua_tstring(s):
    """A string of a chunk: its size with the zero (16-bit big endian), then its bytes and the zero, each xor 0xff."""
    if s is None:
        return b"\0\0"
    b = s.encode("latin-1") + b"\0"
    return struct.pack(">H", len(b)) + bytes(c ^ 0xFF for c in b)


def lua_function(code, consts=(), locals_=(), line=0, name="cr_bin.lua"):
    """One function of a chunk: the line it is defined on, the file name, the code (the stack size and the parameter count,
    then the opcodes and their byte operands: a list of ints or LUA_OP names), the constants (a number 'N', a string 'S', or
    a nested function as the bytes of lua_function 'F'), the locals [(line, name)], then the nested functions (each '#',
    its constant index, the function) and '$'."""
    body = bytes(LUA_OP[c] if isinstance(c, str) else c for c in code)
    out = struct.pack(">H", line) + _lua_tstring(name) + struct.pack(">I", len(body)) + body
    out += struct.pack(">H", len(consts))
    nested = b""
    for i, c in enumerate(consts):
        if isinstance(c, (int, float)):
            out += b"N" + struct.pack("<f", c)
        elif isinstance(c, str):
            out += b"S" + _lua_tstring(c)
        else:
            out += b"F"
            nested += b"#" + struct.pack(">H", i) + c
    out += struct.pack(">H", len(locals_)) + b"".join(struct.pack(">H", ln) + _lua_tstring(n) for ln, n in locals_)
    return out + nested + b"$"


def lua_chunk(main):
    """A precompiled chunk: ESC "Lua", the version 0x31, the size of a number (4: a float), the 4 bytes of the test number
    (as in the game's scripts), then the main function (lua_function)."""
    return b"\x1bLua" + bytes([0x31, 4]) + bytes.fromhex("460abf17") + main


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


def keyframe_binary(frames, fps, joints, nodes, markers=(), flags=0, type_=0, name="cr.key", names=None):
    """A binary .key (ScummVM KeyframeAnim::loadBinary): 'FYEK', the name (36 bytes), then at 40 the flags, the joint
    count, the type, the fps (float), at 56 the frame count, the joint count, 0 and the marker count; the marker frames
    (floats) at 72 and their values at 104, 8 of each; from 136 one record a joint: its node's name (32 bytes), the joint
    index, the entry count, 0, and the entries (frame, flags, x y z, pitch yaw roll, their deltas: floats, the flags a
    32-bit int). nodes as in keyframe_text; a joint without one has no entries, under its name in `names`."""
    assert len(markers) <= 8
    h = b"FYEK" + _fixed(name, 36) + struct.pack("<IIIfIIII", flags, joints, type_, fps, frames, joints, 0, len(markers))
    h += b"".join(struct.pack("<f", f) for f, _ in markers) + b"\0" * (4 * (8 - len(markers)))
    h += b"".join(struct.pack("<I", v) for _, v in markers) + b"\0" * (4 * (8 - len(markers)))
    assert len(h) == 136
    by = {index: (nm, entries) for index, nm, entries in nodes}
    for j in range(joints):
        nm, entries = by.get(j, ((names or {}).get(j, ""), []))
        h += _fixed(nm, 32) + struct.pack("<III", j, len(entries), 0)
        for frame, eflags, pos, rot, dpos, drot in entries:
            h += struct.pack("<fI12f", frame, eflags, *(tuple(pos) + tuple(rot) + tuple(dpos) + tuple(drot)))
    return h


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


def wav(seconds, rate=22050, freq=440.0, channels=1, amplitude=8000):
    """A RIFF WAVE of 16-bit PCM: a sine tone of `seconds` (what iMUSE plays, uncompressed, as ScummVM reads it)."""
    n = int(seconds * rate)
    frames = b"".join(struct.pack("<h", int(amplitude * math.sin(2 * math.pi * freq * i / rate))) * channels for i in range(n))
    fmt = struct.pack("<HHIIHH", 1, channels, rate, rate * channels * 2, channels * 2, 16)
    body = b"WAVE" + b"fmt " + struct.pack("<I", len(fmt)) + fmt + b"data" + struct.pack("<I", len(frames)) + frames
    return b"RIFF" + struct.pack("<I", len(body)) + body


def bomp(data):
    """BOMP coding (ScummVM blocky16.cpp, bompDecode): a control byte, the count less 1 in its upper 7 bits and in its low bit
    1 for a run (one byte, repeated) or 0 for that many bytes as they are; at most 128 bytes a control byte."""
    out = bytearray()
    i, n = 0, len(data)
    while i < n:
        run = 1
        while i + run < n and run < 128 and data[i + run] == data[i]:
            run += 1
        if run >= 3:
            out += bytes([((run - 1) << 1) | 1, data[i]])
            i += run
            continue
        j = i
        while j < n and j - i < 128 and not (j + 2 < n and data[j] == data[j + 1] == data[j + 2]):
            j += 1
        out += bytes([(j - i - 1) << 1]) + data[i:j]
        i = j
    return bytes(out)


def bomp_decode(coded, size):
    """bompDecode (to check `bomp`)."""
    out, i = bytearray(), 0
    while len(out) < size:
        c = coded[i]
        num = (c >> 1) + 1
        if c & 1:
            out += bytes([coded[i + 1]]) * num
            i += 2
        else:
            out += coded[i + 1:i + 1 + num]
            i += 1 + num
    return bytes(out[:size])


def snm(width, height, colours, frame_us=66667, rate=22050, fill=None):
    """A SMUSH movie as Grim's (gzipped SANM): one Bl16 frame per colour, each a whole frame of that RGB565 colour, raw
    (Blocky16 mode 0: the 560-byte frame header, then width * height pixels, little endian). SHDR as Insane_ReadFrameHeader
    (0x4bd7c0) and ScummVM's SmushDecoder read it: x, y, width, height at +4..+10, the time of a frame in us at +14, the size
    of the largest frame at +18 (more than 0), a 1024-byte palette; FLHD with a Bl16 of the frame size and the Wave header (declared 8
    bytes: the rate and the channels, then the total size of the audio). Every frame has its Wave too: the sample count (big
    endian) and VIMA data of silence (all zero: step index 0, predictor 0, codes 0), as the game's movies all have sound."""
    import gzip

    def chunk(tag, body):
        return tag + struct.pack(">I", len(body)) + body + (b"\0" if len(body) & 1 else b"")

    samples = rate * frame_us // 1000000
    wave = struct.pack(">i", samples) + bytes(3 + samples)
    frames = []
    # (a frame is a colour, raw, or (mode, colour): Blocky16 mode 6 indexes the 256-colour table at +40 of the header with
    # a byte a pixel; 8 the same with the bytes BOMP coded (bomp); 5 the 16-bit pixels BOMP coded, their size at +36; 3 and 4
    # copy a delta buffer, which keeps the colour at +32 of frame 0 when no frame swaps the buffers)
    if fill is None:
        fill = colours[0] if isinstance(colours[0], int) else colours[0][1]
    for i, c in enumerate(colours):
        mode, c = (0, c) if isinstance(c, int) else c
        head = bytearray(560)
        # (the original's Blocky16_DecodeFrame 0x4ccd00 takes the frame's size from +8 and +12; +0x228, the pixel format, 0:
        # 8, 16 bits. ScummVM's Blocky16 has the size from SHDR)
        struct.pack_into("<HH", head, 8, width, 0)
        struct.pack_into("<HH", head, 12, height, 0)
        struct.pack_into("<H", head, 16, i)          # (sequence number: frame 0 starts the delta buffers)
        head[18] = mode
        head[19] = 0                                  # (no buffer swap)
        struct.pack_into("<H", head, 32, fill)        # (the colour the delta buffers start with)
        pixels = struct.pack("<H", c) * (width * height)
        if mode == 0:
            data = pixels
        elif mode in (6, 8):
            struct.pack_into("<H", head, 40, c)
            data = bytes(width * height) if mode == 6 else bomp(bytes(width * height))
        elif mode == 5:
            struct.pack_into("<I", head, 36, len(pixels))
            data = bomp(pixels)
        elif mode in (3, 4):
            data = b""
        else:
            raise ValueError("mode %d" % mode)
        frames.append(chunk(b"FRME", chunk(b"Bl16", bytes(head) + data) + chunk(b"Wave", wave)))
    biggest = max(len(f) for f in frames)
    shdr = bytearray(struct.pack("<BBHHHHHHII", 1, 1, len(colours), 0, 0, width, height, 0, frame_us, biggest))
    shdr += bytes(1024) + struct.pack("<H", 0)
    # (FLHD's Bl16 goes to the same Blocky16_Prepare: the frame size and pixel format, 16 bits)
    flhd = chunk(b"Bl16", struct.pack("<HHHH", 0, width, height, 2)) + b"Wave" + struct.pack(">I", 8) + struct.pack("<II", rate, 1) + struct.pack("<I", 2 * samples * len(colours))
    body = chunk(b"SHDR", bytes(shdr)) + chunk(b"FLHD", flhd) + b"".join(frames)
    return gzip.compress(b"SANM" + struct.pack(">I", len(body)) + body, mtime=0)


class _Bits:
    """A bit writer in Bink's order: each value's low bit first, packed into 32-bit little-endian words."""

    def __init__(self):
        self.acc = 0
        self.n = 0

    def put(self, nbits, v):
        assert 0 <= v < (1 << nbits), (nbits, v)
        self.acc |= v << self.n
        self.n += nbits

    def align32(self):
        self.n = (self.n + 31) & ~31

    def bytes(self):
        assert self.n % 32 == 0
        return self.acc.to_bytes(self.n // 8, "little")


def _yuv(rgb):
    """RGB to the ITU-R BT.601 YUV (16-235) that Bink decodes with."""
    r, g, b = rgb
    y = 16 + 0.257 * r + 0.504 * g + 0.098 * b
    u = 128 - 0.148 * r - 0.291 * g + 0.439 * b
    v = 128 + 0.439 * r - 0.368 * g - 0.071 * b
    return tuple(max(0, min(255, int(round(c)))) for c in (y, u, v))


def _bink_plane(bits, blocks_w, blocks_h, value, width):
    """One plane of a Bink 1 frame (BIKi) whose 8x8 blocks are all fill blocks (block type 6, one colour each): value(bx, by)
    gives a block's byte. As ScummVM's BinkDecoder::decodePlane (and FFmpeg's bink_decode_plane) read it: the Huffman tree
    of each bundle (4 bits; tree 0 sends raw nibbles, and the colours have 16 more for their high nibbles), then per row of
    blocks each bundle whose values are used up reads a count (n == 0: no more of it in this plane) and its values. Here every
    row brings its block types (all the same: the flag 1 and 6) and its colours; the other bundles get 0 on the first row.
    width: the plane's width in pixels (the bundles' count lengths follow from it)."""
    lg = lambda x: x.bit_length() - 1  # noqa: E731
    w = max(width, 8)
    cbw = (width + 7) >> 3
    n_bt = lg((w >> 3) + 511) + 1
    n_sub = lg(((w + 7) >> 4) + 511) + 1
    n_col = lg(cbw * 64 + 511) + 1
    n_small = lg((w >> 3) + 511) + 1        # (motion x, y, the two DCs)
    n_pat = lg((cbw << 3) + 511) + 1
    n_run = lg(cbw * 48 + 511) + 1
    for source in range(9):                 # (block types, sub block types, colours, pattern, x, y, intra DC, inter DC, run)
        if source == 2:
            for _ in range(16):
                bits.put(4, 0)
        if source not in (6, 7):
            bits.put(4, 0)
    for by in range(blocks_h):
        bits.put(n_bt, blocks_w)
        bits.put(1, 1)
        bits.put(4, 6)
        if by == 0:
            bits.put(n_sub, 0)
        row = [value(bx, by) for bx in range(blocks_w)]
        bits.put(n_col, blocks_w)
        if all(v == row[0] for v in row):
            bits.put(1, 1)
            bits.put(4, row[0] >> 4)
            bits.put(4, row[0] & 15)
        else:
            bits.put(1, 0)
            for v in row:
                bits.put(4, v >> 4)
                bits.put(4, v & 15)
        if by == 0:
            for n in (n_pat, n_small, n_small, n_small, n_small, n_run):
                bits.put(n, 0)
    bits.align32()


def bik(width, height, frames, fps=15):
    """A Bink 1 movie, revision i (BIKi, as EMI's movies; ScummVM's BinkDecoder and the original's binkw32.dll read it), with
    no sound track. frames: one per frame, either an RGB colour (the whole frame) or a function (x, y) -> RGB, asked once per
    8 x 8 block at its top-left pixel (the colour planes, at half size, once per 16 x 16). Every block is a fill block, every
    frame a key frame. The header: 'BIKi', the size after the first 8 bytes, the frame count, the largest frame, the frame
    count again, width, height, the frame rate (num, den), flags, the number of audio tracks (0); then the frame offsets (bit 0:
    key frame) and one more, the end of the file. A frame of BIKi starts with 32 bits, the byte offset of the second plane in
    the frame; then Y and the two colour planes (V first: BIKi swaps them), each at a 32-bit boundary."""
    yw, yh = (width + 7) >> 3, (height + 7) >> 3
    cw, ch = (width + 15) >> 4, (height + 15) >> 4
    packets = []
    for f in frames:
        at = f if callable(f) else (lambda x, y, c=f: c)
        y_of = lambda bx, by: _yuv(at(bx * 8, by * 8))[0]        # noqa: E731
        c_of = lambda bx, by: _yuv(at(bx * 16, by * 16))          # noqa: E731
        luma = _Bits()
        _bink_plane(luma, yw, yh, y_of, width)
        chroma = _Bits()
        _bink_plane(chroma, cw, ch, lambda bx, by: c_of(bx, by)[2], width >> 1)
        _bink_plane(chroma, cw, ch, lambda bx, by: c_of(bx, by)[1], width >> 1)
        y = luma.bytes()
        packets.append(struct.pack("<I", 4 + len(y)) + y + chroma.bytes())
    n = len(packets)
    head_size = 44 + 4 * (n + 1)
    offsets, pos = [], head_size
    for p in packets:
        offsets.append(pos | 1)
        pos += len(p)
    offsets.append(pos)
    head = b"BIKi" + struct.pack("<IIIIIIIIII", pos - 8, n, max(len(p) for p in packets), n, width, height, fps, 1, 0, 0)
    return head + struct.pack("<%dI" % (n + 1), *offsets) + b"".join(packets)


# EMI's costumes, skeletons, meshes and animations (ScummVM engines/grim/emi: costumeemi.cpp, skeleton.cpp, modelemi.cpp,
# animationemi.cpp). A costume names its parts without the "b" of their files (clv.skl is clv.sklb).

def _la_string(s):
    """A string as EMI's binary files have it: its length with the closing zero, then the string and the zero."""
    b = s.encode("ascii") + b"\0"
    return struct.pack("<I", len(b)) + b


def cosb(chores):
    """An EMI costume (.cosb): the chore count, then each chore: its name, its length in seconds (1000: no end) and its
    tracks. A track names its component ("!" and a 4-letter type: "!skelcr.skl", "!meshcr.mesh", "!animcr.anim",
    "!luavCR_LV"), a flag word, its parent component (-1: none) and its keys (time in seconds, value: floats).
    chores: [(name, length, [(component, flag, parent, [(time, value), ...]), ...])]."""
    out = struct.pack("<I", len(chores))
    for name, length, tracks in chores:
        out += _la_string(name) + struct.pack("<fI", length, len(tracks))
        for comp, flag, parent, keys in tracks:
            out += _la_string(comp) + struct.pack("<IiI", flag, parent, len(keys))
            out += b"".join(struct.pack("<ff", t, v) for t, v in keys)
    return out


def sklb(joints):
    """An EMI skeleton (.sklb): the joint count, then each joint: its name and its parent's (32 bytes each; "no_parent" for the root, as the game's: the original looks the parent up by name and
    crashes on an empty one),
    its position (x y z) and its rotation (a quaternion x y z w). joints: [(name, parent, pos, quat)]."""
    out = struct.pack("<I", len(joints))
    for name, parent, pos, quat in joints:
        out += _fixed(name, 32) + _fixed(parent, 32) + struct.pack("<7f", *(tuple(pos) + tuple(quat)))
    return out


def meshb(name, vertices, faces, bones=None, normal=(0.0, 1.0, 0.0), colour=(255, 255, 255, 255), texture="default.tga"):
    """An EMI mesh (.meshb, type 19): its name, a radius, a centre and its box (min, max), one texture set with one texture
    (none of the faces use it), the vertices, a normal, a colour (RGBA) and texture coordinates (0, 0) each, the faces (no texture, 16-bit vertex
    indices, three a triangle) and, with `bones` ([(joint name, [vertex index, ...])]), the bones: each vertex follows the
    one joint it is listed under, with weight 1."""
    xs, ys, zs = zip(*vertices)
    lo, hi = (min(xs), min(ys), min(zs)), (max(xs), max(ys), max(zs))
    centre = tuple((a + b) / 2 for a, b in zip(lo, hi))
    radius = max(math.sqrt(sum((v[i] - centre[i]) ** 2 for i in range(3))) for v in vertices)
    out = _la_string(name) + struct.pack("<4f", radius, *centre) + struct.pack("<6f", *(lo + hi))
    # (one texture set of one texture, as the game's meshes have at least that; the faces use none)
    out += struct.pack("<III", 1, 0, 1) + _la_string(texture) + struct.pack("<I", 0)
    out += struct.pack("<II", 19, len(vertices))
    out += b"".join(struct.pack("<3f", *v) for v in vertices)
    out += struct.pack("<3f", *normal) * len(vertices)
    out += bytes(colour) * len(vertices)
    out += struct.pack("<2f", 0.0, 0.0) * len(vertices)
    # (one face: the flags of the game's (0x304), no texture, then the index count and the indices of every triangle)
    out += struct.pack("<I", 1) + struct.pack("<III", 0x304, 0, 3 * len(faces))
    out += b"".join(struct.pack("<3H", *tri) for tri in faces)
    if bones:
        out += struct.pack("<II", 1, len(bones))
        out += b"".join(_la_string(j) for j, _ in bones)
        infos = sorted((v, i) for i, (_, vs) in enumerate(bones) for v in vs)
        out += struct.pack("<I", len(infos))
        # (each vertex: incFac 1 moves on to the next vertex after this joint)
        out += b"".join(struct.pack("<IIf", 1, i, 1.0) for _, i in infos)
    else:
        out += struct.pack("<I", 0)
    return out


def animb(name, seconds, bones):
    """An EMI animation (.animb): its name, its length in seconds and its bones. A bone names a joint, its operation (3 a
    translation, 4 a rotation), a priority, a third word and its keys: x y z (and w for a rotation, a quaternion), then the
    time in seconds. bones: [(joint, operation, priority, [(values, time), ...])]."""
    out = _la_string(name) + struct.pack("<fI", seconds, len(bones))
    for joint, op, priority, keys in bones:
        out += _la_string(joint) + struct.pack("<IIII", op, priority, 0, len(keys))
        for values, t in keys:
            out += struct.pack("<%df" % len(values), *values) + struct.pack("<f", t)
    return out


def imus(seconds, rate=22050, freq=330.0, loop=True, marker=None, hook_jump=None, amplitude=6000):
    """iMUSE's own sound format, as the game's music (.IMC; uncompressed, no MCMP): 'iMUS', a MAP and the DATA of 16-bit mono
    PCM (a sine tone), laid out as IMuse::createSoundHeader writes it: FRMT (offset, endianness 0, word size, rate,
    channels), the regions, STOP; every offset is a position in the file. Two regions of half the tone each, with a TEXT
    marker between them when `marker` is given (iMUSE's triggers: "_end" and the like) and, at the end, a JUMP back to the
    start (hook 0: taken unless the track's hook is 128) when `loop`. `hook_jump` (hook id, fade ms): a JUMP in the
    middle back to the start, taken only when the track has that hook (ImSetState to a state of the same file with it)."""
    n = int(seconds * rate) & ~1
    pcm = b"".join(struct.pack("<h", int(amplitude * math.sin(2 * math.pi * freq * i / rate))) for i in range(n))
    half = (len(pcm) // 4) * 2

    def block(tag, *fields):
        body = b"".join(struct.pack(">I", f & 0xFFFFFFFF) for f in fields)
        return tag + struct.pack(">I", len(body)) + body

    def text(offset, s):
        body = struct.pack(">I", offset) + s.encode("latin-1") + b"\0"
        return b"TEXT" + struct.pack(">I", len(body)) + body

    def build(data_at):
        m = block(b"FRMT", data_at, 0, 16, rate, 1)
        m += block(b"REGN", data_at, half)
        if hook_jump:
            m += block(b"JUMP", data_at + half, data_at, hook_jump[0], hook_jump[1])
        if marker:
            m += text(data_at + half, marker)
        m += block(b"REGN", data_at + half, len(pcm) - half)
        if loop:
            m += block(b"JUMP", data_at + len(pcm), data_at, 0, 0)
        m += block(b"STOP", data_at + len(pcm))
        return b"MAP " + struct.pack(">I", len(m)) + m

    # (the map's size moves the data: build it once to know where the data is)
    head = 16 + len(build(0)) - 8 + 8
    mp = build(head)
    body = mp + b"DATA" + struct.pack(">I", len(pcm)) + pcm
    out = b"iMUS" + struct.pack(">I", len(body)) + body
    return out


# VIMA, the ADPCM of iMUSE's compressed sounds (ScummVM engines/grim/movie/codecs/vima.cpp, decompressVima): a step index
# picks how many bits the next sample's code has (4 to 7) and the step it scales; a code with all its low bits set is an
# escape followed by the 16-bit sample itself.
_VIMA_STEPS = [
    7, 8, 9, 10, 11, 12, 13, 14, 16, 17, 19, 21, 23, 25, 28, 31, 34, 37, 41, 45, 50, 55, 60, 66, 73, 80, 88, 97, 107, 118,
    130, 143, 157, 173, 190, 209, 230, 253, 279, 307, 337, 371, 408, 449, 494, 544, 598, 658, 724, 796, 876, 963, 1060,
    1166, 1282, 1411, 1552, 1707, 1878, 2066, 2272, 2499, 2749, 3024, 3327, 3660, 4026, 4428, 4871, 5358, 5894, 6484,
    7132, 7845, 8630, 9493, 10442, 11487, 12635, 13899, 15289, 16818, 18500, 20350, 22385, 24623, 27086, 29794, 32767]
_VIMA_BITS = [4] * 45 + [5] * 14 + [6] * 17 + [7] * 13
_VIMA_MOVES = {
    4: [-1, -1, -1, -1, 1, 2, 4, 6],
    5: [-1] * 8 + [1, 1, 1, 2, 2, 4, 5, 6],
    6: [-1] * 16 + [1, 1, 1, 1, 1, 2, 2, 2, 2, 4, 4, 4, 5, 5, 6, 6],
    7: [-1] * 32 + [1] * 10 + [2] * 8 + [4] * 6 + [5] * 4 + [6] * 4,
}


def _vima_table():
    t = [0] * (64 * len(_VIMA_STEPS))
    for start in range(64):
        for i, step in enumerate(_VIMA_STEPS):
            put, count, v = 0, 32, step
            while count:
                if start & count:
                    put += v
                count >>= 1
                v >>= 1
            t[start + 64 * i] = put
    return t


_VIMA_TABLE = _vima_table()


def _vima_delta(pos, nbits, mag):
    """The change a code of magnitude `mag` makes at step index `pos` (without its sign)."""
    d = _VIMA_TABLE[(mag << (7 - nbits)) | (pos << 6)]
    if mag:
        d += _VIMA_STEPS[pos] >> (nbits - 1)
    return d


def vima(samples, pos=0):
    """One mono VIMA block of 16-bit samples: the step index and the first value (3 bytes), then the codes, most significant
    bit first. Each code is the one the decoder turns into the value nearest the sample (the encoder runs the decoder),
    with two zero bytes at the end for the decoder's read ahead."""
    out = [samples[0] if samples else 0]
    word = out[0]
    head = bytes([pos]) + struct.pack(">h", word)
    acc, nacc, data = 0, 0, bytearray()

    def put(v, n):
        nonlocal acc, nacc
        acc = (acc << n) | v
        nacc += n
        while nacc >= 8:
            nacc -= 8
            data.append((acc >> nacc) & 0xFF)
        acc &= (1 << nacc) - 1

    # (the first sample is the start value: a code of 0 keeps it)
    for i, s in enumerate(samples):
        nbits = _VIMA_BITS[pos]
        high = 1 << (nbits - 1)
        best = None
        for mag in range(high - 1):
            d = _vima_delta(pos, nbits, mag)
            for neg in (0, 1):
                w = max(-0x8000, min(0x7FFF, word - d if neg else word + d))
                if best is None or abs(w - s) < best[0]:
                    best = (abs(w - s), mag, neg, w)
        _, mag, neg, word = best
        put((high if neg else 0) | mag, nbits)
        pos = max(0, min(88, pos + _VIMA_MOVES[nbits][mag]))
    if nacc:
        put(0, 8 - nacc)
    return head + bytes(data) + b"\0\0"


def vima_decode(block, count):
    """decompressVima for one mono block (to check the encoder): `count` 16-bit samples."""
    pos, word = block[0], struct.unpack(">h", block[1:3])[0]
    src = 3
    bits = (block[src] << 8) | block[src + 1]
    src += 2
    ptr, out = 0, []
    for _ in range(count):
        nbits = _VIMA_BITS[pos]
        ptr += nbits
        high = 1 << (nbits - 1)
        low = high - 1
        val = (bits >> (16 - ptr)) & (high | low)
        if ptr > 7:
            bits = ((bits & 0xFF) << 8) | (block[src] if src < len(block) else 0)
            src += 1
            ptr -= 8
        if val & high:
            val ^= high
        else:
            high = 0
        if val == low:
            raise ValueError("an escape: the encoder writes none")
        d = _vima_delta(pos, nbits, val)
        word = max(-0x8000, min(0x7FFF, word - d if high else word + d))
        out.append(word)
        pos = max(0, min(88, pos + _VIMA_MOVES[nbits][val]))
    return out


def mcmp(head, pcm, vima_blocks=True):
    """iMUSE's compressed container (the game's .IMC and voice files): 'MCMP', the block count, then per block the codec
    (an index into the names), the decoded size and the stored size (big endian), the size of the codec names and the
    names ("NULL", "VIMA"), then the blocks. The first block is `head` stored as it is (the iMUS or RIFF header up to its
    data), then `pcm` (16-bit little-endian mono) in blocks of 8192 bytes, VIMA or, without `vima_blocks`, stored as
    they are (codec 0)."""
    blocks = [(0, len(head), head)]
    for i in range(0, len(pcm), 8192):
        part = pcm[i:i + 8192]
        if vima_blocks:
            samples = list(struct.unpack("<%dh" % (len(part) // 2), part))
            blocks.append((1, len(part), vima(samples)))
        else:
            blocks.append((0, len(part), part))
    names = b"NULL\0VIMA\0"
    table = b"".join(struct.pack(">BII", c, n, len(d)) for c, n, d in blocks)
    return b"MCMP" + struct.pack(">H", len(blocks)) + table + struct.pack(">H", len(names)) + names + b"".join(d for _, _, d in blocks)


def imus_split(data):
    """An iMUS file (`imus`) as its header, up to and with the DATA tag and size, and its sound data."""
    i = data.index(b"DATA") + 8
    return data[:i], data[i:]


def aiff(seconds, rate=22050, freq=440.0, amplitude=8000):
    """An AIFF of 16-bit mono PCM (EMI's sound effects, .aif): FORM AIFF, COMM (1 channel, the frame count, 16 bits, the
    rate as an 80-bit float), SSND (offset 0, block size 0, then the samples, big endian): a sine tone of `seconds`."""
    n = int(seconds * rate)
    frames = b"".join(struct.pack(">h", int(amplitude * math.sin(2 * math.pi * freq * i / rate))) for i in range(n))
    e = rate.bit_length() - 1
    ext = struct.pack(">HQ", 16383 + e, rate << (63 - e))
    comm = b"COMM" + struct.pack(">IHIH", 18, 1, n, 16) + ext
    ssnd = b"SSND" + struct.pack(">III", 8 + len(frames), 0, 0) + frames
    body = b"AIFF" + comm + ssnd
    return b"FORM" + struct.pack(">I", len(body)) + body


def wav_split(data):
    """A RIFF file (`wav`) as its header, up to and with the data chunk's tag and size (44 bytes), and its samples: the
    game's voices and sounds are MCMP files with that header stored and the samples in VIMA blocks."""
    i = data.index(b"data") + 8
    return data[:i], data[i:]


def lip(entries, end):
    """A lip sync file (.lip, read by iMUSE with the voice of the same name and by ScummVM's LipSync): 'LIP!', the entry
    count, then the entries, each the time it starts in 16 ms ticks and a phoneme (the IPA code point: 0x5F is silence),
    16 bits little endian. The last entry is `end`, with silence: an entry lasts until the next one starts."""
    rows = list(entries) + [(end, 0x5F)]
    return b"LIP!" + struct.pack("<i", len(rows)) + b"".join(struct.pack("<hH", t, p) for t, p in rows)


# EMI's music (ScummVM engines/grim/emi/sound/emisound.cpp, mp3track.cpp): Textures/FullMonkeyMap.imt names a file for
# each music state; the files (under Textures/spago/ and Textures/mego/) are a RIFF WAVE header of format 0x55 (MP3)
# with MP3 frames as its data, and a .jmm beside each gives its start and its loop.

def mp3_silence(seconds):
    """MPEG-1 Layer III frames of silence, mono, 44100 Hz, 128 kbit/s: each a header (FF FB 90 C0), 17 bytes of side
    information and its main data, all zero (no granule has any data: the decoder gives silence). 417 bytes and 1152
    samples a frame."""
    frame = b"\xff\xfb\x90\xc0" + bytes(417 - 4)
    return frame * max(1, int(seconds * 44100 / 1152))


def emi_music(seconds):
    """A music file of EMI's (.m4b under Textures/spago): RIFF WAVE, fmt of format 0x55 (MPEG layer 3), 1 channel,
    22050 Hz, as the game's have it, then the MP3 frames as the data chunk."""
    data = mp3_silence(seconds)
    fmt = struct.pack("<HHIIHH", 0x55, 1, 22050, 44100, 2, 16)
    body = b"WAVE" + b"fmt " + struct.pack("<I", len(fmt)) + fmt + b"data" + struct.pack("<I", len(data)) + data
    return b"RIFF" + struct.pack("<I", len(body)) + body


def jmm(start_ms, loop_end_ms=None, loop_start_ms=None):
    """The cue points of a music file (.jmm): .start in ms and, for a loop, .jump from its end back to its start."""
    out = ".start %f\r\n\r\n" % start_ms
    if loop_end_ms is not None:
        out += ".jump %f %f -1 0 0 0 0 0 \r\n" % (loop_end_ms, loop_start_ms)
    return (out + ".end -1.000000\r\n").encode("ascii")


def imt(entries):
    """EMI's music table (Textures/FullMonkeyMap.imt): between /* and */, a .cueButton (the state's id, a place on the
    composer's map, its sync group and type, state or episode) and a .playFile (trim 127 and the file, under the music
    set's folder, with a backslash) for each. entries: [(id, sync, type, file)]."""
    out = ["/*"]
    for i, sync, type_, f in entries:
        out.append('.cueButton id %d x 0 y 0 sync %d type %-7s ""' % (i, sync, type_))
        out.append('.playFile trim 127 "%s"' % f)
    out.append("*/")
    return ("\r\n".join(out) + "\r\n").encode("ascii")
