#!/usr/bin/env python3
"""Builds the ScummVM patches that make the elevator doors open again when they were left open.

The bug (ha.lua, hh.lua of Grim Fandango; ga.lua, lo.lua and bw.lua have it too, but the run does not need those fixed): the open function of an elevator door does nothing when the door is flagged open, but
it is Object.open that switches on the sectors of the way through (door.passage). A door that was left open by an earlier visit
keeps its way through off, and Manny is held up in front of it until he steps out of the trigger and in again. The fix calls
Object.open every time.

Each fixed function is compiled on its own (grim_luac) and spliced, as a bytecode function, into the original script of the game
(a function carries its own constants, so nothing else of the file moves). grim_diffr then makes the .patchr from the original file
to the result, and grim_mklab packs them with the patches that are in grim-patch.lab already. For ha.lua the patch that is there
already is applied first, so that it stays.

  python build_elevator_patch.py [--out DIR]

Needs scummvm-tools built in $MSYS_HOME/scummvm-tools/build (grim_unlab, grim_luac, grim_patchr, grim_diffr, grim_mklab), the game data in
C:/GOG Games/GRIMDATA and the lab as committed in the scummvm tree (override with TOOLS, GRIMDATA, PATCHLAB).
"""
import os
import shutil
import struct
import subprocess
import sys
import tempfile

# (the MSYS home, where scummvm and scummvm-tools are built; this is the Windows Python, whose ~ is C:/Users/<name>)
HOME = os.environ.get("MSYS_HOME", "C:/msys64/home/" + os.environ.get("USERNAME", "Joel"))
TOOLS = os.environ.get("TOOLS", os.path.join(HOME, "scummvm-tools", "build"))
GRIMDATA = os.environ.get("GRIMDATA", "C:/GOG Games/GRIMDATA")
PATCHLAB = os.environ.get("PATCHLAB")  # default: the lab as it is committed in the scummvm tree (git show HEAD:), so that a rerun starts from the same lab
SVM = os.path.join(HOME, "scummvm")
LABPATH = "dists/engine-data/grim-patch.lab"

# file, line the function is defined at, source of the function (an assignment, which is compiled at that line)
FIXES = [
    ("ha.lua", 807, """ha.lo_door.open = function(arg1)
    if not arg1:is_open() then
        arg1.interest_actor:wait_for_chore(ha_elvos_elev_door_door_close)
        arg1.interest_actor:stop_chore()
        arg1:play_chore(ha_elvos_elev_door_door_open)
        arg1:wait_for_chore()
    end
    Object.open(arg1)
    return TRUE
end
"""),
    ("ha.lua", 728, """ha.ga_door.open = function(arg1)
    if not arg1:is_open() then
        arg1.interest_actor:wait_for_chore(ha_elvos_garelev_door_door_close)
        arg1.interest_actor:stop_chore()
        arg1.interest_actor:play_chore(ha_elvos_garelev_door_door_open)
        arg1.interest_actor:wait_for_chore()
    end
    Object.open(arg1)
    return TRUE
end
"""),
    ("hh.lua", 151, """hh.hl_door.open = function(arg1)
    if not arg1:is_open() then
        arg1:play_chore(0)
    end
    Object.open(arg1)
end
"""),
]


def run(*args, **kw):
    r = subprocess.run([str(a) for a in args], capture_output=True, text=True, **kw)
    if r.returncode != 0:
        sys.exit("failed: %s\n%s%s" % (" ".join(map(str, args)), r.stdout, r.stderr))
    return r.stdout


def tool(name):
    return os.path.join(TOOLS, name + ".exe")


# --- the Lua 3.1 binary format (engines/grim/lua/lundump.cpp) ---

class Func:
    def __init__(self):
        self.start = self.end = self.line = 0
        self.name = ""
        self.children = []  # (slot, Func)


def word(b, p):
    return (b[p] << 8) | b[p + 1], p + 2


def tstring(b, p):
    n, p = word(b, p)
    return bytes(c ^ 0xFF for c in b[p:p + n]).decode("latin-1"), p + n


def read_func(b, p):
    f = Func()
    f.start = p
    f.line, p = word(b, p)
    f.name, p = tstring(b, p)
    size = struct.unpack(">I", b[p:p + 4])[0]
    p += 4 + size
    n, p = word(b, p)
    for _ in range(n):
        tag = chr(b[p])
        p += 1
        if tag == "N":
            p += 4
        elif tag == "S":
            _, p = tstring(b, p)
        elif tag != "F":
            sys.exit("bad constant tag %r at %d" % (tag, p))
    n, p = word(b, p)
    for _ in range(n):
        p += 2
        _, p = tstring(b, p)
    while b[p] == ord("#"):
        slot, p = word(b, p + 1)
        child = read_func(b, p)
        f.children.append((slot, child))
        p = child.end
    if b[p] != ord("$"):
        sys.exit("function does not end with $ at %d" % p)
    f.end = p + 1
    return f


