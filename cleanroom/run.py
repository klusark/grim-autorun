"""Clean-room engine tests: our own data (Lua, sets, bitmaps, text) run on ScummVM and on the original v1.01 exe, with no
file of the game's data. See README.md.

  python run.py build                      writes the data into build/ (loose files)
  python run.py scummvm [--only T1,T2]     runs ScummVM with each of its renderers, compares each with expected/original.log
                   [--renderer R,R]        only these renderers (opengl, opengl_shaders, software; CR_RENDERERS too)
  python run.py original [--only T]        runs the original exe through grimlaunch.exe, compares with the expected log
  python run.py original --save            ... and makes the whole run the new expected log (never a part of it)
  python run.py remastered [--only T]      runs the Grim Fandango Remastered exe (debuglog patch only), compares with the expected log
  python run.py decomp [--only T]          runs the rebuilt exe of grim-decomp (its own test knobs, no grimlaunch.exe), compares
                                           with the expected log
  python run.py both                      both engines, compared with each other
  python run.py compare A.log B.log        compares two result logs
  python run.py <command> --work DIR       its own build/, run/ and logs/ in DIR, locked on its own, and nothing written to
                                           expected/ (the crashers it finds are reported only): runs in parallel with
                                           others, each with its own DIR (--save is refused)
  python run.py <command> --game emi       the same for Escape from Monkey Island: the original Monkey4.exe v1.1 (through
                                           grimlaunch.exe) and ScummVM's EMI; the test files of tests/common/ and tests/emi/

The test files are in tests/common/ (both games), tests/grim/ and tests/emi/ (testfiles.py). Each game's original
is its own reference: expected/original.log for Grim, expected/emi_original.log for EMI. The EMI runs keep their files in
build_emi/, run/emi/ and logs/emi/; its data go into one archive, local.m4b (the original reads no loose Lua). The Lua global
CR_GAME is "grim" or "emi".

Every engine runs each test file in a game of its own (CR_FILE), as many games at a time as there are processors (CR_GAMES
sets another number), each in a run folder of its own (run/<engine>_<k>) that is reset before every game. Grim's original is
started with grimlaunch's multi, smushtime and imusetime patches: movies and sound go by game time, and the tests wait in
frames. A test that crashes or hangs an engine is found and skipped (README.md): only its file goes on, in a new game, from the
test after it. ScummVM's are kept in
expected/scummvm_crashers_<renderer>.txt and the Remastered's in expected/remastered_crashers.txt (committed), skipped and
reported on the next runs; --fresh runs them again (the original's too) and rewrites the list (the ones that no longer crash drop out).

ScummVM runs every test once with each renderer of Grim (RENDERERS: OpenGL, OpenGL with shaders, the software TinyGL):
logs/scummvm_<renderer>.log and logs/scummvm_<renderer>_raw.log; logs/scummvm.log is the first renderer's.

Results go to logs/<engine>.log (only the CR lines, normalised) and logs/<engine>_raw.log (the whole engine log).
Environment: SCUMMVM (scummvm.exe), GRIM_INSTALL (the folder the original exe and its DLLs are copied from by
`run.py original`; `run.py decomp` does not use it; default
C:\\GOG Games\\GRIMDATA), CR_VISIBLE=1 (the engines' windows on the screen; otherwise they run on a desktop of their own,
tools/offscreen.c), CR_VERBOSE=1 (or --verbose: each game's command line, its tests as they begin and end, how it ended),
EMI_INSTALL (the same for Monkey4.exe, default C:\\GOG Games\\Escape from Monkey Island), CR_STALL
(seconds without a new line in the engine's log before a run counts as hung and is killed, default 2; CR_STARTUP, default 30, until the first line),
GRIM_DECOMP (the folder of the rebuilt grimfandango.exe and its three DLLs, default C:\\Users\\Joel\\grim-decomp\\build\\run)."""
import argparse
import os
import re
import shutil
import subprocess
import sys
import threading
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "tools"))
import assets  # noqa: E402
import assets_emi  # noqa: E402
import formats  # noqa: E402
import compare  # noqa: E402
import snaps  # noqa: E402
import testfiles  # noqa: E402

ROOT = os.path.dirname(HERE)
WORK = HERE   # (where build/, run/ and logs/ are: --work DIR moves them)
READ_ONLY = False   # (--work: expected/ is not written)
BUILD = os.path.join(WORK, "build")
RUN = os.path.join(WORK, "run")
LOGS = os.path.join(WORK, "logs")
EXPECTED = os.path.join(HERE, "expected", "original.log")
UNSTABLE = os.path.join(HERE, "expected", "unstable.txt")
# (a build with scummvm/grim-test-data.patch: scummvm/build.sh makes it in ~/scummvm-cleanroom)
SCUMMVM = os.environ.get("SCUMMVM", r"C:\msys64\home\Joel\scummvm-cleanroom\build\scummvm.exe")
GRIM_INSTALL = os.environ.get("GRIM_INSTALL", r"C:\GOG Games\GRIMDATA")
REMASTERED_INSTALL = os.environ.get("REMASTERED_INSTALL", "C:/Program Files (x86)/Steam/steamapps/common/Grim Fandango Remastered")

# The program files of the original (not data): the exe, its DLLs and the HMI driver's HMILIBS.INI. (iMUSE's preset
# file IMUSE.PSL is test data now, assets.PRESET_LIBRARY, in every engine's run folder.)
PROGRAM_FILES = ["GRIMFANDANGO.exe", "LUA.DLL", "IMUSE.DLL", "CHORE.DLL", "NULLMUSE.DLL", "HMIFXFP.DLL", "HMIFXLIB.DLL",
                 "HMILIBS.INI", "grimdlg.dll"]
# The rebuilt exe of grim-decomp (build/run after `make -C build link`): these four come from GRIM_DECOMP and are all of
# its program files (nothing from GRIM_INSTALL). Its test patches are build/cleanroom/ of that repository (README.md there).
GRIM_DECOMP = os.environ.get("GRIM_DECOMP", r"C:\Users\Joel\grim-decomp\build\run")
DECOMP_FILES = {"GRIMFANDANGO.exe": "grimfandango.exe", "LUA.DLL": "lua.dll", "IMUSE.DLL": "imuse.dll", "CHORE.DLL": "chore.dll"}
# The Remastered: the exe and the dlls it loads (the game's data are not copied; the Lua is the same 3.1)
REMASTERED_FILES = ["GrimFandango.exe", "Lua.dll", "SDL2.dll", "chore.dll", "steam_api.dll", "controllerdef.txt", "icon.png", "x86"]   # (x86: the shaders)
# EMI's: the exe, the Miles sound dlls and filters, Bink (no .m4b, no movie)
EMI_INSTALL = os.environ.get("EMI_INSTALL", r"C:\GOG Games\Escape from Monkey Island")
EMI_PROGRAM_FILES = ["Monkey4.exe", "Mss32.dll", "binkw32.dll", "Mp3dec.asi", "Chorus.flt", "Reverb3.flt", "Sdelay.flt"]
EMI_ARCHIVE = "local.m4b"
EMI_MARKER = "emitestdata.txt"
GAME = "grim"
# ScummVM in the Remastered's mode (scummvm --remastered): the same data with another marker (the test patch's entry with
# ADGF_REMASTERED), the Remastered's text table and commentary file, folders of its own
REMASTERED_MARKER = "grimremasteredtestdata.txt"
SVM_REMASTERED = False


