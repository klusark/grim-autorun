"""The original GRIMFANDANGO.EXE (v1.01) reads its settings from grim.ini next to the exe instead of the registry.

Reg_Open (0x4038a0, called once from Grim_OpenRegistry) becomes a loader stub for the GrimRegOpen export of patch.dll. When it runs
it loads grim.ini and overwrites the entry of the other wrapper functions (Reg_GetString, Reg_SetInt, ...) in memory with jumps into the
dll, see patches/patch/config.c. There is no fallback to the registry; tools/regtoini.py writes a grim.ini from the registry values.
"""
import struct

from ..pe import loader_stub

NEEDS_DLL = True
REG_OPEN = 0x004038A0
REG_OPEN_BYTES = bytes.fromhex("81ec88000000")   # sub esp,0x88


def apply(pe, args):
    assert pe.read(REG_OPEN, 6) == REG_OPEN_BYTES, "unexpected bytes at Reg_Open"
    stub = loader_stub(pe, b"GrimRegOpen")
    pe.write(REG_OPEN, b"\xE9" + struct.pack("<i", stub - (REG_OPEN + 5)))
