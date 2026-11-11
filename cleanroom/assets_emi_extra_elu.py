"""The data of emi_elu.lua (EMI's Lua builtins): a .til of three layers (frames), for NewLayer's frames and as the background of
a set of its own (the layers of a background are drawn between the actors by their sort order)."""
import gzip
import struct

import assets as A
import assets_emi as E
import formats as F


def elu_til_layers(layers):
    """A .til of 256 x 256 whose layers are one tile each (formats.til writes one layer): layers is a list of (r, g, b)
    colours, one a layer. Layer i is polygon i, which is tile i on the whole screen."""
    T = 256
    coords, polys, tiles = [], [], []
    for i, rgb in enumerate(layers):
        polys.append((i, len(coords), 4))
        coords += [(-1.0, 1.0, 0.0, 0.0), (1.0, 1.0, 1.0, 0.0), (1.0, -1.0, 1.0, 1.0), (-1.0, -1.0, 0.0, 1.0)]
        r, g, b = rgb
        tiles.append(bytes((255, b, g, r)) * (T * T))
    head = b"TIL0" + struct.pack("<IIII", 0, len(coords), len(layers), len(polys)) + b"\0" * 16
    body = b"".join(struct.pack("<4f", *c) for c in coords)
    body += b"".join(struct.pack("<II", i, 1) for i in range(len(layers)))
    body += b"".join(struct.pack("<III", *p) for p in polys)
    bmoff = len(head) + len(body)
    head = head[:4] + struct.pack("<I", bmoff) + head[8:]
    bm = bytearray(128)
    bm[0:5] = b"BM  F"
    struct.pack_into("<I", bm, 16, len(tiles))
    struct.pack_into("<IIIIIIII", bm, 32, 2, 32, 8, 8, 8, 24, 16, 8)
    data = head + body + bytes(bm) + b"".join(struct.pack("<II", T, T) + t for t in tiles)
    return gzip.compress(data, mtime=0)


def files():
    out = {}
    out["elu_frames.til"] = elu_til_layers([(40, 40, 40), (60, 60, 60), (80, 80, 80)])
    out["elu_layers.setb"] = F.set_binary([dict(E.CAMERA, name="elu_layers_0", background="elu_frames.til")], [E.LIGHT],
                                          E.emi_sectors(A.SETS["cr_flat"][1]))
    return out