def set_remastered():
    """Points the build, run and log folders at ScummVM's Remastered mode (its crashers: expected/remastered_scummvm_...)."""
    global SVM_REMASTERED, BUILD, RUN, LOGS
    SVM_REMASTERED = True
    BUILD = os.path.join(WORK, "build_remastered")
    RUN = os.path.join(WORK, "run", "remastered_scummvm")
    LOGS = os.path.join(WORK, "logs", "remastered_scummvm")


def set_work(d):
    """--work: build/, run/ and logs/ in d, and expected/ is only read (the crashers found are not kept)."""
    global WORK, READ_ONLY, BUILD, RUN, LOGS
    WORK = os.path.abspath(d)
    READ_ONLY = True
    BUILD = os.path.join(WORK, "build")
    RUN = os.path.join(WORK, "run")
    LOGS = os.path.join(WORK, "logs")


def set_game(game):
    """Points the folders and the expected files at one game's (Grim's are the top ones, EMI's are beside them)."""
    global GAME, BUILD, RUN, LOGS, EXPECTED, UNSTABLE, CRASHERS
    GAME = game
    if game == "emi":
        BUILD = os.path.join(WORK, "build_emi")
        RUN = os.path.join(WORK, "run", "emi")
        LOGS = os.path.join(WORK, "logs", "emi")
        EXPECTED = os.path.join(HERE, "expected", "emi_original.log")
        UNSTABLE = os.path.join(HERE, "expected", "emi_unstable.txt")
        CRASHERS = os.path.join(HERE, "expected", "emi_crashers.txt")


def test_files():
    """The test files of the current game (their paths), in the order they run."""
    return testfiles.files(GAME)


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
        f.write(b"cr_test = function(n, f) end\r\ncr_scummvm_differs = function(n, w, g) end\r\nseterrormethod = function(f) end\r\ndofile = function(f) end\r\n")
    # (the files of the game that runs: one of the other game's cannot stop its run)
    files = [os.path.join(HERE, "lua", "_system.lua")] + test_files()
    ok = True
    for path in files:
        out = subprocess.run([exe, dll, stub, path], capture_output=True, text=True, cwd=LUA31, timeout=30)
        text = (out.stdout + out.stderr).strip()
        if "error" in text.lower() or "last token" in text:
            print("lint: %s does not parse:\n  %s" % (os.path.relpath(path, HERE), text.replace("\n", "\n  ")))
            ok = False
    os.remove(stub)
    return ok


def cr_tests_lua(only=None, skip=(), start=None, fails=0, file=None):
    """The text of _cr_tests.lua: the run's switches (CR_ONLY, CR_FROM, CR_SKIP, and CR_FILE: only the tests of that test
    file), then every test file (CR_LOADING names the file being read, so that each test knows its file)."""
    head = "-- GENERATED by run.py, do not edit\nCR_GAME = \"%s\"\n" % GAME
    if only:
        head += "CR_ONLY = { }\n" + "".join('CR_ONLY["%s"] = 1\n' % n for n in only.split(","))
    # (tests that crash or hang an engine: the runner writes SKIP for them)
    if start:
        head += 'CR_FROM = "%s"\nCR_FAILS0 = %d\n' % (start, fails)
    if file:
        head += 'CR_FILE = "%s"\n' % file
    head += "CR_SKIP = { }\n" + "".join('CR_SKIP["%s"] = 1\n' % n for n in sorted(skip))
    return formats.lua_text(head + "".join('CR_LOADING = "%s"\ndofile("cr_%s")\n' % ((os.path.basename(t),) * 2)
                                           for t in test_files()))


def build(only=None, skip=(), start=None, fails=0):
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
    files["_cr_tests.lua"] = cr_tests_lua(only, skip, start, fails)
    for t in tests:
        files["cr_" + os.path.basename(t)] = formats.lua_text(open(t).read())
    files["_system.lua"] = formats.lua_text(open(os.path.join(HERE, "lua", "_system.lua")).read())
    if GAME == "emi":
        # (ScummVM stops when there is no script.tab; the original reads its Lua from archives only)
        files["script.tab"] = formats.text_table_emi(assets.TEXT)
        # (kept: each game of a run gets the archive again with its own _cr_tests.lua, Engine.put_tests)
        global ARCHIVE_FILES
        ARCHIVE_FILES = dict(files)
        files = {EMI_ARCHIVE: formats.lab_emi(files)}
        # (outside the archive: the movies, which both engines open as files of Movies/)
        files.update(assets_emi.loose_files())
        files[EMI_MARKER] = b"Escape from Monkey Island engine test data, see grim_tools/cleanroom/README.md\r\n"
    else:
        # (ScummVM detects the test data by this file; in the Remastered's mode by another, with the Remastered's text table
        # (grim.en.tab) and commentary list)
        files[REMASTERED_MARKER if SVM_REMASTERED else MARKER] = b"Grim engine test data, see grim_tools/cleanroom/README.md\r\n"
        if SVM_REMASTERED:
            files["grim.en.tab"] = formats.text_table_remastered(assets.TEXT)
            files["commentary_def.txt"] = formats.commentary_def(assets.COMMENTARY)
    files[MANIFEST] = ("\n".join(sorted(files) + [MANIFEST]) + "\n").encode("ascii")
    for name, data in files.items():
        os.makedirs(os.path.dirname(os.path.join(BUILD, name)), exist_ok=True)
        with open(os.path.join(BUILD, name), "wb") as f:
            f.write(data)
    print("built %s: %d files, %d test files (%s)" % (BUILD, len(files), len(tests), GAME))
    return BUILD


def copy_data(dest):
    """Copies the build into a run folder, removing first the files of the build copied there before."""
    os.makedirs(dest, exist_ok=True)
    old = os.path.join(dest, MANIFEST)
    if os.path.exists(old):
        for name in open(old).read().splitlines():
            p = os.path.join(dest, name)
            if os.path.isfile(p):
                os.remove(p)
    for root, _, names in os.walk(BUILD):
        sub = os.path.relpath(root, BUILD)
        os.makedirs(os.path.join(dest, sub), exist_ok=True)
        for f in names:
            shutil.copyfile(os.path.join(root, f), os.path.join(dest, sub, f))


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
    prefix = "emi_" if GAME == "emi" else "remastered_" if SVM_REMASTERED else ""
    return os.path.join(HERE, "expected", "%sscummvm_crashers_%s.txt" % (prefix, RENDERER))


