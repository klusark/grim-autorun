"""Patch the original GRIMFANDANGO.EXE (v1.01) so PrintDebug/PrintWarning/PrintError log to a file.

usage: patch_debuglog.py <GRIMFANDANGO.EXE in> <patched exe out>

The retail executable registers all three Lua builtins with one function that does nothing.
Changes (all reversible by restoring the original exe):
  * The function pointers of the three builtins in the Lua function table (.data) are pointed
    at three stubs, so each level gets its own logging function.
  * The stubs are written into the zero padding at the end of .text. Each one does
    LoadLibraryA("grimdlg.dll"), GetProcAddress("GrimLogDebug" / "GrimLogWarning" /
    "GrimLogError") and jumps to it. If the dll or the export is missing the builtin simply
    returns, as the original did.
grimdlg.dll must be next to the executable. Messages are appended to grimdebug.log in the
same folder.
"""
import struct
import sys

IMAGE_BASE = 0x400000
NOOP_BUILTIN = 0x0049DDD0
# address of the function pointer in the table, and the export it gets sent to
SLOTS = (
    (0x004EAB8C, b"GrimLogError\0"),    # PrintError
    (0x004EAB94, b"GrimLogWarning\0"),  # PrintWarning
    (0x004EAB9C, b"GrimLogDebug\0"),    # PrintDebug
)
DLL_NAME = b"grimdlg.dll\0"
STUB_LEN = 36


class PE:
    def __init__(self, data):
        self.d = bytearray(data)
        self.pe = struct.unpack_from("<I", self.d, 0x3C)[0]
        nsec = struct.unpack_from("<H", self.d, self.pe + 6)[0]
        optsz = struct.unpack_from("<H", self.d, self.pe + 20)[0]
        self.base = struct.unpack_from("<I", self.d, self.pe + 24 + 28)[0]
        assert self.base == IMAGE_BASE
        sec = self.pe + 24 + optsz
        self.secs = [struct.unpack_from("<8sIIII", self.d, sec + i * 40) for i in range(nsec)]

    def off(self, va):
        for name, vsize, rva, rawsize, rawptr in self.secs:
            if self.base + rva <= va < self.base + rva + rawsize:
                return rawptr + va - self.base - rva
        raise ValueError(hex(va))

    def section(self, name):
        for s in self.secs:
            if s[0].rstrip(b"\0") == name:
                return s
        raise KeyError(name)

    def import_slot(self, func):
        """virtual address of the IAT entry that imports func by name"""
        d = self.d
        impdir = struct.unpack_from("<II", d, self.pe + 24 + 96 + 8)[0]
        o = self.off(self.base + impdir)
        while True:
            oft, _, _, name_rva, ft = struct.unpack_from("<IIIII", d, o)
            if name_rva == 0:
                break
            t = self.off(self.base + (oft or ft))
            i = 0
            while True:
                thunk = struct.unpack_from("<I", d, t + i * 4)[0]
                if thunk == 0:
                    break
                if not thunk & 0x80000000 and d[self.off(self.base + thunk) + 2:].split(b"\0")[0] == func:
                    return self.base + ft + i * 4
                i += 1
            o += 20
        raise KeyError(func)


def stub(va, dll_va, fn_va, load_library, get_proc_address):
    code = bytearray()
    code += b"\x68" + struct.pack("<I", dll_va)                  # push "grimdlg.dll"
    code += b"\xFF\x15" + struct.pack("<I", load_library)        # call [LoadLibraryA]
    code += b"\x85\xC0"                                          # test eax,eax
    code += b"\x74\x00"                                          # jz fail
    jz1 = len(code) - 1
    code += b"\x68" + struct.pack("<I", fn_va)                   # push export name
    code += b"\x50"                                              # push eax
    code += b"\xFF\x15" + struct.pack("<I", get_proc_address)    # call [GetProcAddress]
    code += b"\x85\xC0"                                          # test eax,eax
    code += b"\x74\x00"                                          # jz fail
    jz2 = len(code) - 1
    code += b"\xFF\xE0"                                          # jmp eax, the export returns to the caller
    fail = len(code)
    code += b"\x33\xC0\xC3"                                      # xor eax,eax; ret
    code[jz1] = fail - (jz1 + 1)
    code[jz2] = fail - (jz2 + 1)
    assert len(code) == STUB_LEN, len(code)
    return code


def main(src, dst):
    exe = PE(open(src, "rb").read())
    d = exe.d

    # all three builtins must still be the shared no-op
    for slot, _ in SLOTS:
        assert struct.unpack_from("<I", d, exe.off(slot))[0] == NOOP_BUILTIN, "unexpected builtin at " + hex(slot)

    load_library = exe.import_slot(b"LoadLibraryA")
    get_proc_address = exe.import_slot(b"GetProcAddress")

    # find the zero padding at the end of .text
    _, vsize, rva, rawsize, rawptr = exe.section(b".text")
    end = rawptr + rawsize
    start = end
    while d[start - 1] == 0:
        start -= 1
    start = (start + 15) & ~15
    cave = exe.base + rva + (start - rawptr)

    size = STUB_LEN * len(SLOTS) + len(DLL_NAME) + sum(len(n) for _, n in SLOTS)
    assert start + size <= end, "code cave too small (%d > %d)" % (size, end - start)

    # the strings follow the stubs: the dll name, then the export names
    strings_off = start + STUB_LEN * len(SLOTS)
    dll_va = cave + STUB_LEN * len(SLOTS)
    strings = bytearray(DLL_NAME)
    names_va = {}
    for slot, name in SLOTS:
        names_va[slot] = dll_va + len(strings)
        strings += name
    d[strings_off:strings_off + len(strings)] = strings

    for i, (slot, _) in enumerate(SLOTS):
        stub_va = cave + i * STUB_LEN
        d[start + i * STUB_LEN:start + (i + 1) * STUB_LEN] = stub(stub_va, dll_va, names_va[slot], load_library, get_proc_address)
        struct.pack_into("<I", d, exe.off(slot), stub_va)

    open(dst, "wb").write(d)
    print("patched ->", dst)
    print("stubs at 0x%x..0x%x, LoadLibraryA 0x%x, GetProcAddress 0x%x" % (cave, cave + size, load_library, get_proc_address))


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(__doc__)
        sys.exit(1)
    main(sys.argv[1], sys.argv[2])
