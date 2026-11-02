"""Escape from Monkey Island: F11 in the original EMI runs lua_dofile("grimpatch.bin") (the same hook as Grim's Backspace+F12; F12 is DREAMM's own menu key).

Ghidra (/emi/Monkey4.exe): WndProc 0x00406700, WM_KEYDOWN range check at 0x004068cb (cmp eax,0x44 / ja default), lua_dofile 0x004420c0 (cdecl,
char*), default message path 0x00406880, .text slack 0x004abe82..0x004abfff.
"""
import struct

HOOK = 0x4068CB      # 83 f8 44 77 b0: cmp eax,0x44 ; ja 0x406880
BACK = 0x4068D0      # first instruction after the range check
DEFAULT = 0x406880   # DefWindowProc path
DOFILE = 0x4420C0
CAVE = 0x4ABE90


def rel(src_end, dst):
    return struct.pack("<i", dst - src_end)


def apply(pe, args):
    assert pe.read(HOOK, 5) == bytes.fromhex("83f84477b0"), "unexpected bytes at the hook"
    assert not any(pe.read(CAVE, 0x60)), "cave is not empty"

    code = bytearray()
    code += bytes.fromhex("83f844")          # cmp eax,0x44
    code += bytes.fromhex("7705")            # ja chk (+5)
    code += b"\xe9" + rel(CAVE + len(code) + 5, BACK)   # jmp BACK
    code += bytes.fromhex("83ff7a")          # chk: cmp edi,VK_F11
    code += bytes.fromhex("0f85") + rel(CAVE + len(code) + 6, DEFAULT)   # jne DEFAULT
    push_at = len(code)
    code += b"\x68\0\0\0\0"                  # push str (fixed below)
    code += b"\xe8" + rel(CAVE + len(code) + 5, DOFILE)   # call lua_dofile
    code += bytes.fromhex("83c404")          # add esp,4
    code += b"\xe9" + rel(CAVE + len(code) + 5, DEFAULT)  # jmp DEFAULT
    str_at = len(code)
    code += b"grimpatch.bin\0"
    code[push_at + 1:push_at + 5] = struct.pack("<I", CAVE + str_at)

    pe.write(CAVE, code)
    pe.extend_text_vsize()   # the cave lies past .text VirtualSize (0xaae82)
    pe.write(HOOK, b"\xe9" + rel(HOOK + 5, CAVE))
