"""The data of emi_rnd.lua (EMI's drawing): the box mesh on a texture drawn additively with its face alpha-blended, and a
sprite drawn additively without the alpha and depth tests."""
import struct

import formats as F
import assets_emi as E


def _replace_once(data, old, new):
    assert data.count(old) == 1, old
    return data.replace(old, new)


def mesh_flags(name, texture, tex_flags, face_flags):
    """formats.meshb's textured box (cr_etex) with the flags of its texture (0x400: additive, modelemi.h BlendAdditive)
    and of its face (0x304 the game's; 0x10000 alpha blend, 0x20 no lighting) set."""
    m = F.meshb(name, E.EBOX_VERTS, E.EBOX_TRIS, bones=[("root", [0, 1, 2, 3]), ("body", [4, 5, 6, 7])], texture=texture,
                textured=True)
    tex = struct.pack("<I", len(texture) + 1) + texture.encode("ascii") + b"\0"
    m = _replace_once(m, tex + struct.pack("<I", 0), tex + struct.pack("<I", tex_flags))
    return _replace_once(m, struct.pack("<II", 0x304, 1), struct.pack("<II", face_flags, 1))


def sprite_flags(name, texture, width, height, pos, flags1, flags2, colour=(255, 255, 255, 255)):
    """formats.sprb with its two flag words given (sprite.h: flags1 0x400 additive; flags2 0x100 depth test, 0x20000
    alpha test)."""
    s = F.sprb(name, texture, width, height, pos, colour)
    s = _replace_once(s, struct.pack("<I2f", 903, width, height), struct.pack("<I2f", flags1, width, height))
    assert s.endswith(struct.pack("<I", 131844))
    return s[:-4] + struct.pack("<I", flags2)


def files():
    out = {}
    out["rnd_add.meshb"] = mesh_flags("rnd_add", "cr_tex.tga", 0x400, 0x304 | 0x10000)
    out["rnd_nolit.meshb"] = mesh_flags("rnd_nolit", "cr_tex.tga", 0, 0x304 | 0x20 | 0x40000)
    out["rnd_add.sprb"] = sprite_flags("rnd_add.spr", "cr_tex.tga", 0.5, 0.5, (0.0, 1.0, 0.0), 903 | 0x400, 0)
    skel = ("!skelcr_ebox.skl", 0, -1, [(0.0, 1)])
    out["rnd_add.cosb"] = F.cosb([
        ("wear_default", 1000.0, [skel, ("!meshrnd_add.mesh", 1, -1, [(0.0, 1)])]),
    ])
    out["rnd_nolit.cosb"] = F.cosb([
        ("wear_default", 1000.0, [skel, ("!meshrnd_nolit.mesh", 1, -1, [(0.0, 1)])]),
    ])
    out["rnd_spr.cosb"] = F.cosb([
        ("wear_default", 1000.0, [skel, ("!meshcr_ebox.mesh", 1, -1, [(0.0, 1)]), ("!sprtrnd_add.spr", 0, -1, [(0.0, 1)])]),
    ])
    return out
