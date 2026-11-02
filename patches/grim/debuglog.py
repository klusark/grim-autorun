"""PrintDebug/PrintWarning/PrintError of the original GRIMFANDANGO.EXE (v1.01) log to a file.

The retail executable registers all three Lua builtins with one function that does nothing.
Changes (all reversible by restoring the original exe):
  * The function pointers of the three builtins in the Lua function table (.data) are pointed
    at three stubs, so each level gets its own logging function.
  * The stubs are written into the zero padding at the end of .text. Each one does
    LoadLibraryA("patch.dll"), GetProcAddress("GrimLogDebug" / "GrimLogWarning" /
    "GrimLogError") and jumps to it. If the dll or the export is missing the builtin simply
    returns, as the original did.
patch.dll must be next to the executable. Messages are appended to grimdebug.log in the
same folder.
"""
import struct

from ..pe import loader_stub

NEEDS_DLL = True
NOOP_BUILTIN = 0x0049DDD0
# address of the function pointer in the table, and the export it gets sent to
SLOTS = (
    (0x004EAB8C, b"GrimLogError"),    # PrintError
    (0x004EAB94, b"GrimLogWarning"),  # PrintWarning
    (0x004EAB9C, b"GrimLogDebug"),    # PrintDebug
)


def apply(pe, args):
    # all three builtins must still be the shared no-op
    for slot, _ in SLOTS:
        assert struct.unpack("<I", pe.read(slot, 4))[0] == NOOP_BUILTIN, "unexpected builtin at " + hex(slot)
    for slot, export in SLOTS:
        pe.write(slot, struct.pack("<I", loader_stub(pe, export)))
