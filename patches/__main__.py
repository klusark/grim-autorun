import argparse
import os

from . import TARGETS, dll
from .pe import PE

EMI_DIR = "C:/GOG Games/Escape from Monkey Island/"


def split(s):
    return [x for x in s.split(",") if x]


def main():
    ap = argparse.ArgumentParser(prog="python -m patches", description="Patch an original executable with a pipeline of patches.")
    ap.add_argument("target", nargs="?", choices=sorted(TARGETS))
    ap.add_argument("exe_in", nargs="?")
    ap.add_argument("exe_out", nargs="?")
    ap.add_argument("--with", dest="extra", default="", metavar="A,B", help="also run these patches that are off by default, or 'all'")
    ap.add_argument("--only", default="", metavar="A,B", help="run only these patches")
    ap.add_argument("--skip", default="", metavar="A,B", help="leave these out")
    ap.add_argument("--simtime-ms", type=int, default=17, help="ms a frame for the simtime patch (default 17)")
    ap.add_argument("--no-dll", action="store_true", help="do not build patch.dll next to the output exe")
    ap.add_argument("--list", action="store_true", help="list the targets and patches")
    args = ap.parse_args()

    if args.list or not args.target:
        for t, (desc, patches) in TARGETS.items():
            print("%s: %s" % (t, desc))
            for name, mod, default in patches:
                print("    %-11s %s%s" % (name, "" if default else "(--with) ", mod.__doc__.strip().splitlines()[0]))
        return
    if args.target == "emi":
        args.exe_in = args.exe_in or EMI_DIR + "Monkey4.exe"
        args.exe_out = args.exe_out or EMI_DIR + "Monkey4_f12.exe"
    if not (args.exe_in and args.exe_out):
        ap.error("exe_in and exe_out are required")

    patches = TARGETS[args.target][1]
    names = [n for n, _, _ in patches]
    for n in split(args.extra) + split(args.only) + split(args.skip):
        if n != "all" and n not in names:
            ap.error("%s has no patch %r (has: %s)" % (args.target, n, ", ".join(names)))
    only, skip = split(args.only), split(args.skip)
    extra = names if "all" in split(args.extra) else split(args.extra)
    chosen = [(n, m) for n, m, default in patches
              if (n in only if only else default or n in extra) and n not in skip]

    need_dll = any(getattr(m, "NEEDS_DLL", False) for _, m in chosen) and not args.no_dll
    if need_dll:
        dll.find_compiler()   # fail before anything is written
    pe = PE(open(args.exe_in, "rb").read())
    for name, mod in chosen:
        mod.apply(pe, args)
        print("applied", name)
    open(args.exe_out, "wb").write(pe.d)
    print("wrote", args.exe_out)
    if need_dll:
        print("built", dll.build(os.path.dirname(os.path.abspath(args.exe_out))))


main()
