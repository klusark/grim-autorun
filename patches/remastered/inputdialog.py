"""Grim Fandango Remastered: the stubbed InputDialog helper loads patch.dll.

Changes (all reversible by restoring the original exe):
  * 0x00428580 (the stubbed 'mov eax,1; ret') becomes a jmp to a loader stub.
  * The stub is written into the zero padding at the end of .text:
    LoadLibraryA("patch.dll"), GetProcAddress("InputDialogStub"), tail-jump.
    It returns 0 (-> InputDialog returns nil) if the dll or export is missing.
  * ASLR (DYNAMICBASE) is cleared so the absolute IAT addresses stay valid.
"""
import struct

from ..pe import loader_stub

NEEDS_DLL = True
TARGET = 0x00428580


def apply(pe, args):
    # sanity: the function we replace must still be the original stub
    assert pe.read(TARGET, 6) == bytes.fromhex("b801000000c3"), "unexpected bytes at InputDialog stub"
    stub = loader_stub(pe, b"InputDialogStub")
    pe.write(TARGET, b"\xE9" + struct.pack("<i", stub - (TARGET + 5)))   # jmp rel32 into the cave

    # clear IMAGE_DLLCHARACTERISTICS_DYNAMIC_BASE
    ch = pe.pe + 24 + 70
    chars = struct.unpack_from("<H", pe.d, ch)[0]
    struct.pack_into("<H", pe.d, ch, chars & ~0x0040)
