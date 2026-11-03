"""Launcher that patches the original exe in memory instead of on disk: python -m patches.launch <exe> [args...]

The exe is started suspended, the patches are written into the process with WriteProcessMemory and the main thread is resumed.
No debugger is attached and no dll is loaded. For now the only patch is the debug log: PrintDebug / PrintWarning / PrintError
(GRIMFANDANGO.EXE v1.01) append their message to grimdebug.log next to the exe, as patches/grim/debuglog.py does for the file.

The logging code is x86 written for `as --32` (binutils); it only calls through the exe's own import table (lua.dll for the message,
kernel32 for the file), so it needs nothing loaded. It goes into memory the launcher allocates in the process.
"""
import argparse
import ctypes
import os
import shutil
import struct
import subprocess
import tempfile
from ctypes import wintypes

from .grim import debuglog
from .pe import PE

CREATE_SUSPENDED = 4
MEM_COMMIT_RESERVE = 0x3000
PAGE_EXECUTE_READWRITE = 0x40
INFINITE = 0xFFFFFFFF
# where the launcher puts its code in the target. The exe's dlls (lua.dll at 0x10000000, the system ones from 0x6xxxxxxx up) stay clear of it
ARENA = 0x5F000000
ARENA_SIZE = 0x1000
DATA = ARENA + 0x800

k32 = ctypes.WinDLL("kernel32", use_last_error=True)
k32.CreateProcessA.argtypes = [wintypes.LPCSTR, wintypes.LPSTR, ctypes.c_void_p, ctypes.c_void_p, wintypes.BOOL, wintypes.DWORD,
                               ctypes.c_void_p, wintypes.LPCSTR, ctypes.c_void_p, ctypes.c_void_p]
k32.VirtualAllocEx.argtypes = [wintypes.HANDLE, ctypes.c_void_p, ctypes.c_size_t, wintypes.DWORD, wintypes.DWORD]
k32.VirtualAllocEx.restype = ctypes.c_void_p
k32.VirtualProtectEx.argtypes = [wintypes.HANDLE, ctypes.c_void_p, ctypes.c_size_t, wintypes.DWORD, ctypes.POINTER(wintypes.DWORD)]
k32.WriteProcessMemory.argtypes = [wintypes.HANDLE, ctypes.c_void_p, ctypes.c_char_p, ctypes.c_size_t, ctypes.POINTER(ctypes.c_size_t)]
k32.ReadProcessMemory.argtypes = [wintypes.HANDLE, ctypes.c_void_p, ctypes.c_void_p, ctypes.c_size_t, ctypes.POINTER(ctypes.c_size_t)]
k32.ResumeThread.argtypes = [wintypes.HANDLE]
k32.WaitForSingleObject.argtypes = [wintypes.HANDLE, wintypes.DWORD]
k32.GetExitCodeProcess.argtypes = [wintypes.HANDLE, ctypes.POINTER(wintypes.DWORD)]
k32.TerminateProcess.argtypes = [wintypes.HANDLE, wintypes.UINT]


class STARTUPINFO(ctypes.Structure):
    _fields_ = [("cb", wintypes.DWORD)] + [(n, ctypes.c_void_p) for n in ("r1", "desktop", "title")] + \
               [(n, wintypes.DWORD) for n in ("x", "y", "xs", "ys", "xc", "yc", "fill", "flags")] + \
               [("show", wintypes.WORD), ("r2", wintypes.WORD), ("r3", ctypes.c_void_p)] + [(n, ctypes.c_void_p) for n in ("in", "out", "err")]


class PROCESS_INFORMATION(ctypes.Structure):
    _fields_ = [("process", wintypes.HANDLE), ("thread", wintypes.HANDLE), ("pid", wintypes.DWORD), ("tid", wintypes.DWORD)]


class Process:
    """a suspended process whose memory the patches write"""

    def __init__(self, exe, args, cwd):
        si = STARTUPINFO()
        si.cb = ctypes.sizeof(si)
        pi = PROCESS_INFORMATION()
        cmd = ('"%s" %s' % (exe, args)).encode()
        if not k32.CreateProcessA(None, cmd, None, None, False, CREATE_SUSPENDED, None, cwd.encode(), ctypes.byref(si), ctypes.byref(pi)):
            raise SystemExit("CreateProcess failed: error %d" % ctypes.get_last_error())
        self.process, self.thread, self.pid = pi.process, pi.thread, pi.pid

    def read(self, va, n):
        buf = ctypes.create_string_buffer(n)
        got = ctypes.c_size_t()
        if not k32.ReadProcessMemory(self.process, va, buf, n, ctypes.byref(got)):
            raise SystemExit("ReadProcessMemory 0x%x failed: error %d" % (va, ctypes.get_last_error()))
        return buf.raw

    def write(self, va, data):
        old = wintypes.DWORD()
        k32.VirtualProtectEx(self.process, va, len(data), PAGE_EXECUTE_READWRITE, ctypes.byref(old))
        if not k32.WriteProcessMemory(self.process, va, bytes(data), len(data), None):
            raise SystemExit("WriteProcessMemory 0x%x failed: error %d" % (va, ctypes.get_last_error()))
        k32.VirtualProtectEx(self.process, va, len(data), old.value, ctypes.byref(old))

    def alloc(self, va, size):
        got = k32.VirtualAllocEx(self.process, va, size, MEM_COMMIT_RESERVE, PAGE_EXECUTE_READWRITE)
        if got != va:
            raise SystemExit("could not allocate 0x%x bytes at 0x%x in the process" % (size, va))

    def resume(self):
        k32.ResumeThread(self.thread)

    def wait(self):
        k32.WaitForSingleObject(self.process, INFINITE)
        code = wintypes.DWORD()
        k32.GetExitCodeProcess(self.process, ctypes.byref(code))
        return code.value


