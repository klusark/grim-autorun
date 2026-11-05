# Clean-room engine tests

Tests that run on the original Grim Fandango v1.01 exe and on ScummVM with **none of the game's data files**:
only data made here (Lua, sets, bitmaps, a colormap, a text table, costumes). The original is the reference. A test does
not assert anything; it logs what it observes (`cr_log`), and `compare.py` checks ScummVM's values against the
original's, value by value.

```sh
python run.py original --save    # run the original 3 times (--repeat N), keep it as expected/original.log
python run.py scummvm            # run on ScummVM and compare with expected/original.log
python run.py both               # run both and compare them with each other
python run.py scummvm --only chore_keys      # one test
python run.py compare logs/original.log logs/scummvm.log --all
```

A run takes 1-2 s on the original (simtime: no waiting between frames) and about 3 s on ScummVM with `--sim-fps`.

The reference must repeat itself. `--save` runs the original several times, and every value that differs between those
runs goes to `expected/unstable.txt` and is not compared. So far that is `next_order|order`: the original's Lua hashes
by address. `chore_short` once differed in one run out of seven, so it may need more repeats.

## What is needed

- **The original:** the program files of the install (`GRIMFANDANGO.exe`, `LUA.DLL`, `IMUSE.DLL`, `CHORE.DLL`, the HMI
  and NULLMUSE dlls, `HMILIBS.INI`, `IMUSE.PSL`, `grimdlg.dll`). `run.py` copies them from `GRIM_INSTALL`
  (default `C:\GOG Games\GRIMDATA`) into `run/original/`, once. No LAB, `GRIM.TAB` or other data file is copied.
  `patch.dll` and `grimlaunch.exe` are built from `../patches` into the run folder whenever the sources are newer.
  The game is started only through `grimlaunch.exe` (debuglog, simtime, config and windowed patches). `grim.ini` points
  `GrimDataDir` at the run folder and sets `good_times` (no CD check).
  `run.py` does not start if a `GRIMFANDANGO.exe` is running already, and it kills only the process it started.
