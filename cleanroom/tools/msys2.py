"""Where MSYS2 is, for the tools run.py builds and runs with its compilers (offscreen.exe, patch.dll, grimlaunch.exe) and
crashstack.py's nm / c++filt / objdump. In this order:

  CR_MSYS2                      its root folder (on CI the msys2-location output of msys2/setup-msys2)
  the MSYS2 of PATH             the root of the cygpath.exe found on PATH (an MSYS2 shell has it), if it is an MSYS2
                                (Git for Windows has a cygpath.exe too, without the ucrt64 and mingw32 environments)
  C:\\msys64                     the installer's default

A root counts only when it has the ucrt64 or the mingw32 environment in it. Nothing is looked up until a tool is needed, so
the runs that need none (ScummVM on Linux) do not need MSYS2."""
import os
import shutil

DEFAULT = r"C:\msys64"
ENVIRONMENTS = ("ucrt64", "mingw32")
_root = None


def _is_msys2(d):
    return bool(d) and any(os.path.isdir(os.path.join(d, e)) for e in ENVIRONMENTS)


def candidates():
    """The roots tried, in order (each one once)."""
    out = []
    env = os.environ.get("CR_MSYS2")
    if env:
        out.append(env)
    cygpath = shutil.which("cygpath")
    if cygpath:
        # (<root>\usr\bin\cygpath.exe)
        out.append(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(cygpath)))))
    out.append(DEFAULT)
    seen = []
    for d in out:
        d = os.path.normpath(d)
        if os.path.normcase(d) not in [os.path.normcase(s) for s in seen]:
            seen.append(d)
    return seen


def root():
    """The root of MSYS2; RuntimeError when there is none (CR_MSYS2 tells where it is)."""
    global _root
    if _root is None:
        tried = candidates()
        found = [d for d in tried if _is_msys2(d)]
        if not found:
            raise RuntimeError("MSYS2 not found (tried %s): set CR_MSYS2 to its root folder" % ", ".join(tried))
        # (CR_MSYS2 set to a folder that is no MSYS2 is a mistake, not a reason to take another one)
        if os.environ.get("CR_MSYS2") and found[0] != tried[0]:
            raise RuntimeError("CR_MSYS2=%s has no %s folder in it" % (os.environ["CR_MSYS2"], " or ".join(ENVIRONMENTS)))
        _root = found[0]
    return _root


def bin_dir(environment):
    """The bin folder of an environment of MSYS2 ("ucrt64", "mingw32")."""
    return os.path.join(root(), environment, "bin")


def tool(environment, name):
    """The path of a program of that environment (name without .exe)."""
    return os.path.join(bin_dir(environment), name + ".exe")


def path_with(environment, env=None):
    """A copy of env (os.environ) with the environment's bin folder first on PATH; unchanged when there is no MSYS2."""
    env = dict(env or os.environ)
    try:
        env["PATH"] = bin_dir(environment) + os.pathsep + env.get("PATH", "")
    except RuntimeError:
        pass
    return env
