"""Clean-room engine tests: our own data (Lua, sets, bitmaps, text) run on ScummVM and on the original v1.01 exe, with no
file of the game's data. See README.md.

  python run.py build                      writes the data into build/ (loose files)
  python run.py scummvm [--only T1,T2]     runs ScummVM with each of its renderers, compares each with expected/original.log
                   [--renderer R,R]        only these renderers (opengl, opengl_shaders, software; CR_RENDERERS too)
  python run.py original [--only T]        runs the original exe through grimlaunch.exe, compares with the expected log
  python run.py original --save            ... and makes the run the new expected log
  python run.py remastered [--only T]      runs the Grim Fandango Remastered exe (debuglog patch only), compares with the expected log
  python run.py both                       both engines, compared with each other
  python run.py compare A.log B.log        compares two result logs
  python run.py <command> --game emi       the same for Escape from Monkey Island: the original Monkey4.exe v1.1 (through
                                           grimlaunch.exe) and ScummVM's EMI; the test files whose "-- games:" names emi

Each test file names the games it runs on with "-- games: grim emi" at the end of its first line (none: grim only). Each game's original
is its own reference: expected/original.log for Grim, expected/emi_original.log for EMI. The EMI runs keep their files in
build_emi/, run/emi/ and logs/emi/; its data go into one archive, local.m4b (the original reads no loose Lua). The Lua global
CR_GAME is "grim" or "emi".

A test that crashes or hangs an engine is found and skipped (README.md). ScummVM's are kept in
logs/scummvm_known_crashers_<renderer>.txt, skipped and reported on the next runs; --fresh runs them again.

ScummVM runs every test once with each renderer of Grim (RENDERERS: OpenGL, OpenGL with shaders, the software TinyGL):
logs/scummvm_<renderer>.log and logs/scummvm_<renderer>_raw.log; logs/scummvm.log is the first renderer's.

Results go to logs/<engine>.log (only the CR lines, normalised) and logs/<engine>_raw.log (the whole engine log).
Environment: SCUMMVM (scummvm.exe), GRIM_INSTALL (the folder the original exe and its DLLs are copied from, default
C:\\GOG Games\\GRIMDATA), CR_VISIBLE=1 (the engines' windows on the screen; otherwise they run on a desktop of their own,
tools/offscreen.c), EMI_INSTALL (the same for Monkey4.exe, default C:\\GOG Games\\Escape from Monkey Island), CR_TIMEOUT
(seconds a run may take, default 120)."""
import argparse
import os
import re
import shutil
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import assets  # noqa: E402
import assets_emi  # noqa: E402
import formats  # noqa: E402
import compare  # noqa: E402
import snaps  # noqa: E402

ROOT = os.path.dirname(HERE)
BUILD = os.path.join(HERE, "build")
RUN = os.path.join(HERE, "run")
LOGS = os.path.join(HERE, "logs")
EXPECTED = os.path.join(HERE, "expected", "original.log")
UNSTABLE = os.path.join(HERE, "expected", "unstable.txt")
# (a build with scummvm/grim-test-data.patch: scummvm/build.sh makes it in ~/scummvm-cleanroom)
SCUMMVM = os.environ.get("SCUMMVM", r"C:\msys64\home\Joel\scummvm-cleanroom\build\scummvm.exe")
GRIM_INSTALL = os.environ.get("GRIM_INSTALL", r"C:\GOG Games\GRIMDATA")
REMASTERED_INSTALL = os.environ.get("REMASTERED_INSTALL", "C:/Program Files (x86)/Steam/steamapps/common/Grim Fandango Remastered")
TIMEOUT = int(os.environ.get("CR_TIMEOUT", "120"))

# The program files of the original (not data): the exe, its DLLs and the two small files iMUSE and the HMI driver read
PROGRAM_FILES = ["GRIMFANDANGO.exe", "LUA.DLL", "IMUSE.DLL", "CHORE.DLL", "NULLMUSE.DLL", "HMIFXFP.DLL", "HMIFXLIB.DLL",
                 "HMILIBS.INI", "IMUSE.PSL", "grimdlg.dll"]
