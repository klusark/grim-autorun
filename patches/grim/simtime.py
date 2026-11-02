"""Fixed frame time for the original GRIMFANDANGO.EXE (v1.01).

The per frame function FUN_004016a0 reads the one-shot global DAT_004f5a48 ("fixed frame time") at 0x401721 and passes it to FUN_00482990, which
runs the fixed step FUN_004a3c80(ms) when it is not zero and the wall clock FUN_004a3c10 when it is. The load at 0x401721 (mov eax,[0x4f5a48],
5 bytes) becomes mov eax,<ms>: every frame is a frame of <ms> milliseconds whatever the machine does, as ScummVM's --sim-fps does.
"""
import struct


def apply(pe, args):
    old = pe.read(0x00401721, 5)
    assert old == b"\xa1\x48\x5a\x4f\x00", "not the exe this patch is for: %r" % old
    pe.write(0x00401721, b"\xb8" + struct.pack("<I", args.simtime_ms))
