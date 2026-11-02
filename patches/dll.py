"""Builds patch.dll, which the patched exes load for logging, the frame limiter and the input dialog.

It has to be a 32-bit dll: the games are 32-bit. The compiler is the first of $GRIMDLG_CC, i686-w64-mingw32-gcc on the PATH and
the MSYS2 MINGW32 / CLANG32 gcc (pacman -S mingw-w64-i686-gcc).
"""
import os
import shutil
import subprocess

SRC = os.path.join(os.path.dirname(os.path.abspath(__file__)), "patch", "patch.c")
MSYS = "C:/msys64"


def find_compiler():
    candidates = [os.environ.get("GRIMDLG_CC"), "i686-w64-mingw32-gcc",
                  MSYS + "/mingw32/bin/gcc.exe", MSYS + "/clang32/bin/gcc.exe"]
    for c in candidates:
        if c and (shutil.which(c) or os.path.isfile(c)):
            return shutil.which(c) or c
    raise SystemExit("no 32-bit gcc found for patch.dll: install one (pacman -S mingw-w64-i686-gcc), set GRIMDLG_CC, "
                     "or run with --no-dll to keep the dll you have")


def compiler_env(compiler):
    """environment for the compiler: its own bin folder first on PATH (cc1 and ld need its dlls), and its lib folders on LIBRARY_PATH,
    so a gcc started from outside its MSYS2 shell finds winmm, user32 and the rest"""
    env = dict(os.environ)
    bin_dir = os.path.dirname(os.path.abspath(compiler))
    root = os.path.dirname(bin_dir)
    libs = [os.path.join(root, "lib")] + [os.path.join(root, d, "lib") for d in os.listdir(root) if d.endswith("-mingw32")]
    env["PATH"] = bin_dir + os.pathsep + env.get("PATH", "")
    libs = [l for l in libs if os.path.isdir(l)]
    if env.get("LIBRARY_PATH"):
        libs.append(env["LIBRARY_PATH"])
    env["LIBRARY_PATH"] = os.pathsep.join(libs)
    return env


def build(out_dir):
    out = os.path.join(out_dir, "patch.dll")
    cmd = [find_compiler(), "-shared", "-O2", "-static-libgcc", "-o", out, SRC, "-luser32", "-lgdi32", "-lwinmm"]
    if not os.path.isfile(SRC):
        raise SystemExit("patch.dll source not found: " + SRC)
    if not os.path.isdir(out_dir):
        raise SystemExit("cannot build patch.dll, output folder does not exist: " + out_dir)
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, env=compiler_env(cmd[0]))
    except OSError as e:
        raise SystemExit("could not run the compiler %s: %s" % (cmd[0], e))
    if r.returncode != 0:
        raise SystemExit("building patch.dll failed (exit %d)\ncommand: %s\n%s%s"
                         % (r.returncode, " ".join(cmd), r.stdout, r.stderr))
    if r.stderr.strip():
        print(r.stderr.strip())   # compiler warnings
    if not os.path.isfile(out):
        raise SystemExit("the compiler reported success but %s was not written" % out)
    return out
