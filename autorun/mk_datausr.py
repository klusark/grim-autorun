"""Packs the files of a directory into a LAB archive (LABN): mk_datausr.py <dir> <out.lab>"""
import os
import struct
import sys

src, out = sys.argv[1], sys.argv[2]
names = sorted(os.listdir(src))
strtab = b""
offs = []
for n in names:
    offs.append(len(strtab))
    strtab += n.encode("ascii") + b"\0"
data_start = 16 + 16 * len(names) + len(strtab)
entries = b""
body = b""
pos = data_start
for n, o in zip(names, offs):
    d = open(os.path.join(src, n), "rb").read()
    entries += struct.pack("<IIII", o, pos, len(d), 0)
    body += d
    pos += len(d)
hdr = b"LABN" + struct.pack("<III", 0x00010000, len(names), len(strtab))
open(out, "wb").write(hdr + entries + strtab + body)
print("wrote", out, len(names), "files")