# The Remastered: the exe and the dlls it loads (the game's data are not copied; the Lua is the same 3.1)
REMASTERED_FILES = ["GrimFandango.exe", "Lua.dll", "SDL2.dll", "chore.dll", "steam_api.dll", "controllerdef.txt", "icon.png", "x86"]   # (x86: the shaders)
# EMI's: the exe, the Miles sound dlls and filters, Bink (no .m4b, no movie)
EMI_INSTALL = os.environ.get("EMI_INSTALL", r"C:\GOG Games\Escape from Monkey Island")
EMI_PROGRAM_FILES = ["Monkey4.exe", "Mss32.dll", "binkw32.dll", "Mp3dec.asi", "Chorus.flt", "Reverb3.flt", "Sdelay.flt"]
EMI_ARCHIVE = "local.m4b"
EMI_MARKER = "emitestdata.txt"
TESTS = os.path.join(HERE, "tests")
GAME = "grim"


def set_game(game):
    """Points the folders and the expected files at one game's (Grim's are the top ones, EMI's are beside them)."""
    global GAME, BUILD, RUN, LOGS, EXPECTED, UNSTABLE, CRASHERS
    GAME = game
    if game == "emi":
        BUILD = os.path.join(HERE, "build_emi")
        RUN = os.path.join(HERE, "run", "emi")
        LOGS = os.path.join(HERE, "logs", "emi")
        EXPECTED = os.path.join(HERE, "expected", "emi_original.log")
        UNSTABLE = os.path.join(HERE, "expected", "emi_unstable.txt")
        CRASHERS = os.path.join(HERE, "expected", "emi_crashers.txt")


def test_games(path):
    """The games a test file runs on: "-- games: grim emi" at the end of a line near its top (the first line, so that no line number
    of the file changes: some results hold them), grim when it has none."""
    with open(path, encoding="latin-1") as f:
        m = re.search(r"-- games:([a-z ]+?)\s*$", f.read(4000), re.M)
    return m.group(1).split() if m else ["grim"]


def test_files():
    """The test files of the current game."""
    return sorted(f for f in os.listdir(TESTS) if f.endswith(".lua") and GAME in test_games(os.path.join(TESTS, f)))


MINGW32 = r"C:\msys64\mingw32\bin"
UCRT64 = r"C:\msys64\ucrt64\bin"


MANIFEST = "cr_manifest.txt"
MARKER = "grimtestdata.txt"
LUA31 = os.path.join(ROOT, "autorun", "tools", "lua31")


def lint():
    """Parses every Lua file with the game's own Lua 3.1 (autorun/tools/lua31, which loads LUA.DLL): a file that does not
    parse would only drop its tests on the engines, with one ERROR line at the start. Skipped when the tool is missing."""
    exe = os.path.join(LUA31, "lua31.exe")
    dll = os.path.join(LUA31, "LUA.DLL")
    if not (os.path.exists(exe) and os.path.exists(dll)):
        return True
    stub = os.path.join(BUILD, "_lint_stub.lua")
    with open(stub, "wb") as f:
        f.write(b"cr_test = function(n, f) end\r\nseterrormethod = function(f) end\r\ndofile = function(f) end\r\n")
    files = [os.path.join(HERE, "lua", "_system.lua")] + sorted(
        os.path.join(HERE, "tests", t) for t in os.listdir(os.path.join(HERE, "tests")) if t.endswith(".lua"))
    ok = True
    for path in files:
        out = subprocess.run([exe, dll, stub, path], capture_output=True, text=True, cwd=LUA31, timeout=30)
        text = (out.stdout + out.stderr).strip()
        if "error" in text.lower() or "last token" in text:
            print("lint: %s does not parse:\n  %s" % (os.path.relpath(path, HERE), text.replace("\n", "\n  ")))
            ok = False
    os.remove(stub)
    return ok


