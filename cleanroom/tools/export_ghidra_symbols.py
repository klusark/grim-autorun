"""Writes the function names of the Ghidra project's exes to tools/symbols/<game>.txt, where crashstack.py reads them.

  python export_ghidra_symbols.py [--url http://127.0.0.1:8089] [NAME=/ghidra/path ...]

Ghidra has to be running with the project open (the MCP plug-in's local HTTP server, read-only list_functions_enhanced). Run it
again after renaming functions in Ghidra. Each line of a file: <rva hex> <t|f> <name>  (rva: address minus the image base; t: a
thunk, which is taken to be 6 bytes long; f: a function, which ends where the next one starts). Default exes:

  remastered = /remastered/GrimFandango.exe   (the Windows Remastered)
  grim       = /v101/GRIMFANDANGO.EXE         (the original v1.01)
  emi        = /emi/Monkey4.exe               (Escape from Monkey Island)
(named by game: GrimFandango.exe and GRIMFANDANGO.EXE are the same file name on Windows)"""
import json
import os
import sys
import urllib.parse
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "symbols")
DEFAULTS = {
    "remastered": "/remastered/GrimFandango.exe",
    "grim": "/v101/GRIMFANDANGO.EXE",
    "emi": "/emi/Monkey4.exe",
}


def get(url, path, **params):
    with urllib.request.urlopen("%s/%s?%s" % (url, path, urllib.parse.urlencode(params)), timeout=120) as r:
        return r.read().decode("utf-8", "replace")


def export(url, name, ghidra_path):
    text = get(url, "list_functions_enhanced", program=ghidra_path, limit=1000000)
    funcs = json.loads(text)["functions"]
    base = IMAGE_BASE
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name + ".txt")
    rows = sorted((int(f["address"], 16) - base, "t" if f.get("isThunk") else "f", f["name"]) for f in funcs if not f.get("isExternal"))
    with open(path, "w", newline="\n") as f:
        f.write("# %s (Ghidra %s), image base 0x%x: <rva> <t|f> <name>; written by export_ghidra_symbols.py\n" % (name, ghidra_path, base))
        for rva, kind, fn in rows:
            f.write("%x %s %s\n" % (rva, kind, fn))
    print("%s: %d functions -> %s" % (name, len(rows), path))


IMAGE_BASE = 0x400000   # (all three exes are linked for it)


def main(argv):
    url = "http://127.0.0.1:8089"
    if "--url" in argv:
        i = argv.index("--url")
        url = argv[i + 1]
        del argv[i:i + 2]
    exes = dict(a.split("=", 1) for a in argv) if argv else DEFAULTS
    for name, path in exes.items():
        export(url, name, path)


if __name__ == "__main__":
    main(sys.argv[1:])