def read_chunk(b):
    if b[0] != 27 or b[1:4] != b"Lua" or b[4] != 0x31:
        sys.exit("not a Lua 3.1 chunk")
    return read_func(b, 10)


def find(f, line):
    found = []
    for _, c in f.children:
        if c.line == line:
            found.append(c)
        found.extend(find(c, line))
    return found


def compile_fix(work, filename, line, source):
    """The bytecode of the function defined by source, as if it stood at the given line of Scripts\\<filename>."""
    d = tempfile.mkdtemp(dir=work)
    os.makedirs(os.path.join(d, "Scripts"))
    path = os.path.join(d, "Scripts", filename)
    with open(path, "w", newline="\n") as fh:
        fh.write("\n" * (line - 1) + source)
    run(tool("grim_luac"), "-o", os.path.join(d, "out.luac"), "Scripts\\" + filename, cwd=d)
    with open(os.path.join(d, "out.luac"), "rb") as fh:
        b = fh.read()
    main = read_chunk(b)
    if len(main.children) != 1:
        sys.exit("expected one function in the fix for %s line %d" % (filename, line))
    f = main.children[0][1]
    if f.line != line or f.name != "Scripts\\" + filename + "\0":
        sys.exit("compiled function is at %s:%d, not %s:%d" % (f.name, f.line, filename, line))
    return b[f.start:f.end]


def main():
    out = "out"
    if "--out" in sys.argv:
        out = sys.argv[sys.argv.index("--out") + 1]
    out = os.path.abspath(out)
    work = tempfile.mkdtemp()
    try:
        # the patches that are in the lab already, and the original scripts
        base_lab = PATCHLAB
        if not base_lab:
            base_lab = os.path.join(work, "base.lab")
            with open(base_lab, "wb") as fh:
                fh.write(subprocess.run(["git", "-C", SVM, "show", "HEAD:" + LABPATH], capture_output=True, check=True).stdout)
        patches = os.path.join(work, "patches")
        os.makedirs(patches)
        run(tool("grim_unlab"), base_lab, cwd=patches)
        orig = os.path.join(work, "orig")
        os.makedirs(orig)
        for lab in ("DATA000", "DATA001", "DATA002", "DATA003", "DATA004", "DATA005"):
            run(tool("grim_unlab"), os.path.join(GRIMDATA, lab + ".LAB"), cwd=orig)

        for filename in sorted(set(f[0] for f in FIXES)):
            old = os.path.join(orig, filename)
            base = old
            existing = os.path.join(patches, filename + ".patchr")
            if os.path.exists(existing):
                base = os.path.join(work, "base_" + filename)
                run(tool("grim_patchr"), old, base, existing)
                print("%s: keeping the patch that is in the lab" % filename)
            with open(base, "rb") as fh:
                data = fh.read()
            # from the end of the file to its start, so that the offsets of the others stay as they were
            todo = []
            main_f = read_chunk(data)
            for fname, line, source in FIXES:
                if fname != filename:
                    continue
                hits = find(main_f, line)
                if len(hits) != 1:
                    sys.exit("%s: %d functions at line %d" % (filename, len(hits), line))
                todo.append((hits[0], compile_fix(work, filename, line, source)))
            todo.sort(key=lambda t: -t[0].start)
            for f, new in todo:
                print("%s: line %d, %d bytes -> %d bytes" % (filename, f.line, f.end - f.start, len(new)))
                data = data[:f.start] + new + data[f.end:]
            read_chunk(data)  # still well formed
            new_path = os.path.join(work, "new_" + filename)
            with open(new_path, "wb") as fh:
                fh.write(data)
            run(tool("grim_diffr"), old, new_path, os.path.join(patches, filename + ".patchr"))
            # (the patch must give back what was built)
            check = os.path.join(work, "check_" + filename)
            run(tool("grim_patchr"), old, check, os.path.join(patches, filename + ".patchr"))
            if open(check, "rb").read() != data:
                sys.exit("%s: the patch does not give back the fixed script" % filename)
            print("%s: patch %d bytes" % (filename, os.path.getsize(os.path.join(patches, filename + ".patchr"))))

        os.makedirs(out, exist_ok=True)
        shutil.copy(base_lab, os.path.join(out, "grim-patch.lab.orig"))
        lab = os.path.join(out, "grim-patch.lab")
        if os.path.exists(lab):
            os.remove(lab)
        run(tool("grim_mklab"), "--grim", patches, lab)
        for filename in sorted(set(f[0] for f in FIXES)):
            shutil.copy(os.path.join(patches, filename + ".patchr"), out)
        print("wrote", lab)
    finally:
        shutil.rmtree(work, ignore_errors=True)


if __name__ == "__main__":
    main()
