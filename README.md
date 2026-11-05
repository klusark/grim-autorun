# grim_tools

Tools for making ScummVM's Grim Fandango (and Escape from Monkey Island) engine behave like the original
game. You compare the two engines by playing the whole game with scripts on both and checking where they
differ.

There are four parts:

- **Scripted playthroughs.** Lua scripts play the entire game from a new game to the credits through real
  key presses. They run on ScummVM through its `--autorun` option, and on the original v1.01 exe through Lua
  injection.
- **Tests.** Navigation, collision, turning and rule tests run on both engines. The expected values were
  recorded on the original.
- **Tracing and comparison tools.** Frame traces, bit-exact walker comparison, frame captures and
  "golden" regression scripts.
- **Patchers for the original exe.** They add logging, a frame limiter, a fixed frame time and Lua injection
  without the registry value.

**Picking up the work? Read [HANDOFF.md](HANDOFF.md) first.** It covers the rules, the current status, the
open differences and the pitfalls.

## Layout

| Path | What it is |
|---|---|
| `HANDOFF.md` | Status, rules and lessons learned; start here |
| `autorun/` | Grim playthrough: libraries (`ar_lib.lua`, `ar_nav.lua`, ...), chapters `ch01..ch65`, run scripts, tests |
| `autorun/PROGRESS.md` | What each chapter does and which save it loads and writes |
| `autorun/TESTS.md`, `TEST_PLAN.md` | Test tiers and what each added test covers |
| `autorun/GHIDRA_NAMES.md` | Addresses in the original exe and the names given to them in Ghidra |
| `autorun/*_PLAN.md` | Design notes: navigation, state, accuracy, collision |
| `autorun/tools/` | Python and shell tools: trace compare, golden tests, frame diff, coverage, audio probes, offline Lua 3.1 (`lua31/`), original math check (`origmath/`) |
| `cleanroom/` | Engine tests on both engines with none of the game's data: our own Lua, sets, bitmaps, costumes (see its README) |
| `emi_autorun/` | Escape from Monkey Island playthrough, built on the Grim libraries (see its `PROGRESS.md`) |
| `crashdbg/` | Windows helpers for the original exe: debugger launcher (`grimrun2`), breakpoint tracer (`grimtrace`), iMuse tracer (`imtrace`), memory read/write, F12 sender |
| `patches/patch/` | Source of `patch.dll` (`patch.c`: logging to `grimdebug.log`, frame limiter; `config.c`: grim.ini instead of the registry), loaded by the patched game. Build steps are in the header of `launcher/grimlaunch.cpp` (32-bit gcc) |
| `patches/launcher/` | `grimlaunch.cpp`: starts the original v1.01 exe suspended and patches it in memory (debuglog, simtime, config on by default; framelimit with `--with`; the game's `-w` window switch is added by default). Writes `grim.ini` from the registry when it is missing |
| `tools/` | Script analysis: `digest.py` (state-changing lines per function), `sectors.py` (plot sector dumps), `safe_solver.py`, `items.py` |
| `gt.sh` | Look up voice text by id or regex in `grim_text.txt` |
| `lua31dis.py`, `delua.exe` | Lua 3.1 bytecode disassembler and decompiler |
| `build_scummvm*.sh` | Build ScummVM (`build-opt` for the autorun, `build` for debugging) |
| `grim_registry.reg` | Registry entries for the original install |
| `backups/`, `oldrun/`, `gfupd/` | Old snapshots and exe variants (not tracked in git) |

## Requirements

- Windows with MSYS2. Build and run in a **UCRT64** login shell (`MSYSTEM=UCRT64 bash -l`).
- The ScummVM source at `~/scummvm` (branches `grim-actor-fixes-split` and others; see HANDOFF.md).
- Grim Fandango data in `C:\GOG Games\GRIMDATA`, and the decompiled scripts in `C:\Users\Joel\grim_lua_src`.
- The original exe and the patched copies. `.gitignore` excludes the binaries, game data, extracted text,
  saves, logs and captures, so a fresh clone has none of them. You have to rebuild or re-extract them:
  - Extract the v1.01 exe from `GFUPD101.EXE`, then run it with `patches/launcher/grimlaunch.exe GRIMFANDANGO.exe` (see HANDOFF.md).
  - Rebuild the C tools in `crashdbg/` with gcc (`patch.dll` and `grimlaunch.exe` build as described in `patches/launcher/grimlaunch.cpp`).

## Quick start

From `autorun/` in a UCRT64 shell:

```sh
SIMFPS=60 sh run_all.sh 6000     # whole game on ScummVM, ~5 min; log in logs/all.log
sh run_chapter.sh ch23_morgue.lua # one chapter from its checkpoint save
python tools/test_all.py scummvm         # all test tiers on ScummVM, ~1 min
sh orig_all.sh                           # whole game on the original exe (takes about an hour)
python3 tools/ftrace_cmp.py logs/ft_sv.log logs/ft_orig_new.log 0.01 0.05 4   # first frame differences
```

Long runs exceed tool timeouts, so start them detached (`setsid nohup ...`) and follow the log.
`orig_test.sh` and `orig_all.sh` kill any running `GRIMFANDANGO.exe`, so check that nobody is playing it first.
