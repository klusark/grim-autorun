#!/usr/bin/env python3
"""Which files of the game's LABs were loaded by ScummVM runs (GRIM_ASSET_LOG=<file> makes the engine append the name of every file it loads for the first time).
  asset_coverage.py <log>... [--dir "C:/GOG Games/GRIMDATA"] [--list ext] [--out report.txt]
Prints, per extension, the number of files loaded and never loaded; --list ext names the ones never loaded."""
import glob
import os
import struct
import sys
from collections import defaultdict

args = sys.argv[1:]
gdir = "C:/GOG Games/GRIMDATA"
lists = []
out = None
logs = []
i = 0
while i < len(args):
    if args[i] == "--dir":
        gdir = args[i + 1]
        i += 2
    elif args[i] == "--list":
        lists.append(args[i + 1].lower())
        i += 2
    elif args[i] == "--out":
        out = args[i + 1]
        i += 2
    else:
        logs.append(args[i])
        i += 1

loaded = set()
for f in logs:
    for line in open(f, errors="ignore"):
        line = line.strip().lower()
        if line:
            loaded.add(line.rsplit("/", 1)[-1])

entries = {}
for f in sorted(glob.glob(gdir + "/*.[lL][aA][bB]")):
    d = open(f, "rb").read()
    if d[:4] != b"LABN":
        continue
    n, sz = struct.unpack("<II", d[8:16])
    strs = d[16 + n * 16:16 + n * 16 + sz]
    for k in range(n):
        no, start, size, _ = struct.unpack("<IIII", d[16 + k * 16:32 + k * 16])
        name = strs[no:strs.index(b"\0", no)].decode("latin1").lower()
        entries.setdefault(name, (os.path.basename(f).lower(), size))

by = defaultdict(lambda: [0, 0, 0, 0])
missing = defaultdict(list)
for name, (lab, size) in entries.items():
    ext = name.rsplit(".", 1)[-1] if "." in name else "(none)"
    b = by[ext]
    if name in loaded:
        b[0] += 1
        b[2] += size
    else:
        b[1] += 1
        b[3] += size
        missing[ext].append((lab, name, size))
lines = ["%-8s %7s %9s %12s %12s" % ("ext", "loaded", "never", "bytes loaded", "bytes never")]
tl = tn = 0
for ext, b in sorted(by.items(), key=lambda kv: -(kv[1][0] + kv[1][1])):
    lines.append("%-8s %7d %9d %12d %12d" % (ext, b[0], b[1], b[2], b[3]))
    tl += b[0]
    tn += b[1]
lines.append("%-8s %7d %9d" % ("total", tl, tn))
for ext in lists:
    lines.append("")
    lines.append("never loaded: " + ext)
    for lab, name, size in sorted(missing.get(ext, [])):
        lines.append("  %s %s %d" % (lab, name, size))
text = "\n".join(lines)
if out:
    open(out, "w").write(text + "\n")
print(text)