def build(only=None, skip=()):
    """Writes the data as loose files into build/ (no archive: both engines read loose files from the game folder);
    returns the build folder. build/cr_manifest.txt lists them, so that a run folder can drop files of an older build."""
    # (Windows may hold a file of the folder for a moment after an engine that crashed: retry for a few seconds)
    for attempt in range(20):
        try:
            if os.path.isdir(BUILD):
                shutil.rmtree(BUILD)
            os.makedirs(BUILD)
            break
        except OSError:
            if attempt == 19:
                raise
            time.sleep(0.5)
    # (each game's own formats: assets.py for Grim, assets_emi.py for EMI)
    if GAME == "grim":
        files = assets.files()
        files.update(assets.loose_files())
    else:
        files = assets_emi.files()
    tests = test_files()
    head = "-- GENERATED by run.py, do not edit\nCR_GAME = \"%s\"\n" % GAME
    if only:
        head += "CR_ONLY = { }\n" + "".join('CR_ONLY["%s"] = 1\n' % n for n in only.split(","))
    # (tests that crash or hang an engine: the runner writes SKIP for them)
    head += "CR_SKIP = { }\n" + "".join('CR_SKIP["%s"] = 1\n' % n for n in sorted(skip))
    files["_cr_tests.lua"] = formats.lua_text(head + "".join('dofile("cr_%s")\n' % t for t in tests))
    for t in tests:
        files["cr_" + t] = formats.lua_text(open(os.path.join(HERE, "tests", t)).read())
    files["_system.lua"] = formats.lua_text(open(os.path.join(HERE, "lua", "_system.lua")).read())
    if GAME == "emi":
        # (ScummVM stops when there is no script.tab; the original reads its Lua from archives only)
        files["script.tab"] = formats.text_table_emi(assets.TEXT)
        files = {EMI_ARCHIVE: formats.lab_emi(files)}
        files[EMI_MARKER] = b"Escape from Monkey Island engine test data, see grim_tools/cleanroom/README.md\r\n"
    else:
        # (ScummVM detects the test data by this file)
        files[MARKER] = b"Grim engine test data, see grim_tools/cleanroom/README.md\r\n"
    files[MANIFEST] = ("\n".join(sorted(files) + [MANIFEST]) + "\n").encode("ascii")
    for name, data in files.items():
        with open(os.path.join(BUILD, name), "wb") as f:
            f.write(data)
    print("built %s: %d files, %d test files (%s)" % (BUILD, len(files), len(tests), GAME))
    return BUILD


def copy_data(dest):
    """Copies the build into a run folder, removing first the files of the build copied there before."""
    os.makedirs(dest, exist_ok=True)
    old = os.path.join(dest, MANIFEST)
    if os.path.exists(old):
        for name in open(old).read().split():
            p = os.path.join(dest, name)
            if os.path.isfile(p):
                os.remove(p)
    for f in os.listdir(BUILD):
        shutil.copyfile(os.path.join(BUILD, f), os.path.join(dest, f))


CRASHERS = os.path.join(HERE, "expected", "crashers.txt")


def read_lines(path):
    raw = open(path, "rb").read().decode("latin-1") if os.path.exists(path) else ""
    return compare.extract(raw)


def read_names(path):
    return set(l.strip() for l in open(path) if l.strip() and not l.startswith("#")) if os.path.exists(path) else set()


def unfinished(lines):
    """The test that was running when a run ended without SUMMARY (its BEGIN has no END or FAILED), or None."""
    cur = None
    for l in lines:
        w, _, rest = l.partition(" ")
        if w == "BEGIN":
            cur = rest
        elif w in ("END", "FAILED") and rest == cur:
            cur = None
    return cur


# The renderers of ScummVM's Grim engine (the "renderer" setting: Graphics::Renderer::parseTypeCode), all run each time
RENDERERS = [r for r in os.environ.get("CR_RENDERERS", "opengl,opengl_shaders,software").split(",") if r]
RENDERER = RENDERERS[0]


def svm_known():
    """The tests that crashed or hung ScummVM with the current renderer."""
    return os.path.join(LOGS, "scummvm_known_crashers_%s.txt" % RENDERER)


