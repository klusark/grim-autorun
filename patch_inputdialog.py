"""Patch Grim Fandango Remastered so the stubbed InputDialog helper loads grimdlg.dll.

usage: patch_inputdialog.py <GrimFandango.exe in> <patched exe out>

Changes (all reversible by restoring the original exe):
  * 0x00428580 (the stubbed 'mov eax,1; ret') becomes a jmp to a loader stub.
  * The stub is written into the zero padding at the end of .text (0x00570e10):
    LoadLibraryA("grimdlg.dll"), GetProcAddress("InputDialogStub"), tail-jump.
    It returns 0 (-> InputDialog returns nil) if the dll or export is missing.
  * ASLR (DYNAMICBASE) is cleared so the absolute IAT addresses stay valid.
"""
import struct
import sys

IMAGE_BASE = 0x400000
TARGET = 0x00428580
CAVE = 0x00570E10
IAT_LOADLIBRARYA = 0x005710F8
IAT_GETPROCADDRESS = 0x00571034


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


def main(src, dst):
    exe = PE(open(src, "rb").read())
    d = exe.d

    # sanity: the function we replace must still be the original stub
    t = exe.off(TARGET)
    assert d[t:t + 6] == bytes.fromhex("b801000000c3"), "unexpected bytes at InputDialog stub"
    c = exe.off(CAVE)
    assert all(b == 0 for b in d[c:c + 128]), "code cave is not empty"
    for iat, name in ((IAT_LOADLIBRARYA, b"LoadLibraryA"), (IAT_GETPROCADDRESS, b"GetProcAddress")):
        rva = struct.unpack_from("<I", d, exe.off(iat))[0]
        assert d[exe.off(IMAGE_BASE + rva) + 2:][:len(name) + 1] == name + b"\0", "unexpected IAT entry for " + name.decode()

    dll_str = b"grimdlg.dll\0"
    fn_str = b"InputDialogStub\0"
    code_len = 36
    dll_va = CAVE + code_len
    fn_va = dll_va + len(dll_str)

    code = bytearray()
    code += b"\x68" + struct.pack("<I", dll_va)              # push "grimdlg.dll"
    code += b"\xFF\x15" + struct.pack("<I", IAT_LOADLIBRARYA)  # call [LoadLibraryA]
    code += b"\x85\xC0"                                       # test eax,eax
    code += b"\x74\x00"                                       # jz fail (patched below)
    jz1 = len(code) - 1
    code += b"\x68" + struct.pack("<I", fn_va)                # push "InputDialogStub"
    code += b"\x50"                                           # push eax
    code += b"\xFF\x15" + struct.pack("<I", IAT_GETPROCADDRESS)  # call [GetProcAddress]
    code += b"\x85\xC0"                                       # test eax,eax
    code += b"\x74\x00"                                       # jz fail
    jz2 = len(code) - 1
    code += b"\xFF\xE0"                                       # jmp eax (cdecl args untouched)
    fail = len(code)
    code += b"\x33\xC0\xC3"                                   # xor eax,eax; ret
    code[jz1] = fail - (jz1 + 1)
    code[jz2] = fail - (jz2 + 1)
    assert len(code) == code_len, len(code)

    d[c:c + len(code)] = code
    d[c + code_len:c + code_len + len(dll_str)] = dll_str
    d[c + code_len + len(dll_str):c + code_len + len(dll_str) + len(fn_str)] = fn_str

    # jmp rel32 from the stub into the cave
    rel = CAVE - (TARGET + 5)
    d[t:t + 5] = b"\xE9" + struct.pack("<i", rel)

    # clear IMAGE_DLLCHARACTERISTICS_DYNAMIC_BASE
    ch = exe.pe + 24 + 70
    chars = struct.unpack_from("<H", d, ch)[0]
    struct.pack_into("<H", d, ch, chars & ~0x0040)

    open(dst, "wb").write(d)
    print("patched ->", dst)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(__doc__)
        sys.exit(1)
    main(sys.argv[1], sys.argv[2])
