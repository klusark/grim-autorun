"""Patch the original GRIMFANDANGO.EXE (v1.01, already patched with patch_debuglog.py) to run at 60 frames a second.

usage: patch_framelimit.py <exe in> <exe out>

The per frame function (0x4016a0) reads the time with a call to 0x478140. That call is sent to a stub in the
zero padding at the end of .text, which does LoadLibraryA("grimdlg.dll"), GetProcAddress("GrimFrameLimit"),
calls it (it sleeps until 1/60 s after the last frame) and then jumps to the original time function.
Without the dll the stub just jumps on. The stub reuses the "grimdlg.dll" string that patch_debuglog.py wrote.
"""
import struct
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from patch_debuglog import PE

CALL_SITE = 0x00401753
TIME_FN = 0x00478140
EXPORT = b"GrimFrameLimit\0"


def stub(cave, dll_va, fn_va, load_library, get_proc_address):
    c = bytearray()
    c += b"\x68" + struct.pack("<I", dll_va)                 # push "grimdlg.dll"
    c += b"\xFF\x15" + struct.pack("<I", load_library)       # call [LoadLibraryA]
    c += b"\x85\xC0\x74\x00"                                 # test eax,eax; jz skip
    jz1 = len(c) - 1
    c += b"\x68" + struct.pack("<I", fn_va) + b"\x50"        # push "GrimFrameLimit"; push eax
    c += b"\xFF\x15" + struct.pack("<I", get_proc_address)   # call [GetProcAddress]
    c += b"\x85\xC0\x74\x00"                                 # test eax,eax; jz skip
    jz2 = len(c) - 1
    c += b"\xFF\xD0"                                         # call eax
    skip = len(c)
    c += b"\xE9" + struct.pack("<i", TIME_FN - (cave + len(c) + 5))  # jmp the original time function
    c[jz1] = skip - (jz1 + 1)
    c[jz2] = skip - (jz2 + 1)
    return c


def main(src, dst):
    exe = PE(open(src, "rb").read())
    d = exe.d
    o = exe.off(CALL_SITE)
    assert d[o] == 0xE8 and CALL_SITE + 5 + struct.unpack_from("<i", d, o + 1)[0] == TIME_FN, "unexpected code at call site"
    load_library = exe.import_slot(b"LoadLibraryA")
    get_proc_address = exe.import_slot(b"GetProcAddress")

    dll_off = bytes(d).find(b"grimdlg.dll\0")
    assert dll_off > 0, "run patch_debuglog.py first"
    dll_va = None
    for _, vsize, rva, rawsize, rawptr in exe.secs:
        if rawptr <= dll_off < rawptr + rawsize:
            dll_va = exe.base + rva + dll_off - rawptr

    _, vsize, rva, rawsize, rawptr = exe.section(b".text")
    end = rawptr + rawsize
    start = end
    while d[start - 1] == 0:
        start -= 1
    start += 1  # keep the terminating zero of the last string
    cave = exe.base + rva + (start - rawptr)

    length = len(stub(cave, dll_va, 0, load_library, get_proc_address))
    code = stub(cave, dll_va, cave + length, load_library, get_proc_address)
    blob = bytes(code) + EXPORT
    assert start + len(blob) <= end, "code cave too small"
    d[start:start + len(blob)] = blob
    struct.pack_into("<i", d, o + 1, cave - (CALL_SITE + 5))
    open(dst, "wb").write(d)
    print("patched ->", dst, "stub at 0x%x, %d bytes" % (cave, len(blob)))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
