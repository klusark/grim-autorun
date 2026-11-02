"""Minimal PE editor shared by the patches: virtual-address access, the code cave at the end of .text and the patch.dll loader stub."""
import struct

DLL_NAME = b"patch.dll"


class PE:
    def __init__(self, data):
        self.d = bytearray(data)
        self.pe = struct.unpack_from("<I", self.d, 0x3C)[0]
        nsec = struct.unpack_from("<H", self.d, self.pe + 6)[0]
        optsz = struct.unpack_from("<H", self.d, self.pe + 20)[0]
        self.base = struct.unpack_from("<I", self.d, self.pe + 24 + 28)[0]
        assert self.base == 0x400000
        self.sec_hdr = self.pe + 24 + optsz
        self.secs = [struct.unpack_from("<8sIIII", self.d, self.sec_hdr + i * 40) for i in range(nsec)]
        self._cave = None

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

    def read(self, va, n):
        o = self.off(va)
        return bytes(self.d[o:o + n])

    def write(self, va, data):
        o = self.off(va)
        self.d[o:o + len(data)] = data

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

    def extend_text_vsize(self):
        """map the whole raw size of .text, so a loader that maps only VirtualSize still has the cave"""
        i = [s[0].rstrip(b"\0") for s in self.secs].index(b".text")
        struct.pack_into("<I", self.d, self.sec_hdr + i * 40 + 8, self.secs[i][3])

    # -- the zero padding at the end of .text, handed out front to back so several patches share it --

    def alloc(self, size, align=16):
        """reserve size bytes in the cave, return their virtual address (the patch writes them with write())"""
        _, vsize, rva, rawsize, rawptr = self.section(b".text")
        end = rawptr + rawsize
        if self._cave is None:
            start = end
            while self.d[start - 1] == 0:
                start -= 1
            self._cave = start + 1  # keep the terminating zero of the last string
        start = (self._cave + align - 1) & ~(align - 1)
        assert start + size <= end, "code cave too small (%d > %d)" % (size, end - start)
        self._cave = start + size
        return self.base + rva + (start - rawptr)

    def cstring(self, s):
        """virtual address of the NUL-terminated string s: one already in .text (written by an earlier patch) or a new one"""
        _, vsize, rva, rawsize, rawptr = self.section(b".text")
        o = bytes(self.d[rawptr:rawptr + rawsize]).find(s + b"\0")
        if o >= 0:
            return self.base + rva + o
        va = self.alloc(len(s) + 1, 1)
        self.write(va, s + b"\0")
        return va


def loader_stub(pe, export, then=None):
    """code that does LoadLibraryA(patch.dll), GetProcAddress(export) and

    then=None:  jumps to the export, which returns to the caller (an export that is missing makes the function return 0)
    then=<va>:  calls the export, then jumps to va (a missing export is skipped)
    Returns the virtual address of the stub."""
    dll_va = pe.cstring(DLL_NAME)
    fn_va = pe.cstring(export)
    load_library = pe.import_slot(b"LoadLibraryA")
    get_proc_address = pe.import_slot(b"GetProcAddress")

    def build(va):
        c = bytearray()
        c += b"\x68" + struct.pack("<I", dll_va)                  # push "patch.dll"
        c += b"\xFF\x15" + struct.pack("<I", load_library)        # call [LoadLibraryA]
        c += b"\x85\xC0\x74\x00"                                  # test eax,eax; jz fail
        jz1 = len(c) - 1
        c += b"\x68" + struct.pack("<I", fn_va) + b"\x50"         # push export name; push eax
        c += b"\xFF\x15" + struct.pack("<I", get_proc_address)    # call [GetProcAddress]
        c += b"\x85\xC0\x74\x00"                                  # test eax,eax; jz fail
        jz2 = len(c) - 1
        if then is None:
            c += b"\xFF\xE0"                                      # jmp eax
            fail = len(c)
            c += b"\x33\xC0\xC3"                                  # xor eax,eax; ret
        else:
            c += b"\xFF\xD0"                                      # call eax
            fail = len(c)
            c += b"\xE9" + struct.pack("<i", then - (va + len(c) + 5))  # jmp then
        c[jz1] = fail - (jz1 + 1)
        c[jz2] = fail - (jz2 + 1)
        return c

    size = len(build(0))
    va = pe.alloc(size, 1)
    pe.write(va, build(va))
    return va