REM_CRASHERS = os.path.join(HERE, "expected", "remastered_crashers.txt")


def open_expected(path, newline="\n"):
    """Opens a file of expected/ to write, trying again for 10 s: on 2026-11-10 writes there failed now and then with
    OSError 22 (Invalid argument) and worked a moment later, which lost the end of a 20-minute --save."""
    for attempt in range(40):
        try:
            return open(path, "w", newline=newline)
        except OSError as e:
            if attempt == 39:
                raise
            if attempt == 0:
                print("run.py: cannot write %s (%s); trying again" % (path, e), flush=True)
            time.sleep(0.25)


def write_rem_known(names):
    """Keeps the Remastered's crashers in expected/ (committed), like ScummVM's: skipped on the next runs, --fresh tries them again."""
    if READ_ONLY:
        return
    os.makedirs(os.path.dirname(REM_CRASHERS), exist_ok=True)
    with open_expected(REM_CRASHERS) as f:
        f.write("# tests that crash or hang the Remastered (found by run.py); skipped, run.py remastered --fresh tries them again\n")
        f.write("".join(n + "\n" for n in sorted(names)))


def write_known(names):
    """Keeps ScummVM's crashers in expected/ (committed: they are not found again on each machine)."""
    if READ_ONLY:
        return
    os.makedirs(os.path.dirname(svm_known()), exist_ok=True)
    with open_expected(svm_known()) as f:
        f.write("# tests that crash or hang ScummVM (%s renderer; found by run.py); skipped, run.py --fresh tries them again\n" % RENDERER)
        f.write("".join(n + "\n" for n in sorted(names)))


ARCHIVE_FILES = {}   # EMI: the files of the archive of the last build (each game gets the archive with its own _cr_tests.lua)


def crash_backtrace(engine, game):
    """Why game (a GameRun of engine) died: hung, or the backtrace of its crash dump (or the rebuilt exe's crash report)."""
    exe = SCUMMVM if engine == "scummvm" else "Monkey4.exe" if GAME == "emi" else "GrimFandango.exe" if engine == "remastered" else "GRIMFANDANGO.exe"
    code = "?" if game.exit is None else "0x%X" % (game.exit & 0xFFFFFFFF)
    import crashstack
    if game.killed:
        return "hung: %s wrote nothing to its log for %g s and was killed by run.py (no crash, so no dump or backtrace)" % (os.path.basename(exe), game.killed)
    if engine == "decomp":
        # (the rebuilt exe writes no dump: its crash filter (build/startup.c) appends the exception, the registers and the top of
        # the stack to grim_crash_<GRIM_MULTI>.txt in its working folder; nm on the exe of the build names the addresses)
        reports = [os.path.join(game.folder, f) for f in os.listdir(game.folder) if f.startswith("grim_crash_")]
        reports = [r for r in reports if os.path.getmtime(r) >= game.start - 2]
        if reports:
            return "%s\n%s" % (reports[0], open(reports[0], "rb").read().decode("latin-1"))
        return "no crash report of the rebuilt exe since the game started (it ended by itself), exit code %s" % code
    # (the original and the Remastered write grimcrash.dmp next to their exe: patch.dll's crash filter; the others' dumps go to
    # CrashDumps under the exe's name, and with games side by side the newest one there may be another game's)
    own = os.path.join(game.folder, "grimcrash.dmp")
    note = ""
    if engine != "scummvm" and os.path.exists(own) and os.path.getmtime(own) >= game.start - 2:
        dump = own
    else:
        dump = crashstack.newest_dump(os.path.basename(exe), game.start - 2)
        note = " (the newest dump of %s since this game started: with games side by side it may be another game's)" % os.path.basename(exe)
    if not dump:
        return "no crash dump of %s since the game started (it died by itself and wrote no dump), exit code %s" % (os.path.basename(exe), code)
    try:
        if engine == "scummvm":
            trace = crashstack.backtrace(dump, exe)
        else:   # (the names of the exe's functions come from Ghidra: tools/export_ghidra_symbols.py)
            sym = "remastered" if engine == "remastered" else "emi" if GAME == "emi" else "grim"
            trace = crashstack.backtrace(dump, symbols_file=os.path.join(HERE, "tools", "symbols", sym + ".txt"), exe_name=os.path.basename(exe))
        return "%s%s\n%s" % (dump, note, trace)
    except Exception as e:   # (a dump that does not parse must not stop the run)
        return "%s: could not read the dump: %s" % (dump, e)


def keep_crash_log(engine, name, game):
    """Keeps the part of game's log that says why the test died (from 40 lines before its BEGIN to the end), with the backtrace,
    as logs/crashes/<engine>_<renderer>_<test>.log."""
    lines = game.raw.splitlines()
    at = max((i for i, l in enumerate(lines) if l.rstrip().endswith("CR BEGIN " + name)), default=0)
    d = os.path.join(LOGS, "crashes")
    os.makedirs(d, exist_ok=True)
    out = os.path.join(d, "%s_%s_%s.log" % (engine, RENDERER if engine == "scummvm" else "exe", name))
    with open(out, "w", newline="\n") as f:
        f.write("==== backtrace\n" + crash_backtrace(engine, game) + "\n\n==== log (from 40 lines before the test)\n")
        f.write("\n".join(lines[max(0, at - 40):]) + "\n")
    say("%s: why it died: %s" % (engine, out))


def crash_group(name):
    """The tests skipped with a crasher: itself, and when the valid call of a builtin crashes (args_<fn>_p0), every call that
    changes one position of it."""
    group = [name]
    m = re.match(r"^(args_.+)_p0$", name)
    if m:
        text = "".join(open(t).read() for t in test_files() if os.path.basename(t).startswith("zz_args"))
        group += sorted(set(re.findall(r'cr_test\("(%s_p[1-9][0-9]*_[a-z]+)"' % re.escape(m.group(1)), text)))
    return group


# ---- the engines, one game per test file, side by side
#
# Every engine runs each test file in a game of its own (CR_FILE), up to one game per processor at a time, each in a run folder
# of its own (run/<engine>_<k>), which is reset before every game (Engine.reset: nothing of the game that ran there before). A
# test that crashes or hangs its game is skipped and only that file goes on, in a new game, from the test after it.

_PRINT_LOCK = threading.Lock()


def say(*args):
    with _PRINT_LOCK:
        print(*args, flush=True)


# (--verbose or CR_VERBOSE=1: each game's command line and knobs, its tests as they begin and end, how it ended; every line
# starts with the seconds since run.py started and the run folder, e.g. "  12.3 scummvm_3 cr_menu.lua: ...")
VERBOSE = os.environ.get("CR_VERBOSE") == "1"
_T0 = time.time()


def trace(folder, file, msg):
    if VERBOSE:
        say("%7.1f %s %s: %s" % (time.time() - _T0, os.path.basename(folder), file, msg))