def run_engine(engine, only=None, fresh=False):
    """Runs an engine until the run reaches SUMMARY: a test that crashes or hangs it is skipped and the run is repeated.
    The original's crashers are kept in expected/crashers.txt (both engines skip them: there is no reference); ScummVM's are
    returned (bugs). Writes logs/<engine>.log; returns (lines, ScummVM's crashers)."""
    skip = read_names(CRASHERS)
    known = set() if fresh or engine != "scummvm" else read_names(svm_known()) - skip
    skip |= known
    new = []
    once = {"original": original_once, "remastered": remastered_once}.get(engine, scummvm_once)
    lines = []
    suspect = None
    for _ in range(400):
        build(only, skip)
        if not lint():
            sys.exit(2)
        snaps.clear(os.path.join(RUN, engine))
        lines = snaps.resolve(once(), os.path.join(RUN, engine))
        if any(l.startswith("SUMMARY") for l in lines):
            break
        name = unfinished(lines)
        if not name:
            print("%s: the run ended without SUMMARY and no test was running; see logs/%s_raw.log" % (engine, engine))
            break
        # (a test is skipped only when the run dies in it twice in a row: the original also crashes now and then by itself)
        if name != suspect:
            print("%s: the run died in %s; run again to confirm" % (engine, name))
            suspect = name
            continue
        print("%s: %s crashed or hung the engine twice; skipped, run again" % (engine, name))
        group = [name]
        # (the valid call of a builtin crashes: every call that changes one position of it is skipped with it)
        m = re.match(r"^(args_.+)_p0$", name)
        if m:
            text = "".join(open(os.path.join(TESTS, t)).read() for t in test_files() if t.startswith("zz_args"))
            group += sorted(set(re.findall(r'cr_test\("(%s_p[1-9][0-9]*_[a-z]+)"' % re.escape(m.group(1)), text)))
            print("%s: and the %d calls of its positions" % (engine, len(group) - 1))
        skip.update(group)
        new.extend(group)
        suspect = None
    if engine == "original" and new:
        with open(CRASHERS, "w", newline="\n") as f:
            f.write("# tests that crash the original (found by run.py); skipped on both engines\n")
            f.write("".join(n + "\n" for n in sorted(skip)))
    os.makedirs(LOGS, exist_ok=True)
    out = os.path.join(LOGS, engine + ".log")
    with open(out, "w", newline="\n") as f:
        f.write("\n".join(lines) + "\n")
    print("%s: %d result lines in %s" % (engine, len(lines), out))
    if engine == "scummvm":
        with open(svm_known(), "w", newline="\n") as f:
            f.write("".join(n + "\n" for n in sorted(known | set(new))))
    return lines, (sorted(known) + new if engine == "scummvm" else [])


def compare_with(reference, engine, crashed):
    rc = compare.main([reference, os.path.join(LOGS, engine + ".log"), "--unstable", UNSTABLE])
    with open(os.path.join(LOGS, "scummvm_crashers_%s.txt" % RENDERER), "w") as f:
        f.write("".join(n + "\n" for n in crashed))
    if crashed:
        print("crashed or hung ScummVM (a bug): %s" % ", ".join(crashed))
        rc = 1
    return rc


# ---- out of sight

# The engines run on a desktop of their own (tools/offscreen.c): their windows do not open on the screen and cannot take the
# focus. They draw as before (OpenGL, DirectDraw). CR_VISIBLE=1 runs them on the user's desktop.
VISIBLE = os.environ.get("CR_VISIBLE") == "1"
OFFSCREEN = os.path.join(HERE, "run", "offscreen.exe")


def offscreen(cmd):
    """The command, started through offscreen.exe (built from tools/offscreen.c when older than it)."""
    if VISIBLE:
        return cmd
    src = os.path.join(HERE, "tools", "offscreen.c")
    if not newer(OFFSCREEN, [src]):
        os.makedirs(os.path.dirname(OFFSCREEN), exist_ok=True)
        env = dict(os.environ, PATH=UCRT64 + os.pathsep + os.environ.get("PATH", ""))
        subprocess.run([os.path.join(UCRT64, "gcc.exe"), "-O2", "-o", OFFSCREEN, src], check=True, env=env)
        print("built %s" % OFFSCREEN)
    return [OFFSCREEN] + cmd


# ---- ScummVM

STALL = int(os.environ.get("CR_STALL", "15"))


