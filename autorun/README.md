# autorun: the Grim Fandango playthrough

Lua scripts that play the whole of Grim Fandango, from a new game to the credits. They play the way a
player does, with real key presses. Manny walks with the movement keys and faces an object until the
game makes it the hot object, then the real USE / PICK_UP / LOOK_AT key goes through the game's own button
handler. Nothing calls an object's function directly. If the game does not offer an object, the step
fails, and the first failure ends the run.

The same scripts run on two engines:

- **ScummVM**, through its `--autorun=<file.lua>` option, in simulated time (`--sim-fps`) so that a run is
  deterministic.
- **The original v1.01 `GRIMFANDANGO.exe`**, through Lua injection: `grimlaunch.exe` patches the exe, and
  F12 runs `grimpatch.bin`.

Where the two engines disagree is a ScummVM bug to find. For the rules, the current status and the open
differences, read [../HANDOFF.md](../HANDOFF.md).

## Requirements

- An MSYS2 **UCRT64** shell. The scripts are POSIX `sh`, with Python for the tools.
- The autorun engine: worktree `~/scummvm-autorun` (branch `autorun`), build `build-opt`, built by
  `../build_scummvm_autorun.sh`. The EMI autorun uses the same engine. `SVM_DIR=<folder>` or
  `SVM_BUILD=<build folder of that worktree>` points a run at another build.
- The game data in `C:\GOG Games\GRIMDATA`. Your `%APPDATA%\ScummVM\scummvm.ini` must have a `grim-win`
  target. Each run copies that ini into `generated/` and changes the copy, so your own ini is never written.
- For the original exe: the v1.01 install and `../launcher/grimlaunch.exe` (see `../README.md`). Start the
  original only through `grimlaunch`.

## Running it

```sh
sh run_all.sh 6000                 # the whole game on ScummVM, a few minutes; log in logs/all.log (logs/<MODE>.log with MODE=)
sh run_chapter.sh ch35_morgue.lua  # one chapter, from the checkpoint save it loads itself (ar_load); log in logs/<chapter>.log
SAVE=1 sh run_all.sh 6000          # the whole game, and the checkpoints grim01.gsv ... written into ./saves
sh rebuild_saves.sh                # rebuilds the checkpoints chapter by chapter (needed after a library change)
sh test_all.sh                     # the navigation tests (tools/test_all.py; tiers in TESTS.md)
sh orig_launch_run.sh              # the whole game on the original exe, through grimlaunch, on a desktop of its own
sh orig_all.sh                     # the original, restarted from the checkpoint of a chapter that fails (up to 3 tries each)
```

A run prints its `AUTORUN` lines at the end. A good run ends in `RESULT PASSED`. The steps of a run are
also drawn in the top left of the game window.

Long runs take longer than a tool call's timeout. Start them detached (`setsid nohup ...`) and follow the log.
The scripts for the original kill any running `GRIMFANDANGO.exe`, so make sure nobody is playing it, and run
only one of them at a time.

### Modes

`MODE=` picks what the run plays (`mode.sh`, with the details in `MODES_PLAN.md`):

| Mode | What it plays |
|---|---|
| `speed` (default) | cutscenes and lines skipped, text only, the minimum of the story |
| `text` | as speed, but each line lasts as long as its text (the mode used to compare frames) |
| `full` | nothing skipped, voices on; saves its checkpoints by default |
| `speed100` | as speed, plus everything else there is to do (the `ex*.lua` extras) |
| `full100` | as full, plus the extras |

The 100% and real modes keep their own saves (`saves_<mode>/`) and logs (`logs/<mode>.log`).

### Common variables

| Variable | Effect |
|---|---|
| `UPTO=<n>` / `FROM=<n>` | play only chapters up to n / from chapter n (FROM loads the checkpoint the chapter before it saved) |
| `SAVE=1` | write the checkpoint saves (by default `run_all.sh` does not save) |
| `SIMFPS=<n>` | simulated frames per second (default 60) |
| `REALTIME=1` | real time instead of simulated time; no time limit and no stall watch |
| `REAL=1` | no skips, voices on (what `MODE=full` sets) |
| `FRAMES=<ms>`, `DUMPDIR=<dir>` | ScummVM writes a frame that often, into that folder |
| `TRICKS=<name>,...` | speed-runner tricks (`ar_tricks.lua`); only tricks verified on the original exe |
| `NAVDEBUG=1`, `SPEEDLOG=1` | draw the navigation on screen / log Manny's stop-walk-run segments (`ar_navdebug.lua`) |
| `STALL=<s>`, `CHSTALL=<s>` | the stall watch (`stall_watch.sh`): no AUTORUN line for that long, or one chapter taking that long, kills the run |
| `GRIMOFF="rule ..."`, `GRIMON=` | switch off (or on) engine accuracy rules, to find which one changes a result |
| `LOG=`, `SAVES=` | log name and save folder |
| `WIN=WxH`, `RENDEREVERY=<n>` | window size and how often a frame is drawn (defaults 640x480 and 1 in 64, except in real or frame-capture runs) |
| `EXTRALIB=<file>` (run_all), `EXTRA="<files>"` (run_chapter) | extra Lua put in front of the chapters (tests, probes) |

