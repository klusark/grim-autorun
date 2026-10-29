# Makes the guard counter of IMUSE.DLL (original Grim Fandango) atomic: Im_GuardEnter (RVA 0x4f50) and Im_GuardLeave (RVA 0x4f60) used
# INC [counter] and load / dec / store with no LOCK, so two threads leaving iMuse together lost an update, the counter stuck at 1 and
# ImHeartbeat (which only runs at 0) never ran again (every wait for a sound spun for ever).
#
#   Im_GuardEnter:  push ecx / mov ecx,&counter / lock inc [ecx] / pop ecx / ret
#   Im_GuardLeave:  mov eax,&counter / lock dec [eax] / jns done / lock inc [eax] / done: ret      (the clamp at 0 of the original kept)
#
# The address operands stay where the relocation entries of the DLL expect them (0xf52, 0xf61); the entry of the old operand at 0xf6b is
# switched off (type 0), the bytes there are code now.
#   imuse_patch.py apply | revert | check [path]       (the backup is IMUSE.DLL.unpatched next to the DLL)
import shutil, struct, sys

mode = sys.argv[1] if len(sys.argv) > 1 else "check"
path = sys.argv[2] if len(sys.argv) > 2 else r"C:\GOG Games\GRIMDATA\IMUSE.DLL"
backup = path + ".unpatched"

ORIG50 = bytes.fromhex("ff05c072011 0c3".replace(" ", ""))
ORIG60 = bytes.fromhex("a1c07201 1085c07406 48a3c0720110c3".replace(" ", ""))
CTR = bytes.fromhex("c0720110")
NEW50 = bytes([0x51, 0xB9]) + CTR + bytes([0xF0, 0xFF, 0x01, 0x59, 0xC3])
NEW60 = bytes([0xB8]) + CTR + bytes([0xF0, 0xFF, 0x08, 0x79, 0x03, 0xF0, 0xFF, 0x00, 0xC3, 0xCC, 0xCC])
assert len(NEW60) == 16

FILE_OFF = 0x400 - 0x1000  # .text: file = rva + FILE_OFF
O50 = 0x4f50 + FILE_OFF
O60 = 0x4f60 + FILE_OFF
RELOC_ENTRY_6B = 0x2134c  # file offset of the relocation entry of offset 0xf6b of page 0x4000 (tools/imuse_inspect.py)
RELOC_ENTRY_52 = 0x21348
RELOC_ENTRY_61 = 0x2134a


def state(d):
    if d[O50:O50 + len(ORIG50)] == ORIG50 and d[O60:O60 + len(ORIG60)] == ORIG60:
        return "original"
    if d[O50:O50 + len(NEW50)] == NEW50 and d[O60:O60 + 16] == NEW60:
        return "patched"
    return "unknown"


d = bytearray(open(path, "rb").read())
assert struct.unpack_from("<H", d, RELOC_ENTRY_52)[0] == 0x3F52, "unexpected relocation table"
assert struct.unpack_from("<H", d, RELOC_ENTRY_61)[0] == 0x3F61, "unexpected relocation table"
st = state(d)
if mode == "check":
    print(path, st)
elif mode == "apply":
    if st == "patched":
        print("already patched")
        sys.exit(0)
    assert st == "original", "unexpected bytes, not touching the file"
    assert struct.unpack_from("<H", d, RELOC_ENTRY_6B)[0] == 0x3F6B
    shutil.copyfile(path, backup)
    d[O50:O50 + len(NEW50)] = NEW50
    d[O60:O60 + 16] = NEW60
    struct.pack_into("<H", d, RELOC_ENTRY_6B, 0)
    open(path, "wb").write(d)
    print("patched; backup", backup)
elif mode == "revert":
    shutil.copyfile(backup, path)
    print("restored from", backup)