def scummvm_once():
    """One ScummVM run; returns the CR lines. The log is ScummVM's --logfile, which is written line by line (its stdout is
    buffered and lost when the process is killed). A run that writes nothing for CR_STALL seconds (a Lua error() opens
    ScummVM's debugger and waits) is killed."""
    d = os.path.join(RUN, "scummvm")
    copy_data(d)
    ini = os.path.join(d, "scummvm.ini")
    saves = os.path.join(d, "saves")
    os.makedirs(saves, exist_ok=True)
    with open(ini, "w") as f:
        f.write("[scummvm]\nconfirm_exit=false\nfullscreen=false\ngfx_mode=opengl\n"
                # (no first-run question about update checks: it would wait for a click)
                "updates_check=0\n\n"
                "[cleanroom]\ngameid=%s\nengineid=grim\ndescription=%s engine test data, renderer %s\nextra=Test data\n"
                "path=%s\\\nlanguage=en\nplatform=windows\ncheck_gamedata=false\nfullscreen=false\n"
                "speech_mute=true\nsim_frame_ms=17\nrenderer=%s\n" % ("monkey4" if GAME == "emi" else "grim",
                                                                    "EMI" if GAME == "emi" else "Grim", RENDERER, d, RENDERER))
    raw = os.path.join(LOGS, "scummvm_raw.log")
    os.makedirs(LOGS, exist_ok=True)
    if os.path.exists(raw):
        os.remove(raw)
    env = dict(os.environ, PATH=UCRT64 + os.pathsep + os.environ.get("PATH", ""))
    cmd = [SCUMMVM, "--config=" + ini, "--savepath=" + saves, "--debugflags=scripts", "--logfile=" + raw]
    # (--sim-fps, a fixed 17 ms a frame like the original's simtime patch, is in the autorun branches only; without it the
    # frame times are the real ones and what is measured per frame differs run to run)
    helptext = subprocess.run([SCUMMVM, "--help"], capture_output=True, text=True, env=env).stdout
    if "--sim-fps" in helptext:
        cmd += ["--sim-fps=60", "--engine-speed=0"]
    else:
        print("scummvm: this build has no --sim-fps: frame times are real, per-frame values will not match the original")
    cmd.append("cleanroom")
    t = time.time()
    p = subprocess.Popen(offscreen(cmd), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, env=env, cwd=d)
    size, last = -1, time.time()
    while p.poll() is None:
        time.sleep(0.3)
        n = os.path.getsize(raw) if os.path.exists(raw) else 0
        if n != size:
            size, last = n, time.time()
        if time.time() - last > STALL or time.time() - t > TIMEOUT:
            p.kill()
            p.wait()
            print("scummvm: killed (%s)" % ("no log for %d s" % STALL if time.time() - t <= TIMEOUT else "timeout"))
            break
    print("scummvm: %.1f s" % (time.time() - t))
    return read_lines(raw)


# ---- the original

def game_processes():
    """(pid, folder) of every running GRIMFANDANGO.exe (EMI: Monkey4.exe)."""
    name = "Monkey4" if GAME == "emi" else "GRIMFANDANGO"
    out = subprocess.run(["powershell", "-NoProfile", "-Command",
                          "Get-Process " + name + " -ErrorAction SilentlyContinue | ForEach-Object { \"$($_.Id)|$($_.Path)\" }"],
                         capture_output=True, text=True).stdout
    procs = []
    for l in out.splitlines():
        pid, _, path = l.strip().partition("|")
        if pid.isdigit():
            procs.append((pid, os.path.normcase(os.path.dirname(path)) if path else ""))
    return procs


def original_running():
    """A GRIMFANDANGO.exe of the install is running (maybe a game being played): a run is not started then. Copies elsewhere
    (other tools' builds) are left alone; leftovers of our own run folder are stopped by original_once."""
    install = os.path.normcase(os.path.normpath(os.path.abspath(EMI_INSTALL if GAME == "emi" else GRIM_INSTALL)))
    return any(folder == install for _, folder in game_processes())


def newer(target, sources):
    return os.path.exists(target) and all(os.path.getmtime(target) >= os.path.getmtime(s) for s in sources)