def reset_folder(d, keep):
    """Removes every file of the run folder d but the names in keep and the build's files (cr_manifest.txt)."""
    keep = set(n.lower() for n in keep) | {MANIFEST.lower()}
    manifest = os.path.join(d, MANIFEST)
    built = open(manifest).read().splitlines() if os.path.exists(manifest) else []
    keep |= set(n.replace("\\", "/").split("/")[0].lower() for n in built)
    for name in os.listdir(d):
        if name.lower() in keep:
            continue
        p = os.path.join(d, name)
        if os.path.isdir(p):
            shutil.rmtree(p, ignore_errors=True)
        else:
            try:
                os.remove(p)
            except OSError:
                pass


class Engine:
    """How run.py runs one engine's games: its run folders, what a game finds in its folder, how it is started."""
    name = ""
    keep = []   # the program files of a run folder (reset keeps them)
    games = None   # at most so many games at a time (None: one per processor)

    def folder(self, k):
        return os.path.join(RUN, "%s_%d" % (self.name, k))

    def prepare(self, d):
        """The run folder before its first game: program files, tools, the build."""
        os.makedirs(d, exist_ok=True)
        copy_data(d)

    def reset(self, d):
        """The run folder as before its first game."""
        reset_folder(d, self.keep)

    def put_tests(self, d, tests_lua):
        """The game's _cr_tests.lua; EMI's Lua is read from the archive only, so the archive is made again with it."""
        if GAME == "emi":
            with open(os.path.join(d, EMI_ARCHIVE), "wb") as f:
                f.write(formats.lab_emi(dict(ARCHIVE_FILES, **{"_cr_tests.lua": tests_lua})))
        else:
            with open(os.path.join(d, "_cr_tests.lua"), "wb") as f:
                f.write(tests_lua)

    def log(self, d):
        return os.path.join(d, "grimdebug.log")

    def command(self, d):
        """(command, environment) of a game in d."""
        raise NotImplementedError

    def kill(self, d):
        """Stops what is left of a game in d that was killed (offscreen.exe's job ends the rest)."""
        kill_own_original(d)


class OriginalEngine(Engine):
    """The original exe (Grim's v1.01, or EMI's Monkey4.exe) or the Remastered, through grimlaunch.exe."""
    def __init__(self, which):
        self.name = which
        self.remastered = which == "remastered"
        # (the Remastered draws every frame with OpenGL: from 6 games at a time some stop writing to their log for seconds and
        # are killed as hung; 4 at a time give the same results as one)
        self.games = 4 if self.remastered else None
        self.keep = (REMASTERED_FILES if self.remastered else EMI_PROGRAM_FILES if GAME == "emi" else PROGRAM_FILES + ["grim.ini"]) + \
            ["patch.dll", "grimlaunch.exe"]

    def prepare(self, d):
        (prepare_remastered if self.remastered else prepare_emi if GAME == "emi" else prepare_original)(d)

    def reset(self, d):
        reset_folder(d, self.keep)
        if not self.remastered and GAME == "grim":
            write_grim_ini(d)

    def command(self, d):
        exe = "GrimFandango.exe" if self.remastered else "Monkey4.exe" if GAME == "emi" else "GRIMFANDANGO.exe"
        # (more than one game at a time; Grim's original: the movies and the sound on game time (the tests wait in frames);
        # EMI's Direct3D does not start on a desktop of its own, its OpenGL renderer (-gl) does and gives the same values (only
        # GammaEnabled, what the hardware can do, differs, and it is not compared); CR_GRIMLAUNCH: more launcher options)
        speed = [] if self.remastered else ["--with", "multi,smushtime,imusetime" if GAME == "grim" else "multi"]
        cmd = [os.path.join(d, "grimlaunch.exe")] + speed + os.environ.get("CR_GRIMLAUNCH", "").split() + [exe] + \
            (["-gl"] if GAME == "emi" else [])
        return cmd, dict(os.environ, GRIM_INI=os.path.join(d, "grim.ini"))


class DecompEngine(Engine):
    """The rebuilt exe of grim-decomp, started directly, with the knobs of its build that do what grimlaunch's patches do to the
    original (grim-decomp/build/cleanroom/README.md)."""
    name = "decomp"
    keep = list(DECOMP_FILES) + ["grim.ini"]
    # (it crashes now and then by itself, a different test each run: about 10 crashes a run at 4 games at a time, 55 at 16, in the
    # same wall time)
    games = 4

    def prepare(self, d):
        prepare_decomp(d)

    def reset(self, d):
        reset_folder(d, self.keep)
        write_grim_ini(d)

    def command(self, d):
        log = self.log(d)
        env = dict(os.environ,
                   GRIM_INI=os.path.join(d, "grim.ini"),   # config: grim.ini, not the registry (whose GrimDataDir is the real game)
                   GRIM_DEBUGLOG=log,                      # debuglog, and the CRSNAP: screenshots
                   GRIM_SIMTIME="17",                      # simtime: every frame is 17 ms, iMUSE on game time too
                   GRIM_MULTI="%s_%s" % (DECOMP_TAG, os.path.basename(d)))   # (its own window title: games side by side)
        for k in ("GRIM_NOMOVIE", "GRIM_LUA_FILE", "GRIM_DISPLAY_DEVICE", "GRIM_MODS", "GRIM_WALK_SCALE", "GRIM_IMUSE_REALTIME"):
            env.pop(k, None)   # (knobs that change the run)
        # (-w: windowed, like the original's windowed patch; the rebuilt exe makes its window a window from the start)
        return [os.path.join(d, "GRIMFANDANGO.exe"), "-w"], env


class ScummvmEngine(Engine):
    """ScummVM with the current renderer (RENDERER). Its log is its --logfile, written line by line (its stdout is buffered
    and lost when the process is killed). Every frame is 17 ms, like the original's simtime patch (sim_frame_ms in the ini,
    grim-test-data.patch), and there is no frame limit."""
    name = "scummvm"
    keep = ["scummvm.ini"]

    def log(self, d):
        return os.path.join(d, "scummvm_raw.log")

    def reset(self, d):
        reset_folder(d, self.keep)
        os.makedirs(os.path.join(d, "saves"), exist_ok=True)
        with open(os.path.join(d, "scummvm.ini"), "w") as f:
            f.write("[scummvm]\nconfirm_exit=false\nfullscreen=false\ngfx_mode=opengl\n"
                    # (no first-run question about update checks: it would wait for a click)
                    "updates_check=0\n"
                    # (no waiting for the screen's refresh at each picture drawn: with it a run takes 5 times as long)
                    "vsync=false\n\n"
                    "[cleanroom]\ngameid=%s\nengineid=grim\ndescription=%s engine test data, renderer %s\nextra=Test data\n"
                    "path=%s%s\nlanguage=en\nplatform=windows\ncheck_gamedata=false\nfullscreen=false\n"
                    "speech_mute=true\nsim_frame_ms=17\nrenderer=%s\n%s" % ("monkey4" if GAME == "emi" else "grim",
                                                                        "EMI" if GAME == "emi" else "Grim", RENDERER, d, os.sep, RENDERER,
                                                                        # (CR_RENDER_EVERY=n: one frame in n is drawn, 0 only those that must be; the engine's default is 8)
                                                                        "sim_render_every=%s\n" % RENDER_EVERY if RENDER_EVERY else ""))

    def command(self, d):
        cmd = [SCUMMVM, "--config=" + os.path.join(d, "scummvm.ini"), "--savepath=" + os.path.join(d, "saves"),
               "--debugflags=scripts", "--logfile=" + self.log(d), "--engine-speed=0", "cleanroom"]
        return cmd, dict(os.environ, PATH=UCRT64 + os.pathsep + os.environ.get("PATH", ""))

    def kill(self, d):
        pass


