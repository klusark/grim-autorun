#!/usr/bin/env python3
"""Builds a DATAUSR.LAB for the ORIGINAL game from ScummVM's script patches, so that the original plays the scripts ScummVM plays.

Every <file>.patchr in ScummVM's grim-patch.lab (the one embedded in the autorun build) is applied, with grim_patchr, to that file as
the game's LABs hold it. A file found in more than one LAB is tried in each until a copy matches the patch (grim_patchr checks the
checksum of the old file). The patched files are packed into a LAB (LABN, as mk_datausr.py writes it).

  python tools/mk_patchlab.py [out.lab]          (default: autorun/patchlab/DATAUSR.LAB)

env: PATCHLAB (default ~/scummvm-autorun/dists/engine-data/grim-patch.lab), GRIMDATA (default C:/GOG Games/GRIMDATA), TOOLS (the
scummvm-tools build with grim_unlab and grim_patchr; default $MSYS_HOME/scummvm-tools/build).
"""
import glob
import os
import struct
import subprocess
import sys
import tempfile

HOME = os.environ.get("MSYS_HOME", "C:/msys64/home/" + os.environ.get("USERNAME", "Joel"))
TOOLS = os.environ.get("TOOLS", os.path.join(HOME, "scummvm-tools", "build"))
GRIMDATA = os.environ.get("GRIMDATA", "C:/GOG Games/GRIMDATA")
PATCHLAB = os.environ.get("PATCHLAB", os.path.join(HOME, "scummvm-autorun", "dists", "engine-data", "grim-patch.lab"))
AR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(AR, "patchlab", "DATAUSR.LAB")


def tool(name):
    return os.path.join(TOOLS, name + ".exe")


def read_lab(path):
    """{lower-case name: (name, bytes)} of a LABN archive"""
    d = open(path, "rb").read()
    n, strsize = struct.unpack_from("<II", d, 8)
    st = 16 + n * 16
    out = {}
    for i in range(n):
        so, off, size, _ = struct.unpack_from("<IIII", d, 16 + i * 16)
        name = d[st + so:d.index(b"\0", st + so)].decode("latin-1")
        out[name.lower()] = (name, d[off:off + size])
    return out


def write_lab(files, out):
    """files: [(name, bytes)]"""
    files = sorted(files, key=lambda f: f[0].lower())
    strtab = b""
    offs = []
    for name, _ in files:
        offs.append(len(strtab))
        strtab += name.encode("latin-1") + b"\0"
    pos = 16 + 16 * len(files) + len(strtab)
    entries = b""
    body = b""
    for (name, data), o in zip(files, offs):
        entries += struct.pack("<IIII", o, pos, len(data), 0)
        body += data
        pos += len(data)
    os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
    with open(out, "wb") as f:
        f.write(b"LABN" + struct.pack("<III", 0x00010000, len(files), len(strtab)) + entries + strtab + body)


patches = read_lab(PATCHLAB)
labs = [(os.path.basename(p), read_lab(p)) for p in sorted(glob.glob(os.path.join(GRIMDATA, "DATA00[0-9].LAB")), reverse=True)]
result = []
failed = []
with tempfile.TemporaryDirectory() as tmp:
    for key, (pname, pdata) in sorted(patches.items()):
        if not key.endswith(".patchr"):
            continue
        target = key[:-len(".patchr")]
        pfile = os.path.join(tmp, "p.patchr")
        open(pfile, "wb").write(pdata)
        done = None
        tried = []
        for labname, lab in labs:
            if target not in lab:
                continue
            name, data = lab[target]
            old = os.path.join(tmp, "old")
            new = os.path.join(tmp, "new")
            open(old, "wb").write(data)
            if os.path.exists(new):
                os.remove(new)
            r = subprocess.run([tool("grim_patchr"), old, new, pfile], capture_output=True, text=True)
            tried.append(labname)
            if r.returncode == 0 and os.path.exists(new) and os.path.getsize(new) > 0:
                done = (name, open(new, "rb").read(), labname)
                break
        if done:
            result.append((done[0], done[1]))
            print("patched %-24s from %s" % (done[0], done[2]))
        else:
            failed.append(target)
            print("NOT patched %-20s (in %s)" % (target, ", ".join(tried) or "no LAB"))
write_lab(result, OUT)
print("wrote %s: %d files, %d not patched" % (OUT, len(result), len(failed)))
sys.exit(1 if failed else 0)
