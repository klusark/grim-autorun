"""The original GRIMFANDANGO.EXE (v1.01) runs at 60 frames a second.

The per frame function (0x4016a0) reads the time with a call to 0x478140. That call is sent to a stub in the
zero padding at the end of .text, which does LoadLibraryA("patch.dll"), GetProcAddress("GrimFrameLimit"),
calls it (it sleeps until 1/60 s after the last frame) and then jumps to the original time function.
Without the dll the stub just jumps on.
"""
import struct

from ..pe import loader_stub

NEEDS_DLL = True
CALL_SITE = 0x00401753
TIME_FN = 0x00478140


def apply(pe, args):
    o = pe.read(CALL_SITE, 5)
    assert o[0] == 0xE8 and CALL_SITE + 5 + struct.unpack_from("<i", o, 1)[0] == TIME_FN, "unexpected code at call site"
    stub = loader_stub(pe, b"GrimFrameLimit", then=TIME_FN)
    pe.write(CALL_SITE + 1, struct.pack("<i", stub - (CALL_SITE + 5)))