def make_engine(engine):
    if engine == "scummvm":
        return ScummvmEngine()
    if engine == "decomp":
        return DecompEngine()
    return OriginalEngine(engine)


class GameRun:
    """One game in its own folder: its log, how it ended."""
    def __init__(self, folder):
        self.folder = folder
        self.start = 0.0
        self.killed = 0      # seconds without a log line when run.py killed it; 0 when it ended by itself
        self.exit = None     # its exit code (None: killed)
        self.lines = []      # its CR lines, the snaps resolved
        self.raw = ""        # its whole log


def game_run(engine, folder, tests_lua, file="", start=None):
    """Runs one game of engine in folder (made by engine.prepare), with tests_lua as _cr_tests.lua (the tests of file; from
    the test start, when a game before crashed or hung)."""
    g = GameRun(folder)
    log = engine.log(folder)
    # (the original appends to its log: the last game's must be gone; Windows may hold it for a moment after the game ended)
    for attempt in range(40):
        try:
            if os.path.exists(log):
                os.remove(log)
            break
        except OSError:
            if attempt == 39:
                raise
            time.sleep(0.25)
    engine.reset(folder)
    engine.put_tests(folder, tests_lua)
    cmd, env = engine.command(folder)
    cmd = offscreen(cmd)
    g.start = time.time()
    # (stdin closed: ScummVM's Lua read() falls back to the process's stdin when readfrom failed, and an open one blocks it)
    # (elsewhere than Windows, SDL's offscreen video driver keeps the window off the screen: OpenGL through EGL, no desktop)
    if not VISIBLE and os.name != "nt":
        env = dict(env or os.environ, SDL_VIDEODRIVER="offscreen")
    p = subprocess.Popen(cmd, cwd=folder, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                         stderr=subprocess.DEVNULL, env=env)
    if VERBOSE:
        knobs = " ".join("%s=%s" % (k, env[k]) for k in sorted(env) if k != "PATH" and os.environ.get(k) != env[k])
        trace(folder, file, "game started%s, pid %d%s: %s" % (" from " + start if start else "", p.pid,
                                                              ", renderer " + RENDERER if engine.name == "scummvm" else "",
                                                              subprocess.list2cmdline(cmd)))
        if knobs:
            trace(folder, file, "environment: " + knobs)
    # (--verbose: the log as far as it was read, a line not yet whole, when each test began)
    seen, tail, began = 0, b"", {}
    # (a game that writes nothing to its log for CR_STALL seconds hangs: it is killed. Until its first CR line the engine is
    # starting (ScummVM writes its header, then detects the game and starts the engine): CR_STARTUP)
    size, last, started = 0, time.time(), False
    while p.poll() is None:
        time.sleep(0.2)
        n = os.path.getsize(log) if os.path.exists(log) else 0
        if VERBOSE and n > seen:
            with open(log, "rb") as f:
                f.seek(seen)
                tail += f.read(n - seen)
            seen = n
            *whole, tail = tail.split(b"\n")
            for l in compare.extract(b"\n".join(whole).decode("latin-1")):
                trace_line(folder, file, l, began)
        if n != size:
            if not started and n > size:
                with open(log, "rb") as f:
                    f.seek(max(0, size - 3))
                    started = b"CR " in f.read(n - max(0, size - 3))
            size, last = n, time.time()
        limit = STALL if started else STARTUP
        if time.time() - last > limit:
            g.killed = limit
            p.kill()
            engine.kill(folder)
            break
    p.wait()
    g.exit = None if g.killed else p.returncode
    g.raw = open(log, "rb").read().decode("latin-1") if os.path.exists(log) else ""
    g.lines = snaps.resolve(compare.extract(g.raw), folder)
    if VERBOSE:
        # (what the game wrote after the last look at its log)
        for l in compare.extract(g.raw[seen - len(tail):]):
            trace_line(folder, file, l, began)
        how = ("killed: nothing in its log for %.0f s" % g.killed if g.killed else
               "exit code 0x%X" % (g.exit & 0xFFFFFFFF))
        trace(folder, file, "game ended after %.1f s, %d tests begun, %s%s" % (
            time.time() - g.start, len(began), how, "" if any(l.startswith("SUMMARY") for l in g.lines) else ", no SUMMARY"))
    return g


def trace_line(folder, file, l, began):
    """--verbose: a CR line of a game's log, when a test begins or ends (began: when each test began)."""
    word, _, rest = l.partition(" ")
    if word == "BEGIN":
        began[rest] = time.time()
        trace(folder, file, "test %s" % rest)
    elif word in ("END", "FAILED", "TIMEOUT"):
        t = began.get(rest)
        trace(folder, file, "test %s %s%s" % (rest, "ok" if word == "END" else word,
                                              " (%.1f s)" % (time.time() - t) if t else ""))
    elif word == "SKIP":
        trace(folder, file, "test %s skipped" % rest)
    elif word == "ERROR":
        trace(folder, file, "test " + rest)


def run_test_file(engine, path, slots, skip, only):
    """The tests of one test file in games of their own, until its last test has run. Returns (its result lines without START
    and SUMMARY, the total of tests a game announces, the tests that crashed or hung, its games' logs)."""
    name = os.path.basename(path)
    folder = slots.get()
    try:
        out, crashed, raws, total = [], [], [], 0
        start = None
        for _ in range(500):
            g = game_run(engine, folder, cr_tests_lua(only, skip | set(crashed), start, 0, name), name, start)
            raws.append(g.raw)
            for l in g.lines:
                if l.startswith("START "):
                    total = max(total, int(l.split()[1]))
            lines = [l for l in g.lines if not l.startswith(("START ", "SUMMARY "))]
            if any(l.startswith("SUMMARY") for l in g.lines):
                out += lines
                break
            cur = unfinished(g.lines)
            if not cur:
                say("%s: %s: the game ended without SUMMARY and no test was running (exit code %s)" %
                    (engine.name, name, "none (killed)" if g.exit is None else "0x%X" % (g.exit & 0xFFFFFFFF)))
                out += lines
                break
            say("%s: %s %s the game; skipped, %s goes on after it" % (engine.name, cur, "hung" if g.killed else "crashed", name))
            keep_crash_log(engine.name, cur, g)
            crashed += crash_group(cur)
            # (what ran before the test is kept; the next game starts at the test, which it writes as SKIP)
            cut = max(i for i, l in enumerate(lines) if l == "BEGIN " + cur)
            out += lines[:cut]
            start = cur
        return out, total, crashed, raws
    finally:
        slots.put(folder)