def assemble(source):
    """Intel syntax x86-32 source -> bytes, with the GNU assembler"""
    as_, objcopy = shutil.which("as"), shutil.which("objcopy")
    if not (as_ and objcopy):
        raise SystemExit("the assembler is missing: `as` and `objcopy` (binutils) must be on the PATH")
    with tempfile.TemporaryDirectory() as t:
        s, o, b = (os.path.join(t, n) for n in ("a.s", "a.o", "a.bin"))
        open(s, "w").write(".intel_syntax noprefix\n.text\n" + source)
        for cmd in ([as_, "--32", "-o", o, s], [objcopy, "-O", "binary", "-j", ".text", o, b]):
            r = subprocess.run(cmd, capture_output=True, text=True)
            if r.returncode:
                raise SystemExit("%s failed:\n%s%s" % (cmd[0], r.stderr, source))
        return open(b, "rb").read()


def log_stub(iat, path_va, prefix_va, prefix_len, newline_va, scratch_va):
    """Lua builtin, cdecl, no arguments: appends "<prefix><first Lua argument, if it is a string>\\n" to the log file"""
    return assemble("""
        push ebx
        push esi
        push 1
        call [%(lua2C)#x]
        add esp, 4
        mov ebx, eax
        push ebx
        call [%(isstring)#x]
        add esp, 4
        test eax, eax
        jz 9f
        push ebx
        call [%(getstring)#x]
        add esp, 4
        mov esi, eax
        push 0
        push 0x80
        push 4
        push 0
        push 3
        push 4
        push %(path)#x
        call [%(createfile)#x]
        cmp eax, -1
        je 9f
        mov ebx, eax
        push 0
        push %(scratch)#x
        push %(prefix_len)d
        push %(prefix)#x
        push ebx
        call [%(writefile)#x]
        mov edx, esi
    1:  cmp byte ptr [edx], 0
        je 2f
        inc edx
        jmp 1b
    2:  sub edx, esi
    3:  test edx, edx
        jz 5f
        mov al, [esi + edx - 1]
        cmp al, 10
        je 4f
        cmp al, 13
        jne 5f
    4:  dec edx
        jmp 3b
    5:  push 0
        push %(scratch)#x
        push edx
        push esi
        push ebx
        call [%(writefile)#x]
        push 0
        push %(scratch)#x
        push 1
        push %(newline)#x
        push ebx
        call [%(writefile)#x]
        push ebx
        call [%(closehandle)#x]
    9:  pop esi
        pop ebx
        ret
    """ % dict(iat, path=path_va, prefix=prefix_va, prefix_len=prefix_len, newline=newline_va, scratch=scratch_va))


def apply_debuglog(proc, exe_file, log_path):
    pe = PE(open(exe_file, "rb").read())   # only for the import table, which is the same in the process
    iat = dict(lua2C=pe.import_slot(b"lua_lua2C"), isstring=pe.import_slot(b"lua_isstring"), getstring=pe.import_slot(b"lua_getstring"),
               createfile=pe.import_slot(b"CreateFileA"), writefile=pe.import_slot(b"WriteFile"), closehandle=pe.import_slot(b"CloseHandle"))
    for slot, _ in debuglog.SLOTS:
        got = struct.unpack("<I", proc.read(slot, 4))[0]
        assert got == debuglog.NOOP_BUILTIN, "unexpected builtin at 0x%x: the exe is not the v1.01 one" % slot

    # data: the log path, the three prefixes, the newline and a scratch dword for WriteFile
    data = bytearray()

    def add(b):
        va = DATA + len(data)
        data.extend(b)
        return va

    path_va = add(log_path.encode() + b"\0")
    prefixes = {b"GrimLogDebug": b"DEBUG ", b"GrimLogWarning": b"WARN  ", b"GrimLogError": b"ERROR "}
    prefix_va = {export: add(p) for export, p in prefixes.items()}
    newline_va = add(b"\n")
    scratch_va = add(b"\0\0\0\0")
    assert len(data) < ARENA_SIZE - 0x800

    proc.alloc(ARENA, ARENA_SIZE)
    proc.write(DATA, data)
    for i, (slot, export) in enumerate(debuglog.SLOTS):
        va = ARENA + i * 0x200
        code = log_stub(iat, path_va, prefix_va[export], len(prefixes[export]), newline_va, scratch_va)
        assert len(code) <= 0x200
        proc.write(va, code)
        proc.write(slot, struct.pack("<I", va))


def main():
    ap = argparse.ArgumentParser(prog="python -m patches.launch", description="Start the original Grim Fandango v1.01 exe with the debug log patched in memory.")
    ap.add_argument("exe")
    ap.add_argument("args", nargs=argparse.REMAINDER, help="command line arguments for the game")
    a = ap.parse_args()
    exe = os.path.abspath(a.exe)
    cwd = os.path.dirname(exe)
    log = os.path.join(cwd, "grimdebug.log")
    proc = Process(exe, " ".join(a.args), cwd)
    try:
        apply_debuglog(proc, exe, log)
    except BaseException:
        k32.TerminateProcess(proc.process, 1)
        raise
    proc.resume()
    print("started pid %d, logging to %s" % (proc.pid, log))
    print("exit code", proc.wait())


if __name__ == "__main__":
    main()