The header comments of `run_all.sh`, `run_chapter.sh`, `mode.sh` and `build_original.sh` list the rest.

## How a run is put together

`run_all.sh` writes one script, `generated/all_<pid>.lua`, from:

1. the mode globals (`AR_MODE`, `AR_SKIPLINES`, `AR_FULL`, ...),
2. the libraries: `ar_lib.lua`, `ar_nav.lua`, `nav_setfile.lua`, `ar_nav_known.lua`, `ar_helpers.lua`,
   `ar_rng.lua`, `ar_full.lua` (and `ar_navdebug.lua`, `ar_tricks.lua`, `ex*.lua` when asked for),
3. every `ch*.lua` in file-name order, each started with `ar_frame_chapter("<name>")`.

`run_chapter.sh` builds the same script with a single chapter. `build_original.sh` builds the version for
the original exe (`autorun_all.lua` and `grimpatch.bin`).

Each chapter ends with `ar_checkpoint(N)`, where N is its position among the `ch*.lua` files. The next
chapter starts with `ar_load(N)`. So any chapter can be played by itself from the saves of an earlier
`SAVE=1` run or `rebuild_saves.sh`.

Two rules:

- **Never leave a `ch*_dbg.lua` (or any other `ch*.lua` that is not a chapter) here,** because `run_all.sh`
  picks up every `ch*.lua`.
- **Never edit `generated/`.** It is rewritten on every run.

## Layout

| Path | What it is |
|---|---|
| `ar_lib.lua` | The core library: keys, verbs (`ar_do`), items (`ar_hold`), doors (`ar_go`), dialogs, cutscene skips, saves, logging, the watchdog |
| `ar_nav.lua`, `nav_setfile.lua`, `ar_nav_known.lua`, `ar_nav_sets.lua` | Path planning over the set's sectors, with the walk links that scripts make |
| `ar_helpers.lua`, `ar_rng.lua`, `ar_full.lua`, `ar_safe.lua` | Walks the planner needs help with, the game's random numbers predicted, shared helpers, the vault safe's tumblers |
| `ar_tricks.lua`, `ar_blam_spots.lua`, `ar_blam_after.lua` | Speed-runner tricks and where they are used |
| `ch01_*.lua` ... `ch65_*.lua` | The chapters; [PROGRESS.md](PROGRESS.md) says what each one does and which saves it loads and writes |
| `ex00_*.lua` ... `ex06_*.lua` | Extras for the 100% modes: dialog sweeps, talkers, trips, doors |
| `run_all.sh`, `run_chapter.sh`, `mode.sh`, `stall_watch.sh` | Running on ScummVM |
| `build_original.sh`, `orig_launch_run.sh`, `orig_all.sh`, `resume_original.sh`, `orig_test.sh` | Running on the original exe |
| `rebuilt_test.sh` | Running a test or the autorun on the rebuilt game (grim-decomp) |
| `min_try.sh` | Commit minimisation of the `autorun` branch: builds master plus chosen commits and plays the speed run |
| `test_nav.lua`, `nav_cases*.lua`, `nav_*_expect.lua`, `test_rules.lua`, `rules_*.lua`, `test_all.sh` | The navigation and rule tests ([TESTS.md](TESTS.md), [TEST_PLAN.md](TEST_PLAN.md)) |
| `tests/` | Probes, golden expected output from the original (`tests/golden/`), hand-made test sets (`tests/sets/`) |
| `tools/` | Python and shell tools: trace and frame comparison, golden tests, coverage, audio, recording, offline Lua 3.1 (`lua31/`), the original's math (`origmath/`) |
| `rl.sh`, `rl2.sh` | Remote Lua into a running ScummVM game |
| `generated/`, `logs/`, `saves*/`, `origlaunch/` | Run output (not tracked) |

## Further reading

- [PROGRESS.md](PROGRESS.md): the chapter table and how the playthrough works
- [ROUTE.md](ROUTE.md): the route of the speed run, frame by frame (made by `tools/route_report.py`)
- [TESTS.md](TESTS.md), [TEST_PLAN.md](TEST_PLAN.md): the test tiers
- [MODES_PLAN.md](MODES_PLAN.md): the modes
- [GHIDRA_NAMES.md](GHIDRA_NAMES.md): addresses in the original exe and their names in Ghidra
- `NAV_PLAN.md`, `STATE_PLAN.md`, `ACCURACY_PLAN.md`, `COLLISION_FIX_PLAN.md`, `CAMERA_PLAN.md`, `SEAM_PLAN.md`: design notes