def prepare_tools(d):
    """patch.dll and grimlaunch.exe, built from the sources of this repository (an old grimlaunch.exe lacks the windowed patch
    and takes the whole screen), when they are older than the sources."""
    pdir = os.path.join(ROOT, "launcher")
    dll_src = [os.path.join(pdir, "patch.c"), os.path.join(pdir, "config.c")]
    dll = os.path.join(d, "patch.dll")
    if not newer(dll, dll_src):
        env = dict(os.environ, PATH=MINGW32 + os.pathsep + os.environ.get("PATH", ""))
        subprocess.run([os.path.join(MINGW32, "gcc.exe"), "-shared", "-O2", "-static-libgcc", "-o", dll] + dll_src +
                       ["-luser32", "-lgdi32", "-lwinmm"], check=True, env=env)
        print("original: built patch.dll")
    launcher_src = [os.path.join(pdir, "grimlaunch.cpp")]
    launcher = os.path.join(d, "grimlaunch.exe")
    if not newer(launcher, launcher_src):
        env = dict(os.environ, PATH=UCRT64 + os.pathsep + os.environ.get("PATH", ""))
        subprocess.run([os.path.join(UCRT64, "g++.exe"), "-O2", "-static", "-o", launcher] + launcher_src, check=True, env=env)
        print("original: built grimlaunch.exe")


def prepare_original(d):
    """The run folder of the original: the program files from the install, the tools, grim.ini pointing at the folder itself,
    the data."""
    os.makedirs(d, exist_ok=True)
    for f in PROGRAM_FILES:
        dst = os.path.join(d, f)
        if not os.path.exists(dst):
            src = os.path.join(GRIM_INSTALL, f)
            if not os.path.exists(src):
                sys.exit("original: %s is missing (set GRIM_INSTALL to the folder of GRIMFANDANGO.exe)" % src)
            shutil.copyfile(src, dst)
    prepare_tools(d)
    # good_times skips the CD check (Grim_Init); the display values are the ones the install uses
    with open(os.path.join(d, "grim.ini"), "w", newline="\r\n") as f:
        f.write("[Grim]\nGrimDataDir=%s\\\ngood_times=TRUE\nTextAllowed=true\nExperimentalDisplay=0\n"
                "Last3DDevice=hex:00000000000000000000000000000000\n"
                "LastDisplayDevice=hex:009fa692fa13d11197c000a024293005\n" % d)
    copy_data(d)


def prepare_emi(d):
    """The run folder of the original EMI: the program files from the install, the tools, the data. grimlaunch points the game's
    data folder at the run folder (datadir) and skips the disc check (nocd)."""
    os.makedirs(d, exist_ok=True)
    for f in EMI_PROGRAM_FILES:
        dst = os.path.join(d, f)
        if not os.path.exists(dst):
            src = os.path.join(EMI_INSTALL, f)
            if not os.path.exists(src):
                sys.exit("original: %s is missing (set EMI_INSTALL to the folder of Monkey4.exe)" % src)
            shutil.copyfile(src, dst)
    prepare_tools(d)
    copy_data(d)


def kill_own_original(d):
    """Stops the GRIMFANDANGO.exe processes started from the run folder d (by their path)."""
    mine = os.path.normcase(os.path.normpath(os.path.abspath(d)))
    for pid, folder in game_processes():
        if folder == mine:
            subprocess.run(["taskkill", "/F", "/PID", pid], capture_output=True)


def prepare_remastered(d):
    """The run folder of the Remastered: its exe and dlls, the tools, the data. It has no grim.ini (no registry settings)."""
    os.makedirs(d, exist_ok=True)
    for f in REMASTERED_FILES:
        dst = os.path.join(d, f)
        if not os.path.exists(dst):
            src = os.path.join(REMASTERED_INSTALL, f)
            if not os.path.exists(src):
                sys.exit("remastered: %s is missing (set REMASTERED_INSTALL to the folder of its GrimFandango.exe)" % src)
            if os.path.isdir(src):
                shutil.copytree(src, dst)
            else:
                shutil.copyfile(src, dst)
    prepare_tools(d)
    copy_data(d)


def remastered_once():
    return original_once("remastered")


