"""Lists or extracts members of LAB archives (for reference only: nothing read from the game's LABs goes into the clean-room data).
   labls.py <lab> [member [out]]   no member: list; member without out: hex dump of its first 256 bytes"""
import struct, sys


def read_lab(path):
    d = open(path, "rb").read()
    assert d[:4] == b"LABN", path
    n, sl = struct.unpack("<II", d[8:16])
    st = 16 + 16 * n
    names = d[st:st + sl]
    out = {}
    for i in range(n):
        no, off, size, _ = struct.unpack("<IIII", d[16 + 16 * i:32 + 16 * i])
        name = names[no:names.index(b"\0", no)].decode("latin-1")
        out[name.lower()] = (off, size)
    return d, out


if __name__ == "__main__":
    d, m = read_lab(sys.argv[1])
    if len(sys.argv) == 2:
        for k, (o, s) in sorted(m.items()):
            print(k, s)
    else:
        o, s = m[sys.argv[2].lower()]
        b = d[o:o + s]
        if len(sys.argv) > 3:
            open(sys.argv[3], "wb").write(b)
        else:
            for i in range(0, min(256, len(b)), 16):
                print("%04x " % i + " ".join("%02x" % c for c in b[i:i + 16]))
