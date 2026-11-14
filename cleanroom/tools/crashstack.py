"""Backtrace from a Windows minidump (the .dmp files WER writes to %LOCALAPPDATA%\\CrashDumps), without any package.

  python crashstack.py FILE.dmp [--exe scummvm.exe]     prints the exception and the stack of the thread that crashed
  python crashstack.py FILE.dmp --symbols symbols/remastered.txt --module GrimFandango.exe     with the names of a Ghidra export

There is no unwinder: the stack is scanned from the stack pointer for values that point into a loaded module (the return
addresses), so a frame or two may be stray values. A function name is given for the exe passed with --exe when `nm` can read
its symbols (the retail Grim and EMI exes have none: those frames are module+offset)."""
import bisect
import glob
import os
import struct
import subprocess
import sys

CRASHDUMPS = os.path.join(os.environ.get("LOCALAPPDATA", ""), "CrashDumps")
NM = "nm"   # (binutils from PATH: MSYS2's ucrt64\bin)
CPPFILT = "c++filt"
EXIT_MARK = 0xE0455849   # patch.dll's made-up exception code for "the process is ending itself"
CODES = {0xC0000005: "access violation", 0xC00000FD: "stack overflow", 0xC0000094: "integer divide by zero",
         0xC000001D: "illegal instruction", 0xC0000374: "heap corruption", 0xC0000409: "stack buffer overrun (fast fail)",
         0x80000003: "breakpoint", 0xC0000025: "noncontinuable exception"}


def parse(path):
    d = open(path, "rb").read()
    if d[:4] != b"MDMP":
        raise ValueError("not a minidump")
    nstreams, rva = struct.unpack_from("<II", d, 8)
    streams = {}
    for i in range(nstreams):
        t, size, off = struct.unpack_from("<III", d, rva + 12 * i)
        streams[t] = (size, off)
    dump = {"data": d, "modules": [], "memory": [], "threads": {}, "exception": None, "arch": 9}
    if 7 in streams:
        dump["arch"] = struct.unpack_from("<H", d, streams[7][1])[0]   # 0 x86, 9 amd64
    if 4 in streams:
        off = streams[4][1]
        for i in range(struct.unpack_from("<I", d, off)[0]):
            base, size = struct.unpack_from("<QI", d, off + 4 + 108 * i)
            name_rva = struct.unpack_from("<I", d, off + 4 + 108 * i + 20)[0]
            n = struct.unpack_from("<I", d, name_rva)[0]
            name = d[name_rva + 4:name_rva + 4 + n].decode("utf-16-le")
            dump["modules"].append((base, size, name))
    if 9 in streams:   # Memory64List
        off = streams[9][1]
        count, data = struct.unpack_from("<QQ", d, off)
        for i in range(count):
            start, size = struct.unpack_from("<QQ", d, off + 16 + 16 * i)
            dump["memory"].append((start, size, data))
            data += size
    if 5 in streams:   # MemoryList
        off = streams[5][1]
        for i in range(struct.unpack_from("<I", d, off)[0]):
            start, size, r = struct.unpack_from("<QII", d, off + 4 + 16 * i)
            dump["memory"].append((start, size, r))
    if 3 in streams:
        off = streams[3][1]
        for i in range(struct.unpack_from("<I", d, off)[0]):
            tid = struct.unpack_from("<I", d, off + 4 + 48 * i)[0]
            csize, crva = struct.unpack_from("<II", d, off + 4 + 48 * i + 40)
            dump["threads"][tid] = (csize, crva)
    if 6 in streams:
        off = streams[6][1]
        tid = struct.unpack_from("<I", d, off)[0]
        code, flags = struct.unpack_from("<II", d, off + 8)
        addr = struct.unpack_from("<Q", d, off + 24)[0]
        nparams = struct.unpack_from("<I", d, off + 32)[0]
        info = struct.unpack_from("<%dQ" % min(nparams, 15), d, off + 40)
        csize, crva = struct.unpack_from("<II", d, off + 160)   # the context the exception was raised with
        dump["exception"] = {"thread": tid, "code": code, "address": addr, "info": info, "context": (csize, crva)}
    return dump