def original_once(which="original"):
    """One run of the original (or the Remastered); returns the CR lines."""
    exe = "GrimFandango.exe" if which == "remastered" else "Monkey4.exe" if GAME == "emi" else "GRIMFANDANGO.exe"
    if which == "original" and original_running():
        sys.exit("original: the %s of %s is running (maybe a game being played); not started" %
                 (exe, EMI_INSTALL if GAME == "emi" else GRIM_INSTALL))
    d = os.path.join(RUN, which)
    kill_own_original(d)
    (prepare_remastered if which == "remastered" else prepare_emi if GAME == "emi" else prepare_original)(d)
    log = os.path.join(d, "grimdebug.log")
    if os.path.exists(log):
        os.remove(log)
    t = time.time()
    # (EMI's Direct3D does not start on a desktop of its own: its window opens on the user's, off the screen, without the focus)
    launch = [os.path.join(d, "grimlaunch.exe")] + (["--with", "offscreen"] if GAME == "emi" and not VISIBLE else []) + [exe]
    p = subprocess.Popen(launch if GAME == "emi" else offscreen(launch), cwd=d, stdout=subprocess.DEVNULL,
                         stderr=subprocess.DEVNULL, env=dict(os.environ, GRIM_INI=os.path.join(d, "grim.ini")))
    # (a run that writes nothing to grimdebug.log for CR_STALL seconds hangs: it is killed, and so is every game started from
    # our run folder; copies elsewhere, a game being played or other tools' builds, are not touched)
    size, last = -1, time.time()
    while p.poll() is None:
        time.sleep(0.2)
        n = os.path.getsize(log) if os.path.exists(log) else 0
        if n != size:
            size, last = n, time.time()
        if time.time() - last > STALL or time.time() - t > TIMEOUT:
            print("original: killed (%s)" % ("no log for %d s" % STALL if time.time() - t <= TIMEOUT else "timeout"))
            kill_own_original(d)
            p.kill()
            break
    print("%s: %.1f s" % (which, time.time() - t))
    if os.path.exists(log):
        os.makedirs(LOGS, exist_ok=True)
        shutil.copyfile(log, os.path.join(LOGS, which + "_raw.log"))
    return read_lines(log)


def test_of(line):
    """The test a line of a result log is about (None for START and SUMMARY)."""
    parts = line.split(" ", 1)
    if len(parts) < 2 or parts[0] in ("START", "SUMMARY"):
        return None
    return parts[1].split("|")[0].split(" ")[0]


def renderer_diff(r0, r1):
    """Prints the tests whose values differ between two renderers' runs (beyond 1e-6)."""
    def load(r):
        return compare.parse(open(os.path.join(LOGS, "scummvm_%s.log" % r), encoding="latin-1").read().splitlines())[1]
    t0, t1 = load(r0), load(r1)
    unstable = compare.load_unstable(UNSTABLE)
    diff = [n for n in t0 if n in t1 and
            compare.diff_values(t0[n]["values"], t1[n]["values"], 1e-6, n, unstable, 1e-3)]
    print("---- %s against %s: %d of %d tests differ%s" % (r1, r0, len(diff), len(t0), (": " + ", ".join(diff[:40]) +
                                                                                       (" ..." if len(diff) > 40 else "")) if diff else ""))


def run_scummvm_all(reference, only, fresh, renderers):
    """Runs the tests on ScummVM once with each renderer and compares each run with the reference; the logs of each are
    kept as logs/scummvm_<renderer>.log and _raw.log. Returns 0 when every renderer matches."""
    global RENDERER
    rcs = []
    for r in renderers:
        RENDERER = r
        print("==== scummvm, renderer %s" % r)
        _, crashed = run_engine("scummvm", only, fresh)
        for suffix in (".log", "_raw.log"):
            src = os.path.join(LOGS, "scummvm" + suffix)
            if os.path.exists(src):
                shutil.copyfile(src, os.path.join(LOGS, "scummvm_%s%s" % (r, suffix)))
        rcs.append((r, compare_with(reference, "scummvm", crashed)))
        # (what the reference has that this renderer gives differently, against the first renderer: a difference between
        # the renderers themselves)
        if r != renderers[0]:
            renderer_diff(renderers[0], r)
    for suffix in (".log", "_raw.log"):
        src = os.path.join(LOGS, "scummvm_%s%s" % (renderers[0], suffix))
        if os.path.exists(src):
            shutil.copyfile(src, os.path.join(LOGS, "scummvm" + suffix))
    RENDERER = renderers[0]
    print("==== scummvm renderers: " + ", ".join("%s %s" % (r, "same" if rc == 0 else "differs") for r, rc in rcs))
    return max(rc for _, rc in rcs) if rcs else 0