def run_parallel(engine, only, skip):
    """Runs every test file (with only: the files of those tests) in games of engine side by side. Writes
    logs/<engine>_raw.log (the games' logs, file by file); returns (the result lines, the tests that crashed or hung)."""
    import concurrent.futures
    import queue
    build(only, skip)
    if not lint():
        sys.exit(2)
    files = test_files()
    if only:
        # (the files that name one of the tests; all of them when a name is not written out, e.g. a computed one)
        want = set(only.split(","))
        named = [t for t in files if want & set(re.findall(r'cr_test\("([^"]+)",', open(t).read()))]
        found = set().union(*[set(re.findall(r'cr_test\("([^"]+)",', open(t).read())) for t in named]) if named else set()
        if want <= found:
            files = named
    # (CR_GAMES: games at a time, default one per processor, or the engine's own limit)
    n = max(1, min(int(os.environ.get("CR_GAMES") or engine.games or os.cpu_count() or 1), len(files)))
    # (the original copies its data folder into a buffer of 128 bytes to look for the *.lab in it, AddResourcePath 0x48d570: from
    # 128 characters on it finds none, and the archive tests fail)
    longest = engine.folder(n - 1) + "\\"
    if len(longest) > 100:
        sys.exit("%s: the run folders' path is too long for the game (%d characters, %s; at most 100): use a shorter --work"
                 % (engine.name, len(longest), longest))
    slots = queue.Queue()
    for k in range(n):
        d = engine.folder(k)
        engine.prepare(d)
        slots.put(d)
    t0 = time.time()
    say("%s: %d test files, %d games at a time" % (engine.name, len(files), n))
    results = {}
    # (the biggest files first: the run ends with the small ones)
    order = sorted(files, key=lambda t: -os.path.getsize(t))
    with concurrent.futures.ThreadPoolExecutor(n) as ex:
        futures = {ex.submit(run_test_file, engine, t, slots, skip, only): t for t in order}
        for f in concurrent.futures.as_completed(futures):
            results[futures[f]] = f.result()
    body, raw, new, total = [], [], [], 0
    for t in files:
        out, tot, crashed, raws = results[t]
        body += out
        new += crashed
        total = max(total, tot)
        raw += ["---- %s, game %d of %d\n%s" % (os.path.basename(t), i + 1, len(raws), r) for i, r in enumerate(raws)]
    fails = sum(1 for l in body if l.startswith("FAILED "))
    lines = ["START %d tests" % total] + body + ["SUMMARY %d tests, %d failed" % (total, fails)]
    say("%s: %.1f s for %d test files%s" % (engine.name, time.time() - t0, len(files),
                                           "; crashed or hung: " + ", ".join(new) if new else ""))
    os.makedirs(LOGS, exist_ok=True)
    with open(os.path.join(LOGS, engine.name + "_raw.log"), "w", newline="\n", encoding="latin-1") as f:
        f.write("\n".join(raw))
    return lines, new


def run_engine(engine, only=None, fresh=False):
    """Runs an engine's test files side by side (run_parallel): a test that crashes or hangs it is skipped. The original's
    crashers are kept in expected/crashers.txt (every engine skips them: there is no reference); ScummVM's and the Remastered's
    in their own lists (bugs, skipped on the next runs). Writes logs/<engine>.log; returns (lines, ScummVM's or the rebuilt exe's
    crashers)."""
    # (--fresh: the original runs the tests that crashed it before again, too; the list is written again at the end)
    skip = set() if fresh and engine == "original" else read_names(CRASHERS)
    known = set() if fresh or engine not in ("scummvm", "remastered") else (read_names(svm_known()) if engine == "scummvm" else read_names(REM_CRASHERS)) - skip
    skip |= known
    if engine == "original" and original_running():
        sys.exit("original: the %s of %s is running (maybe a game being played); not started" %
                 ("Monkey4.exe" if GAME == "emi" else "GRIMFANDANGO.exe", EMI_INSTALL if GAME == "emi" else GRIM_INSTALL))
    lines, new = run_parallel(make_engine(engine), only, skip)
    if engine == "scummvm":
        write_known(known | set(new))
    elif engine == "remastered" and (new or fresh):
        write_rem_known(known | set(new))
    elif engine == "original" and (new or fresh) and not READ_ONLY:
        with open_expected(CRASHERS) as f:
            f.write("# tests that crash the original (found by run.py); skipped on both engines\n")
            f.write("".join(n + "\n" for n in sorted(skip | set(new))))
    os.makedirs(LOGS, exist_ok=True)
    out = os.path.join(LOGS, engine + ".log")
    with open(out, "w", newline="\n") as f:
        f.write("\n".join(lines) + "\n")
    say("%s: %d result lines in %s" % (engine, len(lines), out))
    return lines, (sorted(known) + new if engine == "scummvm" else new if engine == "decomp" else [])


def compare_with(reference, engine, crashed, only=None):
    other = os.path.join(LOGS, engine + ".log")
    rc = compare.main([reference, other, "--unstable", UNSTABLE, "--known"] + (["--only"] if only else []))
    with open(os.path.join(LOGS, "scummvm_crashers_%s.txt" % RENDERER), "w") as f:
        f.write("".join(n + "\n" for n in crashed))
    if crashed:
        # (a crash of a test marked cr_scummvm_differs is a known one)
        marks = compare.known(*[compare.parse(open(p, encoding="latin-1").read().splitlines())[1] for p in (reference, other)])
        new = [n for n in crashed if n not in marks]
        print("crashed or hung ScummVM (a bug): %s%s" % (", ".join(crashed), "; not marked: %s" % ", ".join(new) if new else
                                                        "; all marked cr_scummvm_differs"))
        if new:
            rc = 1
    return rc


# ---- out of sight

# The engines run on a desktop of their own (tools/offscreen.c): their windows do not open on the screen and cannot take the
# focus. They draw as before (OpenGL, DirectDraw). CR_VISIBLE=1 runs them on the user's desktop.
VISIBLE = os.environ.get("CR_VISIBLE") == "1"
RENDER_EVERY = os.environ.get("CR_RENDER_EVERY", "")
OFFSCREEN = os.path.join(HERE, "run", "offscreen.exe")


