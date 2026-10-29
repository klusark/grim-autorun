# Prints the bytes of the two guard functions of IMUSE.DLL (RVA 0x4f50 / 0x4f60) and the relocation entries of the page 0x4000.
# usage: imuse_inspect.py [path to IMUSE.DLL]
import struct, sys

path = sys.argv[1] if len(sys.argv) > 1 else r"C:\GOG Games\GRIMDATA\IMUSE.DLL"
d = open(path, "rb").read()
pe = struct.unpack_from("<I", d, 0x3C)[0]
assert d[pe:pe + 4] == b"PE\0\0"
nsec = struct.unpack_from("<H", d, pe + 6)[0]
optsz = struct.unpack_from("<H", d, pe + 20)[0]
opt = pe + 24
image_base = struct.unpack_from("<I", d, opt + 28)[0]
reloc_rva, reloc_size = struct.unpack_from("<II", d, opt + 96 + 5 * 8)
secs = []
for i in range(nsec):
    o = opt + optsz + 40 * i
    name = d[o:o + 8].rstrip(b"\0").decode()
    vsize, rva, rawsize, rawptr = struct.unpack_from("<IIII", d, o + 8)
    secs.append((name, rva, vsize, rawptr, rawsize))
    print(f"section {name:8s} rva {rva:#8x} vsize {vsize:#8x} raw {rawptr:#8x} rawsize {rawsize:#8x}")
print(f"image base {image_base:#x}, reloc dir rva {reloc_rva:#x} size {reloc_size:#x}")


def off(rva):
    for name, r, vs, rp, rs in secs:
        if r <= rva < r + max(vs, rs):
            return rp + rva - r
    raise ValueError(hex(rva))


for rva, n in ((0x4f40, 0x40),):
    o = off(rva)
    print(f"bytes at rva {rva:#x} (file {o:#x}):")
    for i in range(0, n, 16):
        print("  %05x  %s" % (rva + i, d[o + i:o + i + 16].hex(" ")))
ro = off(reloc_rva)
p = 0
while p < reloc_size:
    page, bsz = struct.unpack_from("<II", d, ro + p)
    if bsz == 0:
        break
    if page == 0x4000:
        ents = struct.unpack_from("<%dH" % ((bsz - 8) // 2), d, ro + p + 8)
        print(f"reloc block page {page:#x} at file {ro + p:#x}, {len(ents)} entries; those in 0xf40..0xf80:")
        for k, e in enumerate(ents):
            if 0xf40 <= (e & 0xfff) < 0xf80:
                print(f"  entry {k} type {e >> 12} offset {e & 0xfff:#x}  (file offset of the entry {ro + p + 8 + 2 * k:#x})")
    p += bsz