- **ScummVM:** a build with `scummvm/grim-test-data.patch` (a detection entry for the marker file `grimtestdata.txt`,
  flag `GF_TESTDATA`: no `gfupd101.exe`, no `grim-patch.lab`, no md5 check, loose files and the folder's own LABs).
  `scummvm/build.sh` builds it in the worktree `~/scummvm-cleanroom` (`git worktree add --detach ../scummvm-cleanroom
  <branch>` and `git apply` the patch first). `SCUMMVM=` selects another exe. Without `--sim-fps` (branches without the
  autorun options) the frame times are real ones and the per-frame values do not match.

## How it works

Both engines boot by running `_system.lua` and then calling `BOOT`. The test data has its own `_system.lua`
(`lua/_system.lua`), which is the test runner. It loads `_cr_tests.lua`, which `run.py` writes with one `dofile` per
file in `tests/`. It runs every test in a task of its own, writes `CR ...` lines through `PrintDebug` and ends with
`exit()`. The original writes them to `grimdebug.log` (patch.dll), ScummVM to its log (`--debugflags=scripts`).

What the original needs at start (Ghidra, `Grim_Init`): `grim.tab` is optional (`Polyglot_LoadTable`; ours is in the
folder, because it is read with fopen before any archive is open); every `*.lab` of the data folder and the folder
itself are opened (`Resource_OpenArchivesInDir`), so loose files are enough; `splash.bm` is optional; `_system.lua` is
run from source text (the exe has the Lua 3.1 parser).

| File | What it is |
|---|---|
| `run.py` | build, run either engine, compare |
| `compare.py` | extracts the CR lines from an engine log, compares two runs (`--tol`, default 1e-6) |
| `formats.py` | writers: LAB, grim.tab (RCNE), .bm/.zbm (raw, RGB565), .cmp, text .set, text .cos |
| `assets.py` | the data: three sets (`cr_flat`, `cr_edge`, `cr_stair`), backgrounds, the text table, `cr_luav.cos` |
| `lua/_system.lua` | the runner (`cr_test`, `cr_log`, `cr_frames`, `cr_until`) |
| `tests/*.lua` | the tests |
| `expected/original.log` | the original's results, the reference for ScummVM runs |
| `expected/unstable.txt` | values the original does not repeat run to run (not compared) |
| `scummvm/` | the engine patch and its build script |
| `tools/labls.py` | lists the members of a LAB (to look at the layout of the game's formats; nothing is copied) |

## Writing a test

```lua
cr_t_my_case = function()
	MakeCurrentSet("cr_flat.set")
	local a = cr_actor("cr_flat.set")       -- tests/actors.lua: an actor at the origin, following the boxes
	WalkActorTo(a, 1, 1, 0)
	cr_frames(10)
	cr_pos("after_10", a)                   -- cr_log("after_10", x, y, z)
end
cr_test("my_case", cr_t_my_case)
```

Lua 3.1: no `break`, no closures over locals (use globals, e.g. `CR_A` with `cr_actor_global`), nil is false, at most
32 locals, and no mixed table constructors (`{ 1, 2; n = 2 }` needs the `;`). `TRUE`/`FALSE` are defined by the runner.
Before a run, `run.py` parses every Lua file with the game's own LUA.DLL (`autorun/tools/lua31`). A file that does not
parse would otherwise drop its tests with one ERROR line. A test that raises an error writes `ERROR` and `FAILED`, and the
runner goes on. Log what you see and let the comparison decide. Test names, keys and the order of the keys must not depend
on the engine. A key logged twice in a test is compared as `key`, `key#2`, ...

`compare.py` puts a test in one of three classes. `same`: equal within 1e-6. `close`: all differing values are numbers
within 1e-3 (`--close`). `DIFF`: anything else.

Original-only traps found so far:
- `WalkActorTo` moves an actor only when it follows the boxes (`SetActorFollowBoxes`).
- `SetSelectedActor` on an actor without a costume crashes the original.
- `GetAngleBetweenActors(a, b)` crashes when `a` does not follow the boxes (it reads the walker's heading).
- There is no `sleep_for`.

## Determinism of the original

With `simtime` every frame is 17 ms (`frame_time` checks it), and repeated runs give the same values except one: the order
of `next()`. The original's Lua hashes strings and tables by address. LUA.DLL's own C runtime places its small-block heap
where Windows finds room, and that moves by multiples of 64 KB from run to run; the low bits of every address repeat.
Two attempts did not change it, so both were dropped: ASLR off for the process (a creation flag in grimlaunch), and LUA.DLL's
and the exe's heap calls redirected to a fixed arena from patch.dll (Lua's objects are not allocated there). The first region
is reserved before patch.dll loads. Fixing it would need patch.dll loaded at the process entry, before the runtimes start.
Until then, tests must not depend on table order. `--save` keeps any value that varies in `expected/unstable.txt`.

## Differences found (ScummVM grim-actor-fixes, 2026-11-05)

58 tests: 28 the same, 2 close, 28 differ. Besides the per-frame walk and turn values:
- The walk ends one frame's step past the target on the original (more at a higher rate), with a final yaw 2.3 degrees off.
  After `PutActorAt` the original keeps walking.
- The original eases into `TurnActorTo`; ScummVM turns at a constant rate. `WalkActorForward` into a wall slides on the
  original and stops dead on ScummVM.
- ScummVM does not fire the LUAV keys of a costume without a model (`CR_LV` is never set); the original does.
- `MakeSectorActive` with a number does nothing on the original. A sector switched on stays on across a change of set on the
  original; ScummVM resets it. The current setup is kept across a change of set on the original; ScummVM goes back to 0.
  `GetCurrentSetup` of a set that is not current is 0 on the original and nil on ScummVM.
- `WorldToScreen` returns whole pixels on the original; with a rolled camera ScummVM is up to 31 px off.
- `RotateVector` and `GetAngleBetweenVectors` are within 1e-3 (the original's sin/cos tables).
- Registry: an unset value reads 96 on ScummVM (nil on the original); numbers come back as strings on the original.
- Number text: the original's C runtime writes 3-digit exponents (`1e+015`) and `1.#INF`; `tonumber("0x10")` is nil.
  `LocalizeString("no slashes")` gives `"//no slashes"` on the original.
- About 87 Lua builtins exist only on the original; `sleep_for`, `pause_script`, `unpause_script` only on ScummVM.

## Not done yet

Models (.3do), materials (.mat), keyframes (.key) and sounds have no writer yet. Walk chores, collision boxes and anything
that is drawn need them. Text objects and fonts (.laf) are not covered either.