def read(dump, addr, n):
    for start, size, rva in dump["memory"]:
        if start <= addr and addr + n <= start + size:
            o = rva + addr - start
            return dump["data"][o:o + n]
    return None


def registers(dump, ctx):
    """(ip, sp, bp) from a CONTEXT: the x64 one or the 32-bit one (716 bytes)."""
    csize, crva = ctx
    d = dump["data"]
    if csize == 716:
        return struct.unpack_from("<III", d, crva + 0xB8)[0], struct.unpack_from("<I", d, crva + 0xC4)[0], struct.unpack_from("<I", d, crva + 0xB4)[0]
    return struct.unpack_from("<Q", d, crva + 0xF8)[0], struct.unpack_from("<Q", d, crva + 0x98)[0], struct.unpack_from("<Q", d, crva + 0xA0)[0]


class FileSymbols:
    """The function names of an exe from a file export_ghidra_symbols.py wrote (tools/symbols/<game>.txt: <rva> <t|f> <name>).
    A function ends where the next one starts, a thunk after 6 bytes; an address outside every function has no name (it is
    still printed as module+offset: the file does not know every function)."""
    strict = False

    def __init__(self, path):
        self.addrs, self.names, self.thunk = [], [], []
        with open(path, encoding="utf-8") as f:
            for line in f:
                if line.startswith("#") or not line.strip():
                    continue
                rva, kind, name = line.rstrip().split(" ", 2)
                self.addrs.append(int(rva, 16))
                self.thunk.append(kind == "t")
                self.names.append(name)
        self.image_base = 0

    def lookup(self, rva):
        i = bisect.bisect_right(self.addrs, rva) - 1
        if i < 0:
            return ""
        end = self.addrs[i] + 6 if self.thunk[i] else (self.addrs[i + 1] if i + 1 < len(self.addrs) else self.addrs[i] + 0x1000)
        if rva >= end:
            return ""
        return "%s+0x%x" % (self.names[i], rva - self.addrs[i])


def module_of(dump, a):
    for base, size, name in dump["modules"]:
        if base <= a < base + size:
            return base, name
    return None


class Symbols:
    """The function symbols of one exe, from nm (none: empty). A hit far from its symbol is data, not code: strict."""
    strict = True

    def __init__(self, exe):
        self.addrs, self.names = [], []
        if not exe or not os.path.exists(exe):
            return
        try:
            out = subprocess.run([NM, "-n", "--defined-only", exe], capture_output=True, text=True, timeout=120).stdout
        except (OSError, subprocess.TimeoutExpired):
            return
        for line in out.splitlines():
            p = line.split(None, 2)
            if len(p) == 3 and p[1] in "tTwW":
                self.addrs.append(int(p[0], 16))
                self.names.append(p[2])
        self.image_base = 0
        try:
            hdr = subprocess.run(["objdump", "-p", exe], capture_output=True, text=True, timeout=60).stdout
            for line in hdr.splitlines():
                if line.startswith("ImageBase"):
                    self.image_base = int(line.split()[1], 16)
        except (OSError, subprocess.TimeoutExpired):
            pass

    def lookup(self, rva):
        """Name+offset of the symbol at an RVA (nm's addresses are image base + rva)."""
        if not self.addrs:
            return None
        i = bisect.bisect_right(self.addrs, self.image_base + rva) - 1
        if i < 0:
            return None
        name = self.names[i]
        try:
            name = subprocess.run([CPPFILT], input=name, capture_output=True, text=True, timeout=30).stdout.strip() or name
        except (OSError, subprocess.TimeoutExpired):
            pass
        off = self.image_base + rva - self.addrs[i]
        return None if off > 0x8000 else "%s+0x%x" % (name, off)   # (further from its symbol than any function is long: data)


def describe(dump, a, exe_name, symbols):
    m = module_of(dump, a)
    if not m:
        return "0x%x" % a
    base, name = m
    short = os.path.basename(name)
    text = "%s+0x%x" % (short, a - base)
    if symbols and symbols.addrs and exe_name and short.lower() == exe_name.lower():
        sym = symbols.lookup(a - base)
        if sym is None and symbols.strict:
            return None
        if sym:
            text += "  " + sym
    return text