def offscreen(cmd):
    """The command, started through offscreen.exe (built from tools/offscreen.c when older than it)."""
    if VISIBLE or os.name != "nt":
        return cmd
    src = os.path.join(HERE, "tools", "offscreen.c")
    if not newer(OFFSCREEN, [src]):
        os.makedirs(os.path.dirname(OFFSCREEN), exist_ok=True)
        env = dict(os.environ, PATH=UCRT64 + os.pathsep + os.environ.get("PATH", ""))
        subprocess.run([os.path.join(UCRT64, "gcc.exe"), "-O2", "-o", OFFSCREEN, src, "-lole32"], check=True, env=env)
        print("built %s" % OFFSCREEN)
    return [OFFSCREEN] + cmd


# ---- ScummVM

STALL = float(os.environ.get("CR_STALL", "2"))      # seconds without a new log line before a run counts as hung
STARTUP = float(os.environ.get("CR_STARTUP", "30"))   # the same until the first line (the engine is starting)


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
    (other tools' builds) are left alone; leftovers of our own run folders are stopped by Engine.kill."""
    install = os.path.normcase(os.path.normpath(os.path.abspath(EMI_INSTALL if GAME == "emi" else GRIM_INSTALL)))
    return any(folder == install for _, folder in game_processes())


def newer(target, sources):
    return os.path.exists(target) and all(os.path.getmtime(target) >= os.path.getmtime(s) for s in sources)


def prepare_tools(d):
    """patch.dll and grimlaunch.exe, built from the sources of this repository (an old grimlaunch.exe lacks the windowed patch
    and takes the whole screen), when they are older than the sources. They are built once into run/tools and copied into d."""
    tools = os.path.join(RUN, "tools")
    os.makedirs(tools, exist_ok=True)
    pdir = os.path.join(ROOT, "launcher")
    dll_src = [os.path.join(pdir, "patch.c"), os.path.join(pdir, "config.c")]
    dll = os.path.join(tools, "patch.dll")
    if not newer(dll, dll_src):
        env = dict(os.environ, PATH=MINGW32 + os.pathsep + os.environ.get("PATH", ""))
        subprocess.run([os.path.join(MINGW32, "gcc.exe"), "-shared", "-O2", "-static-libgcc", "-o", dll] + dll_src +
                       ["-luser32", "-lgdi32", "-lwinmm"], check=True, env=env)
        print("original: built patch.dll")
    launcher_src = [os.path.join(pdir, "grimlaunch.cpp")]
    launcher = os.path.join(tools, "grimlaunch.exe")
    if not newer(launcher, launcher_src):
        env = dict(os.environ, PATH=UCRT64 + os.pathsep + os.environ.get("PATH", ""))
        subprocess.run([os.path.join(UCRT64, "g++.exe"), "-O2", "-static", "-o", launcher] + launcher_src, check=True, env=env)
        print("original: built grimlaunch.exe")
    for src in (dll, launcher):
        dst = os.path.join(d, os.path.basename(src))
        if not newer(dst, [src]):
            shutil.copyfile(src, dst)


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
    write_grim_ini(d)
    copy_data(d)


def write_grim_ini(d):
    """grim.ini (the game's registry, the config patch) as a new game finds it: pointing at the folder itself. good_times skips
    the CD check (Grim_Init); the display values are the ones the install uses."""
    with open(os.path.join(d, "grim.ini"), "w", newline="\r\n") as f:
        f.write("[Grim]\nGrimDataDir=%s\\\ngood_times=TRUE\nTextAllowed=true\nExperimentalDisplay=0\n"
                "Last3DDevice=hex:00000000000000000000000000000000\n"
                "LastDisplayDevice=hex:009fa692fa13d11197c000a024293005\n" % d)


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


# ---- the rebuilt exe of grim-decomp

DECOMP_TAG = "cleanroom"   # GRIM_MULTI: its own window title (a game being played does not stop it) and crash report name
def prepare_decomp(d):
    """The run folder of the rebuilt exe: its four programs from GRIM_DECOMP (again whenever the build changed them),
    grim.ini as the original's, the data. Nothing of the install (the rebuilt programs load none of the original's other
    program files) and no grimlaunch.exe or patch.dll."""
    os.makedirs(d, exist_ok=True)
    for f in PROGRAM_FILES:
        dst = os.path.join(d, f)
        if f in DECOMP_FILES:
            src = os.path.join(GRIM_DECOMP, DECOMP_FILES[f])
            if not os.path.exists(src):
                sys.exit("decomp: %s is missing (set GRIM_DECOMP to the folder of the rebuilt grimfandango.exe)" % src)
            if not os.path.exists(dst) or open(src, "rb").read() != open(dst, "rb").read():
                shutil.copyfile(src, dst)
        elif os.path.exists(dst):
            os.remove(dst)   # (left by a run folder of an older run.py, which copied them from the install)
    with open(os.path.join(d, "grim.ini"), "w", newline="\r\n") as f:
        f.write("[Grim]\nGrimDataDir=%s\\\ngood_times=TRUE\nTextAllowed=true\nExperimentalDisplay=0\n"
                "Last3DDevice=hex:00000000000000000000000000000000\n"
                "LastDisplayDevice=hex:009fa692fa13d11197c000a024293005\n" % d)
    copy_data(d)


def renderer_diff(r0, r1):
    """Prints the tests whose values differ between two renderers' runs (beyond 1e-6)."""
    def load(r):
        return compare.parse(open(os.path.join(LOGS, "scummvm_%s.log" % r), encoding="latin-1").read().splitlines())[1]
    t0, t1 = load(r0), load(r1)
    unstable = compare.load_unstable(UNSTABLE) | compare.marked(t0, t1)
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
        rcs.append((r, compare_with(reference, "scummvm", crashed, only)))
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


def lock_folder(path=None, what="another run.py is running in this folder"):
    """Waits until no other run.py works in this folder (they share build/, run/ and logs/: two at once spoil each other's
    runs), then holds the lock until this process ends (Windows releases it when the process dies)."""
    path = path or os.path.join(LOGS, "run.lock")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    f = open(path, "a+")
    warned = False
    while True:
        try:
            f.seek(0)
            if os.name == "nt":
                import msvcrt
                msvcrt.locking(f.fileno(), msvcrt.LK_NBLCK, 1)
            else:
                import fcntl
                fcntl.flock(f.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
            return f
        except OSError:
            if not warned:
                print("run.py: %s; waiting for it" % what, flush=True)
                warned = True
            time.sleep(2)


# (the exes of the original, the Remastered and the decomp run one at a time on the machine, --work or not: they go through
# grimlaunch.exe and the registry, and their windows find each other)
EXE_LOCK = os.path.join(HERE, "logs", "exe.lock")


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "compare":
        return compare.main(sys.argv[2:])
    # (--work before the lock: a run in its own folder locks only that one)
    if "--work" in sys.argv[:-1]:
        set_work(sys.argv[sys.argv.index("--work") + 1])
    _lock = lock_folder()  # noqa: F841 (held until the process ends)
    _exe_lock = (lock_folder(EXE_LOCK, "another run.py runs an original exe") if  # noqa: F841
                 any(w in sys.argv[1:2] for w in ("original", "remastered", "decomp", "both")) else None)
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("what", choices=["build", "scummvm", "original", "remastered", "decomp", "both", "compare"])
    ap.add_argument("logs", nargs="*")
    ap.add_argument("--only", help="run one test")
    ap.add_argument("--remastered", action="store_true",
                    help="scummvm: in its Remastered mode, against logs/remastered.log (run.py remastered) if there is one; a report only")
    ap.add_argument("--save", action="store_true", help="original: the whole run becomes expected/original.log (not with --only)")
    ap.add_argument("--repeat", type=int, default=3, help="original --save: runs, to find the unstable values")
    ap.add_argument("--renderer", help="scummvm: only these renderers (comma separated; default: %s)" % ",".join(RENDERERS))
    ap.add_argument("--game", choices=["grim", "emi"], default="grim", help="the game whose engine is tested (default grim)")
    ap.add_argument("--fresh", action="store_true",
                    help="scummvm: run the tests that crashed or hung ScummVM before again (expected/scummvm_crashers_<renderer>.txt)")
    ap.add_argument("--visible", action="store_true", help="show the engines' windows on the screen (same as CR_VISIBLE=1)")
    ap.add_argument("--work", metavar="DIR", help="build/, run/ and logs/ in DIR, and expected/ only read: for runs in parallel")
    ap.add_argument("-v", "--verbose", action="store_true",
                    help="print each game's command line, its tests as they begin and end, and how it ended (same as CR_VERBOSE=1)")
    a = ap.parse_args()
    if a.work and a.save:
        sys.exit("--save writes expected/: not with --work")
    global VISIBLE, VERBOSE
    if a.visible:
        VISIBLE = True
    if a.verbose:
        VERBOSE = True
    set_game(a.game)
    if a.game == "emi" and a.what == "remastered":
        sys.exit("the Remastered is Grim's")
    if a.game == "emi" and a.what == "decomp":
        sys.exit("grim-decomp is Grim's")
    if a.what == "compare":
        return compare.main(a.logs)
    if a.what == "build":
        build(a.only, read_names(CRASHERS))
        return 0 if lint() else 2
    renderers = a.renderer.split(",") if a.renderer else RENDERERS
    if a.what == "scummvm" and a.remastered:
        if a.game == "emi":
            sys.exit("the Remastered is Grim's")
        # (the Remastered's own run is in the shared logs/, with --work too)
        rem_log = os.path.join(HERE, "logs", "remastered.log")
        set_remastered()
        # (the reference is the Remastered's own run when there is one; the marks are for the original, so this is a report)
        run_scummvm_all(rem_log if os.path.exists(rem_log) else EXPECTED, a.only, a.fresh, renderers)
        return 0
    if a.what == "scummvm":
        return run_scummvm_all(EXPECTED, a.only, a.fresh, renderers)
    if a.what == "original" and a.save:
        # (the expected log is always a whole run: tests saved into an older one end up in another order than they run)
        if a.only:
            sys.exit("--save writes the whole expected log: run it without --only")
        # (the reference must repeat itself: the values that differ between runs are kept in unstable.txt and not compared)
        # (a test that crashes or hangs in one run is skipped by the next ones, which then differ from it: the runs start over
        # whenever the crash list grows, so that all of them skip the same tests)
        runs = []
        restarts = 0
        while len(runs) < a.repeat:
            i = len(runs)
            before = read_names(CRASHERS)
            run_engine("original", a.only)
            if read_names(CRASHERS) != before and restarts < 5:
                restarts += 1
                say("original: new crashers in run %d (%s); the runs start over" %
                    (i + 1, ", ".join(sorted(read_names(CRASHERS) - before))))
                runs = []
                continue
            path = os.path.join(LOGS, "original_%d.log" % (i + 1))
            shutil.copyfile(os.path.join(LOGS, "original.log"), path)
            lines = open(path).read().splitlines()
            # (a run that did not get to the end is no reference: the expected files are left as they are)
            if not any(l.startswith("SUMMARY") for l in lines):
                sys.exit("original: run %d did not reach SUMMARY; nothing saved" % (i + 1))
            runs.append(compare.parse(lines))
        # (keys the tests mark with cr_unstable are not compared anyway: unstable.txt has the others)
        unstable = sorted(compare.unstable_keys(runs) - compare.marked(*[t for _, t in runs]))
        os.makedirs(os.path.dirname(EXPECTED), exist_ok=True)
        # (without the DIFFERS lines: they are the tests' marks for ScummVM, not what the original did; ScummVM's log has them)
        # (and the values that are not compared, cr_unstable or in unstable.txt, written as "(unstable)": a tick count, an
        # address or next()'s order would change the file on every --save, though nothing that is compared changed)
        skip = compare.marked(*[t for _, t in runs]) | set(unstable)
        with open(os.path.join(LOGS, "original.log"), newline="") as src, open_expected(EXPECTED, "") as dst:
            for l in src:
                if l.startswith("DIFFERS "):
                    continue
                if l.startswith("V "):
                    name, key, _ = (l[2:].split("|", 2) + ["", ""])[:3]
                    if "%s|%s" % (name, key) in skip:
                        l = "V %s|%s|(unstable)%s" % (name, key, "\r\n" if l.endswith("\r\n") else "\n")
                dst.write(l)
        with open_expected(UNSTABLE) as f:
            f.write("# test|key values that differed between %d runs of the original; not compared\n" % a.repeat)
            f.write("".join(k + "\n" for k in unstable))
        print("saved %s (%d unstable values: %s)" % (EXPECTED, len(unstable), ", ".join(unstable) or "none"))
        return 0
    if a.what == "remastered":
        run_engine("remastered", a.only, fresh=a.fresh)
        return compare.main([EXPECTED, os.path.join(LOGS, "remastered.log"), "--unstable", UNSTABLE] + (["--only"] if a.only else []))
    if a.what == "decomp":
        # (its crashes are bugs of the rebuild: reported, not kept; the original's crashers are skipped, there is no reference)
        _, crashed = run_engine("decomp", a.only, fresh=a.fresh)
        rc = compare.main([EXPECTED, os.path.join(LOGS, "decomp.log"), "--unstable", UNSTABLE] + (["--only"] if a.only else []))
        if crashed:
            print("crashed or hung the rebuilt exe: %s" % ", ".join(crashed))
            rc = rc or 1
        return rc
    if a.what == "original":
        run_engine("original", a.only, fresh=a.fresh)
        return compare.main([EXPECTED, os.path.join(LOGS, "original.log"), "--unstable", UNSTABLE] + (["--only"] if a.only else []))
    run_engine("original", a.only, fresh=a.fresh)
    shutil.copyfile(os.path.join(LOGS, "original.log"), os.path.join(LOGS, "original_both.log"))
    return run_scummvm_all(os.path.join(LOGS, "original_both.log"), a.only, a.fresh, renderers)

if __name__ == "__main__":
    sys.exit(main())
