"""Reads a binary .3do (LDOM) and prints its structure, to check the layout formats.model3do writes.
   read3do.py <file.3do> | <lab> <member>
The layout is the one ScummVM's Model::loadBinary / Mesh::loadBinary / ModelNode::loadBinary read."""
import struct
import sys


class R:
    def __init__(self, d):
        self.d, self.p = d, 0

    def u(self, n=1):
        v = struct.unpack_from("<%dI" % n, self.d, self.p)
        self.p += 4 * n
        return v if n > 1 else v[0]

    def i(self):
        v = struct.unpack_from("<i", self.d, self.p)[0]
        self.p += 4
        return v

    def f(self, n=1):
        v = struct.unpack_from("<%df" % n, self.d, self.p)
        self.p += 4 * n
        return v if n > 1 else v[0]

    def s(self, n):
        v = self.d[self.p:self.p + n].split(b"\0")[0].decode("latin-1")
        self.p += n
        return v

    def skip(self, n):
        self.p += n


def read(d):
    r = R(d)
    assert d[:4] == b"LDOM", d[:4]
    r.skip(4)
    nmat = r.u()
    mats = [r.s(32) for _ in range(nmat)]
    name = r.s(32)
    r.skip(4)
    ngeo = r.u()
    print("materials", mats, "name", name, "geosets", ngeo)
    for g in range(ngeo):
        nmesh = r.u()
        for m in range(nmesh):
            mname = r.s(32)
            r.skip(4)
            geo, light, tex, nv, ntv, nf = r.u(6)
            verts = r.f(3 * nv) if nv else ()
            r.f(2 * ntv) if ntv else ()
            r.f(nv) if nv else ()
            r.skip(4 * nv)
            print("  mesh %s modes %d %d %d verts %d texverts %d faces %d first vert %s" % (mname, geo, light, tex, nv, ntv, nf, verts[:3]))
            for _ in range(nf):
                read_face(r)
            r.f(3 * nv) if nv else ()
            shadow = r.u()
            r.skip(4)
            radius = r.f()
            r.skip(24)
            print("    shadow %d radius %g" % (shadow, radius))
    r.skip(4)
    nnodes = r.u()
    for n in range(nnodes):
        nname = r.s(64)
        flags = r.u()
        r.skip(4)
        typ = r.u()
        mesh = r.i()
        depth = r.u()
        parent = r.u()
        nchild = r.u()
        child = r.u()
        sibling = r.u()
        pivot = r.f(3)
        pos = r.f(3)
        rot = r.f(3)
        r.skip(48)
        links = []
        for ptr in (parent, child, sibling):
            links.append(r.u() if ptr else None)
        print("  node %s flags %x type %x mesh %d depth %d children %d links %s pivot %s pos %s rot %s" % (
            nname, flags, typ, mesh, depth, nchild, links, pivot, pos, rot))
    radius = r.f()
    bmin, bmax, centre, ins = r.f(3), r.f(3), r.f(3), r.f(3)
    print("radius %g bbox %s %s centre %s insert %s; read %d of %d bytes" % (radius, bmin, bmax, centre, ins, r.p, len(d)))


def read_face(r):
    # (MeshFace::loadBinary: see formats.py; only needed to step over the faces of a real file)
    r.skip(4)
    typ, geo, light, tex, nverts = r.u(5)
    r.skip(4)
    texptr, matptr = r.u(2)
    r.skip(12)
    extralight = r.f()
    r.skip(12)
    r.f(3)
    r.skip(4 * nverts)
    if texptr:
        r.skip(4 * nverts)
    if matptr:
        r.skip(4)


if __name__ == "__main__":
    if len(sys.argv) == 3:
        sys.path.insert(0, __file__.rsplit("\\", 1)[0].rsplit("/", 1)[0])
        import labls
        data, members = labls.read_lab(sys.argv[1])
        o, s = members[sys.argv[2].lower()]
        read(data[o:o + s])
    else:
        read(open(sys.argv[1], "rb").read())