def backtrace(path, exe=None, frames=40, symbols_file=None, exe_name=None):
    """The text of the report: the exception and the return addresses found on the crashed thread's stack."""
    dump = parse(path)
    ex = dump["exception"]
    if not ex:
        return "(the dump has no exception record)"
    if symbols_file and os.path.exists(symbols_file):
        symbols = FileSymbols(symbols_file)   # (exe_name: the module that the names are for)
    else:
        exe_name = os.path.basename(exe) if exe else None
        symbols = Symbols(exe) if exe else None
    ip, sp, bp = registers(dump, ex["context"])
    word = 4 if ex["context"][0] == 716 else 8
    if ex["code"] == EXIT_MARK:   # patch.dll's hook of ExitProcess, TerminateProcess, _exit...: the game ended itself
        lines = ["the process ended itself (exit code %d, 0x%X), called from %s" % (ex["info"][0] if ex["info"] else 0, (ex["info"][0] if ex["info"] else 0) & 0xFFFFFFFF, describe(dump, ex["address"], exe_name, symbols))]
    else:
        lines = ["exception 0x%08x (%s) at %s" % (ex["code"], CODES.get(ex["code"], "unknown"), describe(dump, ex["address"], exe_name, symbols))]
    if ex["code"] == 0xC0000005 and len(ex["info"]) >= 2:
        lines.append("  %s address 0x%x" % ({0: "reading", 1: "writing", 8: "executing"}.get(ex["info"][0], "touching"), ex["info"][1]))
    chain = os.path.splitext(path)[0] + ".txt"   # (ScummVM's crash handler unwinds the stack itself: exact, unlike the scan below)
    if ex["code"] != EXIT_MARK and os.path.exists(chain) and symbols:
        lines.append("call chain of the crashed thread (unwound with the unwind tables by the engine's crash handler):")
        with open(chain) as f:
            for n, l in enumerate(f):
                mod, _, rva = l.strip().rpartition(" ")
                text = "%s+0x%s" % (mod, rva)
                if exe_name and mod.lower() == exe_name.lower() and symbols.addrs:
                    sym = symbols.lookup(int(rva, 16))
                    if sym:
                        text += "  " + sym
                lines.append("  #%-3d %s" % (n, text))
        return "\n".join(lines)
    lines.append("stack of thread %d (return addresses found by scanning from the stack pointer 0x%x; some may be stray):" % (ex["thread"], sp))
    if ex["code"] != EXIT_MARK:
        lines.append("   #0  %s" % describe(dump, ip, exe_name, symbols))
    n, a = (0 if ex["code"] == EXIT_MARK else 1), sp
    # (an exit record is made by patch.dll's hook: its own frames, and what lies on the stack before the caller's return address, are
    # not part of the trace; it starts at the caller)
    started = ex["code"] != EXIT_MARK
    while n < frames:
        w = read(dump, a, word)
        if w is None:
            break
        v = int.from_bytes(w, "little")
        if not started:
            started = v == ex["address"]
            if not started:
                a += word
                if a - sp > 0x10000:
                    break
                continue
        where = describe(dump, v, exe_name, symbols) if module_of(dump, v) else None
        if where:
            lines.append("  #%-3d %s" % (n, where))
            n += 1
        a += word
        if a - sp > 0x10000:
            break
    return "\n".join(lines)


def newest_dump(exe_name, since):
    """The newest dump of that exe written after the time `since`, or None."""
    found = [p for p in glob.glob(os.path.join(CRASHDUMPS, exe_name + ".*.dmp")) if os.path.getmtime(p) >= since]
    return max(found, key=os.path.getmtime) if found else None


if __name__ == "__main__":
    args = sys.argv[1:]
    exe = args[args.index("--exe") + 1] if "--exe" in args else None
    syms = args[args.index("--symbols") + 1] if "--symbols" in args else None
    name = args[args.index("--module") + 1] if "--module" in args else None
    print(backtrace(args[0], exe, symbols_file=syms, exe_name=name))