def lock_folder():
    """Waits until no other run.py works in this folder (they share build/, run/ and logs/: two at once spoil each other's
    runs), then holds the lock until this process ends (Windows releases it when the process dies)."""
    import msvcrt
    os.makedirs(LOGS, exist_ok=True)
    f = open(os.path.join(LOGS, "run.lock"), "a+")
    warned = False
    while True:
        try:
            f.seek(0)
            msvcrt.locking(f.fileno(), msvcrt.LK_NBLCK, 1)
            return f
        except OSError:
            if not warned:
                print("run.py: another run.py is running in this folder; waiting for it", flush=True)
                warned = True
            time.sleep(2)


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "compare":
        return compare.main(sys.argv[2:])
    _lock = lock_folder()  # noqa: F841 (held until the process ends)
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("what", choices=["build", "scummvm", "original", "remastered", "both", "compare"])
    ap.add_argument("logs", nargs="*")
    ap.add_argument("--only", help="run one test")
    ap.add_argument("--save", action="store_true", help="original: the run becomes expected/original.log")
    ap.add_argument("--repeat", type=int, default=3, help="original --save: runs, to find the unstable values")
    ap.add_argument("--renderer", help="scummvm: only these renderers (comma separated; default: %s)" % ",".join(RENDERERS))
    ap.add_argument("--game", choices=["grim", "emi"], default="grim", help="the game whose engine is tested (default grim)")
    ap.add_argument("--fresh", action="store_true",
                    help="scummvm: run the tests that crashed or hung ScummVM before again (logs/scummvm_known_crashers.txt)")
    a = ap.parse_args()
    set_game(a.game)
    if a.game == "emi" and a.what == "remastered":
        sys.exit("the Remastered is Grim's")
    if a.what == "compare":
        return compare.main(a.logs)
    if a.what == "build":
        build(a.only, read_names(CRASHERS))
        return 0 if lint() else 2
    renderers = a.renderer.split(",") if a.renderer else RENDERERS
    if a.what == "scummvm":
        return run_scummvm_all(EXPECTED, a.only, a.fresh, renderers)
    if a.what == "original" and a.save:
        # (the reference must repeat itself: the values that differ between runs are kept in unstable.txt and not compared)
        runs = []
        for i in range(a.repeat):
            run_engine("original", a.only)
            path = os.path.join(LOGS, "original_%d.log" % (i + 1))
            shutil.copyfile(os.path.join(LOGS, "original.log"), path)
            runs.append(compare.parse(open(path).read().splitlines()))
        unstable = sorted(compare.unstable_keys(runs))
        os.makedirs(os.path.dirname(EXPECTED), exist_ok=True)
        if a.only and os.path.exists(EXPECTED):
            # (--only: the tests run replace theirs in the expected log, the others stay)
            new = open(os.path.join(LOGS, "original.log")).read().splitlines()
            ran = set(test_of(l) for l in new) - {None}
            old = [l for l in open(EXPECTED).read().splitlines() if test_of(l) not in ran]
            end = [l for l in old if test_of(l) is None and not l.startswith("START")]
            old = [l for l in old if l not in end]
            with open(EXPECTED, "w", newline="\n") as f:
                f.write("".join(l + "\n" for l in old + [l for l in new if test_of(l) is not None] + end))
            unstable = sorted(set(unstable) | set(k for k in read_names(UNSTABLE) if k.split("|")[0] not in ran))
        else:
            shutil.copyfile(os.path.join(LOGS, "original.log"), EXPECTED)
        with open(UNSTABLE, "w", newline="\n") as f:
            f.write("# test|key values that differed between %d runs of the original; not compared\n" % a.repeat)
            f.write("".join(k + "\n" for k in unstable))
        print("saved %s (%d unstable values: %s)" % (EXPECTED, len(unstable), ", ".join(unstable) or "none"))
        return 0
    if a.what == "remastered":
        run_engine("remastered", a.only)
        return compare.main([EXPECTED, os.path.join(LOGS, "remastered.log"), "--unstable", UNSTABLE])
    if a.what == "original":
        run_engine("original", a.only)
        return compare.main([EXPECTED, os.path.join(LOGS, "original.log"), "--unstable", UNSTABLE])
    run_engine("original", a.only)
    shutil.copyfile(os.path.join(LOGS, "original.log"), os.path.join(LOGS, "original_both.log"))
    return run_scummvm_all(os.path.join(LOGS, "original_both.log"), a.only, a.fresh, renderers)

if __name__ == "__main__":
    sys.exit(main())
