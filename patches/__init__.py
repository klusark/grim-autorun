"""Executable patches as one pipeline: python -m patches --help (from the grim_tools folder)

Every patch module has apply(pe, args) and edits a pe.PE in memory. A target lists its patches in the order they run;
the pipeline reads the exe once, runs them, and writes the result once. The patches share the code cave at the end of .text.
"""
from .grim import config, debuglog, framelimit, simtime
from .remastered import inputdialog
from .emi import f12

# target -> (description, [(name, module, on by default)])
TARGETS = {
    "grim": ("Grim Fandango v1.01 (GRIMFANDANGO.EXE from GFUPD101)", [
        ("debuglog", debuglog, True),      # PrintDebug/Warning/Error -> grimdebug.log
        ("framelimit", framelimit, False),  # 60 fps limiter
        ("simtime", simtime, True),       # fixed frame time
        ("config", config, False),        # grim.ini instead of the registry
    ]),
    "remastered": ("Grim Fandango Remastered (GrimFandango.exe)", [
        ("inputdialog", inputdialog, True),
    ]),
    "emi": ("Escape from Monkey Island (Monkey4.exe)", [
        ("f12", f12, True),
    ]),
}
