# Clean-room engine tests

Tests that run on the original Grim Fandango v1.01 exe and on ScummVM with **none of the game's data files**:
only data made here (Lua, sets, bitmaps, a colormap, a text table, costumes). The original is the reference. A test does
not assert anything; it logs what it observes (`cr_log`), and `compare.py` checks ScummVM's values against the
original's, value by value.

Run it with the MSYS2 venv (`~/venv/bin/python.exe`, UCRT Python 3.14); nothing beyond the standard library is needed.

```sh
python run.py original --save    # run the original 3 times (--repeat N), keep it as expected/original.log
python run.py scummvm            # run on ScummVM and compare with expected/original.log
python run.py both               # run both and compare them with each other
python run.py scummvm --only chore_keys      # one test
python run.py compare logs/original.log logs/scummvm.log --all
```

**Crashes.** When a test kills an engine, `logs/crashes/<engine>_<renderer>_<test>.log` starts with a backtrace read from the
Windows crash dump (`%LOCALAPPDATA%\CrashDumps`, `tools/crashstack.py`; function names for ScummVM from `nm`, module+offset for the
retail exes), then the engine's log. Windows writes dumps only for some processes (ScummVM's so far); with none the file says so.

A run takes 1-2 s on the original (simtime: no waiting between frames) and about 3 s on ScummVM (fixed 17 ms frames, no frame limit).

The reference must repeat itself. A value that is not meant to repeat (a time, a size, an address) is marked in the
test with `cr_unstable(key)`, and it is not compared. `--save` also runs the original several times, and every other value
that differs between those runs goes to `expected/unstable.txt` and is not compared either; the file is written again by
every `--save`, so a value known to vary belongs in the test, not there. `chore_short` once differed in one run out of
seven, so it may need more repeats.

**Known differences and regressions.** A test that ScummVM is known to get wrong is marked next to its `cr_test`:
`cr_scummvm_differs("name", "why")` (a third argument, `"grim"` or `"emi"`, limits it to one game in a file both run). The
ScummVM runs compare with `--known`: a marked test that differs is **known**, a marked one that is the same now is
**FIXED** (the mark should go), and one that differs without a mark is a **REGRESSION**, which fails the run. A crash of a
marked test is known as well. `python tools/mark_known.py [--game emi]` sets the marks from the last `run.py scummvm`
(every renderer's log): it marks every test that differs and unmarks the fixed ones, except marks that give a reason. The
argument tests get theirs through `tools/args_differs.txt` (`args_differs_emi.txt`), which `tools/gen_args.py` reads.

**In parallel.** `run.py` locks its folder: its runs share build/, run/ and logs/, and write the crasher lists of
expected/. `run.py ... --work DIR` gives a run its own build/, run/ and logs/ in DIR and writes nothing to expected/ (the
crashers it finds are reported only), so runs with different DIRs go at once. `tools/parallel.sh` runs Grim and EMI with
every renderer that way, six at once, in about 3 minutes (`--games grim,emi,remastered`, `--renderers`, and run.py's
options such as `--only`; the results in run/parallel/; exit 1 on a regression). It sets `CR_STALL=15`, since six engines at
once keep the machine busy. `--coverage` is the coverage run (below). `tools/mark_known.py` takes its logs as arguments
(`run/parallel/grim_<renderer>/logs/scummvm_<renderer>.log`, one per renderer). A new crasher is not kept: run `run.py scummvm` itself for that.

## What is needed

- **The original:** the program files of the install (`GRIMFANDANGO.exe`, `LUA.DLL`, `IMUSE.DLL`, `CHORE.DLL`, the HMI
  and NULLMUSE dlls, `HMILIBS.INI`, `IMUSE.PSL`, `grimdlg.dll`). `run.py` copies them from `GRIM_INSTALL`
  (default `C:\GOG Games\GRIMDATA`) into `run/original/`, once. No LAB, `GRIM.TAB` or other data file is copied.
  `patch.dll` and `grimlaunch.exe` are built from `../launcher` into the run folder whenever the sources are newer.
  The game is started only through `grimlaunch.exe` (debuglog, simtime, config and windowed patches). `grim.ini` points
  `GrimDataDir` at the run folder and sets `good_times` (no CD check).
  `run.py` does not start if a `GRIMFANDANGO.exe` is running already, and it kills only the process it started.
- **ScummVM:** a build with `scummvm/grim-test-data.patch` (a detection entry for the marker file `grimtestdata.txt`,
  flag `GF_TESTDATA`: no `gfupd101.exe`, no `grim-patch.lab`, no md5 check, loose files and the folder's own LABs;
  `PrintDebug("CRSNAP:<file>")` saves a picture of the screen; an `error()` ends ScummVM at once, with its message in the
  log, instead of opening the debugger and waiting there; `sim_frame_ms` in the ini makes every frame that long, like the
  original's simtime patch, and then only one frame in 8 is drawn, and those of a change of setup, mode or set).
  The patch applies to upstream `master` and needs nothing from another branch. `scummvm/build.sh` builds it in the
  worktree `~/scummvm-cleanroom` (`git worktree add --detach ../scummvm-cleanroom master` and `git apply` the patch
  first). `SCUMMVM=` selects another exe.
- **No windows on the screen:** ScummVM and the originals run on a desktop of their own (`tools/offscreen.c`, built into
  `run/offscreen.exe`): they draw as before (OpenGL, DirectDraw), but nothing shows and they cannot take the focus. The
  program and what it starts are in a job that ends with `offscreen.exe`, so killing a run that hangs kills them all. EMI's
  original cannot start Direct3D on another desktop ("make sure you are not running any application that takes exclusive
  control of your hardware"), so it runs with its OpenGL renderer (`Monkey4.exe -gl`). The values are the same as with
  Direct3D except `GammaEnabled` (1 against nil: what the hardware can do), which is marked unstable. `CR_VISIBLE=1` shows
  them all.

## Escape from Monkey Island

```sh
python run.py original --game emi --save   # the original Monkey4.exe v1.1: expected/emi_original.log
python run.py scummvm --game emi           # ScummVM's EMI against it
```

The same runner runs on EMI. The folder of a test file says which games run it: `tests/common/` both, `tests/grim/` and
`tests/emi/` one each (`testfiles.py`). A game runs the files of `common/` and of its own folder in the order of their
names, the folders mixed, so the file names must differ across the folders. Inside a file of `common/`, `CR_GAME`
(`"grim"` or `"emi"`) guards the parts that need one game's data. Each game's original is its own reference, so "shared"
means the same test source, not the same values. The EMI runs use `build_emi/`, `run/emi/`, `logs/emi/` and
`expected/emi_*`.

- **The original:** `run.py` copies `Monkey4.exe`, the Miles dlls and filters and `binkw32.dll` from `EMI_INSTALL`
  (default `C:\GOG Games\Escape from Monkey Island`). No `.m4b` is copied. The copy has no Windows compatibility setting,
  because GOG's 640x480 one is keyed on the install path. `grimlaunch.exe` applies these EMI patches:
  - `debuglog`: the release exe builds `PrintDebug`'s text and drops it; the hook appends it to `grimdebug.log`.
  - `datadir`: "Install Path" is the exe's folder, so the run never reads the install's archives.
  - `nocd`: no disc check.
  - `simtime`: every frame is 17 ms, through the exe's own fixed-step branch of the frame time.
  - `nopause`: the game keeps running when its window is not the active one. Without it, a game started behind other
    windows stops at once (no frames, and the clock of `sleep_for` stands still) and the run looks hung.
  - `windowed`: adds the game's `-w` switch.
  `run.py` also passes `-gl`: the exe's OpenGL renderer, which starts on the desktop of `offscreen.exe` (Direct3D does not).
- **The data:** one archive, `local.m4b` (`formats.lab_emi`: LABN with the name table xor 0x96). It holds `_system.lua`,
  the tests (text Lua, which the exe's parser reads), `script.tab` (`formats.text_table_emi`) and `assets_emi.py`'s files.
  ScummVM detects the folder by the loose marker `emitestdata.txt`. The original opens its fixed list of archives
  (`local`, `patch`, `lip`, `voiceAll`, `sfx`, `artAll`, `i9n`) and logs the missing ones through OutputDebugString
  without stopping.
- **Sets:** binary `.setb` (`formats.set_binary`, the layout of the game's own sets, checked against `mel.setb`). A test
  calls `MakeCurrentSet("cr_flat.set")`, and both engines look for `cr_flat.setb`. The original falls back to a text
  `.set`, but only in its own text format, which has no colormaps and no `zbuffer` line; ScummVM reads only Grim's text
  format. The sets are Grim's (`assets.SETS`) turned over, because EMI's world has y up: the original finds a point's
  sector in the x-z plane. A Grim point (x, y, z) is the EMI point (x, z, y). The setups have no rotation yet (the
  quaternion of an EMI camera is not worked out).
- **Backgrounds:** `.til` (`formats.til`: 256x256 tiles, gzipped like the game's). The original must have them:
  - without a background it crashes drawing the set (0x420a40);
  - a `.tga` background loads, but leaves its resource list broken, and about one run in three later hangs inside
    `MakeCurrentSet`, walking that list without end (0x45d3e1);
  - it also loads `pixeltest.til`, `dfltroom.til` and `default.tga` at start, so the archive has them.
- **ScummVM:** `grim-test-data.patch` also has a `monkey4` "Test data" entry: no `MonkeyUpdate.exe`, no
  `monkey4-patch.m4b`, only the folder's own `.m4b`, and no music-table dialog. ScummVM stops without `script.tab` and
  shows that dialog without the music tables; the original does neither.

What runs on EMI (2245 tests):
- **Shared with Grim:** the interpreter tests `core`, `lang`, `lua2`, `lua3`, `lua4` and `timing` (`frame_time` without
  its set changes: a set that does not exist crashes Monkey4.exe).
- **EMI only, written for EMI's coordinates:**
  - `emi_sets`: points and sectors, the edge tolerance, ramps, types, active sectors, setups, set changes, and a floor
    in Grim's x-y plane.
  - `emi_actors`: actors without a costume, placed, turned, walking (with and without following the boxes, around the
    L), stopped, walking forward, in the overworld.
  - `emi_engine`: sort order, time scale, look rate and FOV, alpha, the puck, angles, camera, overworld, layers, text,
    sound groups.
  - `zz_args_emi`: generated by `tools/gen_args.py --game emi` from the builtins Monkey4.exe has. It holds every builtin
    with no, nil, string, number, table and function arguments, an actor first for the actor builtins, and the set,
    sector, light and colour families. 28 of these calls crash the original (`expected/emi_crashers.txt`).

ScummVM's EMI on 2026-11-06 (upstream master with the patch; the reference from `Monkey4.exe -gl`): 435 of 2247 tests
differ and 172 crash or hang ScummVM (178 with opengl_shaders, which also crashes in `DimRegion`), on all three renderers.
All 435 are marked `cr_scummvm_differs`. (2026-11-05, on the grim-actor-fixes branch and against Direct3D: 387 and 156.)
- **Crashers:** every `ToggleDraw*`, `SectEdit*`, `ImGet*Vol` and `ImPopState` call, `CompleteChore`, `Pitch`,
  `Roll` and `YawCamera` with wrong arguments, `MakeCurrentSet` without a valid set, `GetVisibleThings`,
  `BlastText`, and `PutActorInSet` on an actor after `UnloadActor` (`ea_unloaded_*`: `getactor` gives null and
  `Lua_V2::PutActorInSet` uses it). The original runs all of them.
- **Differences in the argument calls:** mostly builtins ScummVM lacks or stubs (`IsLightOn`, `IsActorLooking`,
  `GetActorFOV`, `GetCamera*`, `GetLayer*`, `GetGroupVolume`, `Draw3DLine`, `DimScreen`, `PrintMessage`...),
  `LoadActor` with wrong names, and the actor rates and yaws below.

Before `zz_args_emi`, 24 of 73 tests differed. The main differences:
- **Builtins:** 139 names exist on one engine and not the other. ScummVM lacks `GetActorFOV`, `GetLayerFrame`,
  `GetGroupVolume` and `GetPhysicalBytes`, among others. It has `Is3DHardwareEnabled` and `EnableDebugKeys`, which
  Monkey4.exe does not.
- **Sectors:**
  - The original's edge tolerance reaches 1.9e-5 or more past an edge.
  - Its `GetSectorName` gives the name where ScummVM gives nil.
  - A floor in the x-y plane holds every point with z = 0 on the original.
- **Actors:**
  - On the original, `SetActorRot` starts a turn towards the yaw (`IsActorTurning` is 1 right after it, and the yaw
    still reads 0); ScummVM sets the yaw at once.
  - The default walk rate is 0.122 against 0.091, the turn rate 135 against 100.
  - Without following the boxes the original does not walk; ScummVM walks off the floor.
  - `TurnActorTo` and `PointActorAt` do not turn on the original; ScummVM turns for ever.
  - `WalkActorForward` starts a frame earlier on ScummVM, and the walk around the corner of the L differs.
- **Camera and the rest:** `SetCameraFOV` and `SetCameraPosition` do nothing on ScummVM, and the time scale does not
  speed up a walk. `LocalizeString("plain")` gives `"//plain"`. The default speech mode and text speed differ.
- **The interpreter:** number text (`1.#INF`, three-digit exponents), `tonumber` of a hex string, `ascii`, function
  names, and `sleep_for` (7 frames against 8).

EMI's costumes (`emi_costume.lua`, 2026-11-07; `assets_emi.costumes`: `formats.cosb`, `sklb`, `meshb`, `animb`).
Monkey4.exe has no `SetActorCostume` or `IsActorChoring`: `PlayActorChore(actor, chore name, costume, looping, fade)` puts
the costume on the actor and gives the chore's handle. `cr_lv.cos` has Lua Variable tracks only (`!luavCR_LV`);
`cr_ebox.cos` a skeleton, a box mesh on it and an animation. What the original needs of them, found by crashing it: the
root joint's parent is named `no_parent` (an empty name crashes it), and a mesh has one minimum and one maximum after its
centre (not two boxes) and at least one texture set. Both engines play the keys at the same frames once ScummVM counts the
first frame of a chore (it started a chore one frame late, in Grim too: fixed on klusark's `cleanroom`); a chore handle
is a number on the original and userdata on ScummVM, and a missing chore gives 2 against nil.

The interpreter's corners (`lua5.lua`, both games, 2026-11-07): the lexer's pragmas (`$if`, `$ifnot`, `$else`, `$end`,
`$debug`, `$endinput`) and their errors, escapes, number forms, the parser's scope errors, code longer than 255 bytes
(the wide jumps, long table constructors, more than 255 names), string patterns, read patterns, tags: the same on both
except that ScummVM read a file's `\r\n` as two characters (`read("{\n}...")`; fixed on klusark's `cleanroom`). A
precompiled chunk (`zz_binary.lua`; `formats.lua_chunk`, a small Lua 3.1 bytecode writer for the opcodes it uses) loads
the same on both; it runs last because after it the original's Save and Load of `save.lua` crashed now and then, even
with its globals cleared and the garbage collected. EMI's head (`ec_head`): Monkey4.exe has `IsActorLooking`, ScummVM
not (no script of either game calls it). ScummVM's `GetResidualVMPreference` (`ec_preferences`, ScummVM only): an EMI
volume below 25 wrapped round to the loudest (fixed).

iMUSE playing for seconds of the clock (`music_live.lua`): the states of `music.lua` one after another, a sequence to
its `_end` marker, the music's volume, sounds faded and panned, a voiced line with lip sync. The original has no sound
driver and does not move a sound on, so only what does not depend on how far a sound got is compared; the test is for
ScummVM's iMUSE, which mixes, dispatches and runs its triggers by real time.

The other Blocky16 modes (`movie_modes.lua`; `formats.snm` takes `(mode, colour)` frames, `formats.bomp` codes BOMP):
mode 6 (a 256-colour table), 8 (the table, BOMP coded), 5 (BOMP-coded pixels), 3 and 4 (a copy of a delta buffer), each a
640 x 480 movie (the original leaves the last frame of an earlier movie, which a smaller one would not cover): the same
on both.
Mode 2 (`formats.blocky2`, `assets._mode2_frames`): a frame whose block (10, 10) is white becomes delta buffer 1, then
the frames after it code each block another way: copies of that frame (an offset of their own, entries of the motion
table near the white block), the colours (+24, the table at +40, a 16-bit one), blocks of 4 x 4 and 2 x 2 (raw pixels
among them), blocks cut by the interpolation tables' edges. `cr_snap(key, "count")`: the same 726 white pixels on both,
block by block (2026-11-08).

EMI's music (`emi_music.lua`, `assets_emi.music`): `Textures/FullMonkeyMap.imt` (`formats.imt`) with 110 states (ScummVM
wants at least 100) over two files in both music sets (`Textures/spago`, `Textures/mego`), each a RIFF WAVE of format 0x55
holding MP3 frames of silence (`formats.emi_music`, `mp3_silence`), and a `.jmm` (`formats.jmm`: a loop). States,
the state stack, the music set and the volume run the same on both; `ImStateHasEnded` of a state that never played is
128 on the original and 1 on ScummVM, and `ImGetMillisecondPosition` without music was 0 on ScummVM against -1 (fixed).
`run.py` starts every engine with stdin closed: when `readfrom` fails, ScummVM's `read` falls back to the process's
stdin, and an open one (a shell's) blocked it in `lex_read`.

ScummVM's patch files (`patchr.lua`, Grim, ScummVM only; `formats.patchr`): a loose file read through the first of its
`.patchr`, `_1.patchr`, ... whose MD5 matches (a patch for another file, then the right one), by `dofile` and by `read`
(whose put-back seeks the patched file back). The original has none and reads the file as it is (marked).

EMI's text objects (`emi_text.lua`, with the font of Grim's data in EMI's archive: `assets.FONT`): a font named by its file,
dimensions and character positions the same on both; `GetFontDimensions` crashes Monkey4.exe. EMI's sprites and textured
meshes (`ec_sprite`; `formats.sprb`, `meshb(textured=True)`, a .tga material): loaded and played the same on both.

EMI's attached actors (`emi_attach.lua`): a rider attached to the `body` joint of `cr_ebox.cos`'s skeleton stays where it
is and follows the carrier's moves and turns, the same on both once ScummVM attaches to the joint asked for (it looked
up the previous joint's name and attached to the actor: the rider jumped by the joint's offset; fixed on klusark's
`cleanroom`); without a joint, detached twice, the carrier's alpha. A set's shadows (`formats.set_binary` writes them now:
`cr_shadows.set`) cast by an actor with a mesh (`eat_shadow`).

EMI's sounds and voices (`emi_sound.lua`, 2026-11-07; `formats.aiff` for `.aif`, the voices `.wVC` as MCMP with VIMA blocks,
and a `.lip`). `LoadSound` of a file that is not there is nil, and `PlayLoadedSoundFrom` plays with five arguments (both
fixed on klusark's `cleanroom`); a voiced line goes until ShutUpActor on both. Left: `PlayLoadedSound(h, nil, volume)`
plays nothing on the original, and after `StopSound` its handle has no volume. A `SayLine` without a voice file crashes
Monkey4.exe.

Not done: the rotation of a setup's camera, EMI's textured meshes and what a skeleton or an animation does to the mesh
(no pictures of the original's EMI), and sharing Grim's set, actor and walk tests (they need Grim's points turned over and
EMI's sets).

The argument tests of the builtins whose results vary are marked unstable by `tools/gen_args.py` (`UNSTABLE`): ticks,
memory and disk sizes, `ResReport`, `date()`, `tostring` of a function or table, and `collectgarbage()`, whose count changes
with every edit to the test sources.

## How it works

Both engines boot by running `_system.lua` and then calling `BOOT`. The test data has its own `_system.lua`
(`lua/_system.lua`), which is the test runner. It loads `_cr_tests.lua`, which `run.py` writes with one `dofile` per
test file of the game (`tests/common/` and `tests/grim/` or `tests/emi/`). It runs every test in a task of its own, writes `CR ...` lines through `PrintDebug` and ends with
`exit()`. The original writes them to `grimdebug.log` (patch.dll), ScummVM to its log (`--debugflags=scripts`).

What the original needs at start (Ghidra, `Grim_Init`): `grim.tab` is optional (`Polyglot_LoadTable`; ours is in the
folder, because it is read with fopen before any archive is open); every `*.lab` of the data folder and the folder
itself are opened (`Resource_OpenArchivesInDir`), so loose files are enough; `splash.bm` is optional; `_system.lua` is
run from source text (the exe has the Lua 3.1 parser).

| File | What it is |
|---|---|
| `run.py` | build, run either engine, compare |
| `compare.py` | extracts the CR lines from an engine log, compares two runs (`--tol`, default 1e-6) |
| `snaps.py` | pictures of the screen (`cr_snap`): reads the .bmp files and logs the box of the bright pixels |
| `formats.py` | writers: LAB, grim.tab (RCNE), .bm/.zbm (raw, RGB565), .cmp, text .set, text .cos, binary and text .3do (text models may have faces with materials; a header or radius of your own if asked; `model_bounds` works out the box as the original does), .mat (8-bit, one texture a cel), text .key |
| `assets.py` | the data: the sets (`cr_flat`, `cr_edge`, `cr_stair`, `cr_open`: cr_flat with a far z-buffer, where models are drawn; `cr_ell`: an L of floors), backgrounds, the text table, costumes, drawn models, a keyframe, `cr_extra.lab` |
| `lua/_system.lua` | the runner (`cr_test`, `cr_log`, `cr_unstable`, `cr_scummvm_differs`, `cr_frames`, `cr_until`, `cr_snap`) |
| `tests/common/*.lua` | the tests both games run (the Lua interpreter, frame time) |
| `tests/grim/*.lua`, `tests/emi/*.lua` | each game's own tests |
| `testfiles.py` | which test files a game runs, in which order |
| `expected/original.log` | the original's results, the reference for ScummVM runs |
| `expected/unstable.txt` | values that differed between `--save`'s runs of the original and are not marked `cr_unstable` (not compared) |
| `scummvm/` | the engine patch and its build script |
| `tools/mark_known.py` | marks the tests ScummVM gets wrong (`cr_scummvm_differs`) from the last ScummVM run |
| `tools/args_differs.txt` | the argument tests ScummVM gets wrong (`args_differs_emi.txt` for EMI; read by `gen_args.py`) |
| `tools/labls.py` | lists the members of a LAB (to look at the layout of the game's formats; nothing is copied) |
| `tools/read3do.py` | prints the structure of a binary .3do (checks what `formats.model3do` writes) |

## Writing a test

```lua
cr_t_my_case = function()
	MakeCurrentSet("cr_flat.set")
	local a = cr_actor("cr_flat.set")       -- tests/grim/actors.lua: an actor at the origin, following the boxes
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

What Lua cannot read can be looked at on the screen: `cr_snap(key)` saves a picture of it, and run.py logs under `key` the
box of its bright pixels (`x0 y0 x1 y1`, or `none`). The tests draw white text on the dark backgrounds, so the box is that
of the text. The call is `PrintDebug("CRSNAP:<file>")`: on the original, patch.dll saves the back buffer with the game's own
screenshot function (`Render_SaveScreenshotBmp` 0x487340, the Backspace+S debug key; only on v1.01, whose bytes it checks);
on ScummVM, the test patch draws the scene and saves it (ScummVM's picture is grey, which does not change the box; with
TinyGL it presents the frame first, as only one in 8 is). `cr_snap(key, "dark")` gives the box of the pixels darker than
any background (a shadow), `cr_snap(key, "lit")` the box of the others (what an iris leaves open). The original's picture is
the frame drawn before the call, ScummVM's the scene as it is at the call: a picture right after a change in the same frame
differs for that reason alone, so the tests let a frame pass first.

`compare.py` puts a test in one of three classes. `same`: equal within 1e-6. `close`: all differing values are numbers
within 1e-3 (`--close`). `DIFF`: anything else.

Original-only traps found so far:
- `WalkActorTo` moves an actor only when it follows the boxes (`SetActorFollowBoxes`).
- `SetSelectedActor` on an actor without a costume crashes the original.
- `GetAngleBetweenActors(a, b)` crashes when `a` does not follow the boxes (it reads the walker's heading).
- There is no `sleep_for`.
- Costume tags are compared letter for letter: `'MMDL'`, `'KEYF'`, `'MESH'`, `'MODL'` upper case, `'luav'`, `'cmap'`, `'imls'`
  lower case, as the game's costumes write them (`formats.COSTUME_TAGS`). A costume with `'mmdl'` does not load
  (`GetActorCostume` is nil). ScummVM upper-cases the tags and loads it.
- `SetShadowColor` and `GetFontDimensions` crash the original whatever the arguments.
- A chore of length 0 as an actor's rest chore hangs the original.
- `FreeObjectState` frees the bitmap of the object state: a set with that bitmap as its background crashes when it is
  loaded afterwards. Object states and images in the tests use `cr_obj.bm` for that reason.
- `IrisUp` / `IrisDown` with a time of 0 stop the original (elapsed / time is 0 / 0; the argument probe's valid call has
  it, so all its iris calls are skipped). `NextSetup` / `PreviousSetup` in a set with one setup and
  `MakeCurrentSetup` of a setup that does not exist crash.
- The rest of the crashes with wrong arguments are listed in `expected/crashers.txt` (found by the argument probe).

## The Remastered

`python run.py remastered` runs the same Grim tests on Grim Fandango Remastered (`GrimFandango.exe` and its dlls copied
from `REMASTERED_INSTALL`, the Steam folder by default; only the debuglog patch) and compares it with `expected/original.log`.
It is a report: the Remastered is not the reference, and its crashes go to `expected/remastered_crashers.txt`.
2026-11-08: 505 of 5087 tests differ from the original.

`python run.py scummvm --remastered` runs ScummVM in its Remastered mode: the test patch has a second detection entry,
for the marker `grimremasteredtestdata.txt` (with `ADGF_REMASTERED`), and the data gets the Remastered's text table
(`grim.en.tab`, `formats.text_table_remastered`) and commentary list (`commentary_def.txt`, `formats.commentary_def`,
`assets.COMMENTARY`). It builds into `build_remastered/` and runs in `run/remastered_scummvm/`; the reference is
`logs/remastered.log` (the last `run.py remastered`) when there is one, else the original's. This is a report too and never
fails (the marks are for the original); its crashers are `expected/remastered_scummvm_crashers_<renderer>.txt`.
`tests/grim/zz_remastered.lua` calls the Remastered's own builtins (`rem_*`; "missing" on the original and Grim mode).

Found this way (fixed on `cleanroom`): EnableCommentary, ShowCursor, AddHotspot / QueryActiveHotspots and Save (the
original's `Save(file)`; the Remastered saves only to a numbered slot and does nothing with a name) asserted. Still different
from the Remastered exe: most of ScummVM's Remastered builtins are stubs (ImGetCommentaryVol is 0 and does not follow
ImSetCommentaryVol, AddHotspot gives userdata where the exe gives a number, OverlayCreate, GetFloorWalkPos, the key names and
the save status functions give nil or placeholders); ScummVM has HideMouseCursor, UpdateMouseCursor, UpdateUIButtons,
DestroyAllUIButtonsImmediately, CacheCurrentWalkVector and RemoveBorders as builtins, the exe has none of them.

## On GitHub

`.github/workflows/scummvm-cleanroom.yml` runs `run.py scummvm` for Grim and EMI on a Windows runner every night, on a
push that changes `cleanroom/`, and by hand (Actions, "Run workflow": another repository or branch of ScummVM, other
renderers). It builds the branch `cleanroom` of klusark/scummvm: the test patch as a commit of its own and, after it, the
fixes in progress of `~/scummvm-cleanroom` (push the worktree's work there to test it). For a branch without the test
patch (upstream master), "apply_patch" applies `scummvm/grim-test-data.patch`. The build is in the runner's MSYS2 (UCRT64,
ccache), with Mesa's software OpenGL (llvmpipe, `opengl32.dll` next to `scummvm.exe`: the runner has no GPU), and it is
compared with the expected logs here; the originals are not run there. The job fails on a regression or a crash without
a mark; the summary lists them and the logs are kept as an artifact. The marks follow upstream master: a test that only
the fixes in progress make the same is "fixed" there (its mark stays until upstream has the fix).

Both games run with every renderer (`opengl`, `opengl_shaders`, `software`), the renderers of a game at once
(`tools/parallel.sh`, each step in its own `CR_PARALLEL_DIR`, llvmpipe with one thread per engine: `LP_NUM_THREADS=1`).
A second job, `coverage`, builds the same ScummVM with gcov (as below), runs both games and the Remastered mode with
every renderer on it, all nine at once, and writes the coverage of engines/grim and
graphics/tinygl (`covreport.py --all`, every part with its total) to the run's summary; the page of each file, with the
lines never run, is the artifact `coverage` (`index.html`). Its results are not compared and it never fails the run.

## Coverage of ScummVM

A gcov build of the cleanroom worktree measures which lines of engines/grim the tests run:

```sh
mkdir ~/scummvm-cleanroom/build-cov && cd ~/scummvm-cleanroom/build-cov
CXX="ccache g++" CC="ccache gcc" CXXFLAGS="--coverage -fprofile-update=atomic -O0 -g" \
    LDFLAGS="--coverage -fprofile-update=atomic" ../configure --disable-all-engines --enable-engines=grim,monkey4
sed -i 's/^CXXFLAGS := \(.*\)$/CXXFLAGS := \1 -DCR_GCOV/' config.mk   # Exit() writes the counters (see below)
make -j16
cd ~/grim_tools/cleanroom && tools/parallel.sh --coverage   # every game and renderer at once; the report: reports/coverage/
```

`tools/parallel.sh --coverage` runs Grim, EMI and Grim in the Remastered mode, each with every renderer: nine `run.py
scummvm` at once, each with `--work` (its own build/, run/ and logs/ under run/parallel/, nothing written to expected/),
then `autorun/tools/covreport.py --all` into reports/coverage/. That takes about 4 minutes, against 15 one after the other. The
nine add their counters to the same .gcda files when they end, and libgcov locks each file while it adds to it (on Windows
too, with `_locking`). `-fprofile-update=atomic` makes the counters safe between ScummVM's own threads (audio, timers):
without it two threads can lose each other's counts, the counts no longer add up, and the ones gcov works out from the
others can go negative. 2026-11-10: the same coverage both ways (29838 lines one after the other without atomic, 29835 in
parallel with it; the few lines apart are the timing of sounds and of Lua's garbage collector).

`SCUMMVM` must be a Windows path. gcov writes the counters when the process ends, so the engine's shutdown (its
destructors) is counted too; ScummVM ends the whole suite cleanly (exit code 0, 2026-11-07; it used to crash after `exit()`,
and `Exit()` dumped the counters itself, which left the shutdown out). A run killed as hung writes nothing, so the runner
also asks for the counters every 200 tests (`PrintDebug("CRGCOV")`: `__gcov_dump()` and then `__gcov_reset()`, so that the
write at the end still happens, in a `CR_GCOV` build; nothing otherwise): such a run loses only what ran since. 2026-11-05: 42.3% of the lines (11596 of 27397, without lua, emi, remastered, tinygl).
2026-11-07: 41.7% (10357 of 24864) before and 49.0% (12192 of 24868) after the tests of saving and loading (`save.lua`),
sounds of our own (`sound.lua`), the registry, the primitives and the start-up state. 2026-11-10 (`--all`, every game
and renderer): 69.4%, 29838 of 43016 lines (grim 69.5%, emi 68.3%, tinygl 57.9%, lua 87.6%, remastered 63.5%). What is left is mostly iMUSE's music (its state tables) and streaming, the shader renderer (the tests use `gfx_mode=opengl`),
and the debugger.

## Wrong arguments and coverage

`tests/grim/zz_args.lua` is generated by `tools/gen_args.py`. It calls every builtin of the original with no arguments, nil, a
string, a number, a table and a function, and the actor builtins also with a real actor followed by each of those. There
is one test per call. Builtins that would end or block the run, or change the runner itself, are left out (the list is in
the script). On top of that:
- families (text objects, fonts, primitives, images, object states, colours, lights, sets, sectors) get a real first
  argument of their kind and then each wrong one; the actor chore builtins get wrong chores and costumes;
- every position of a builtin gets each wrong value (nil, string, number, table; -1 and 1e9 for numbers) while the other
  positions are valid. The kinds of the positions come from `tools/signatures.py`, which reads how the game's decompiled
  scripts call each builtin (only to learn the signatures; `tools/signatures.json`), and from `OVERRIDES` in gen_args.py.
Every call starts from the same state (`cr_args_for`): each builtin gets an actor of its own, at the origin facing 0,
in `cr_flat.set`, and a builtin of a family gets a fresh handle. With one shared actor, a call that broke it made every
call after it fail, and they were blamed. Each builtin also gets `p0`, the call with all positions valid: when that
crashes an engine, all its position calls are skipped with it. In all: 4580 calls of 333 builtins. The original is the reference. **Where ScummVM accepts what the original refuses,
or refuses what it accepts, that is a bug like any other difference**: the values or the Lua errors differ in the
comparison.

A test that crashes or hangs an engine is found by `run.py`. A run that ends without SUMMARY, or writes nothing for 15 s
(`CR_STALL`), is stopped. The test without an END is run again, and only when the run dies in it a second time is it
skipped (`CR_SKIP`) and the whole run repeated. The original's crashers go to `expected/crashers.txt` and are skipped on both
engines (there is no reference). ScummVM's are reported as bugs (`logs/scummvm_crashers.txt`). A crash that moves to
the next test after each skip is a test that leaves the engine in a bad state. Look for it before trusting the list
(the object-state bitmap above was found that way).

`python tools/coverage.py [--list]` tells how many builtins the tests call by name and which are only in the probe.
`python run.py original --only a,b,c` runs a list of tests.

## Determinism of the original

With `simtime` every frame is 17 ms (`frame_time` checks it), and repeated runs give the same values except the order of
`next()` and the values that are not meant to repeat (ticks, memory and disk sizes, dates, addresses). Text and speech
end by real time, not by the game's clock, so how many frames a SayLine stays may vary (`say_line` puts back what it
changes, so that nothing after it depends on that). The original's Lua hashes strings and tables by address. LUA.DLL's own C runtime places its small-block heap
where Windows finds room, and that moves by multiples of 64 KB from run to run; the low bits of every address repeat.
Two attempts did not change it, so both were dropped: ASLR off for the process (a creation flag in grimlaunch), and LUA.DLL's
and the exe's heap calls redirected to a fixed arena from patch.dll (Lua's objects are not allocated there). The first region
is reserved before patch.dll loads. Fixing it would need patch.dll loaded at the process entry, before the runtimes start.
Until then, tests must not depend on table order (`next_order` marks its order `cr_unstable`).

## Differences found (ScummVM grim-actor-fixes, 2026-11-05)

4740 tests: 3886 the same, 3 close, 851 differ (most of them in the argument probe). Every difference is a ScummVM bug
to look at, whether ScummVM is stricter or more permissive than the original.

Argument probe (`zz_args.lua`, 4580 calls; classified from the logs):
- 64 builtins of the original are missing in ScummVM (503 calls): among them `GetActorScale`, `GetCameraInterest`,
  `IsActorLooking`, `GetLightPosition` / `Intensity` / `Type` / `Angles`, `IsLightOn`, `FindLight`, `PutActorAtOrigin`,
  `WalkActorToInterest`, `SnapToPlane`, `GetSectorVertices`, `ScreenToWorld`, `GetTickCount`, `ascii`, `exp`, `log`,
  `log10`, `atan2`, `getenv`, `rename`.
- 36 builtins crash or hang ScummVM with arguments the original takes (145 calls, `expected/scummvm_crashers_opengl.txt`, skipped by default; `--fresh` runs them again): the
  object state builtins (`NewObjectState`, `SendObjectToFront` / `Back`, `SetObjectType`), `SetActorColormap`, the text
  builtins with a missing or wrong font (`LockFont`, `MakeTextObject`, `BlastText`, `SayLine`), `GetImage`,
  `MakeCurrentSet` / `MakeCurrentSetup` of a missing set or setup, the shadow builtins (`SetActorShadowPlane` /
  `Point`, `AddShadowPlane`, `SetActiveShadow`, `ActivateActorShadow`) with out-of-range shadows, `SetActorHead`,
  `SetActorCostume` / `PushActorCostume` of a missing costume, the chore builtins with a number as the costume,
  `EnableControl` / `DisableControl` / `GetControlState` out of range, the iMuse parameter calls with -1, `GetVisibleThings`
  with an argument, `GetActorNodeLocation` with node -1.
- 34 builtins give different values for the same arguments (164 calls), e.g. `GetActorChores`, `GetActorCostume`,
  `GetActorRect`, `GetActorTurnRate`, `GetShrinkPos`, `IsSectorActive`, `WorldToScreen`, `DrawLine` / `DrawRectangle`,
  `ImStartSound`, `ImGetParam`, `LocalizeString`, `PerSecond`, `ReadRegistryValue`, `FunctionName`, `format`, `strlen`,
  `strlower`, `strupper`, `deg`, `asin`, `acos`.
- A Lua error on ScummVM only: `ImSetVoiceEffect`, `TextFileGetLineCount`, `WalkActorVector`. On the original only:
  `find_script` (and `date` / `tostring`, whose values vary).
- The original crashes on 120 calls of 20 builtins (`expected/crashers.txt`): `SetShadowColor` and `GetFontDimensions`
  with anything, `IrisUp` / `IrisDown`, `GetKeyLength`, shadow planes out of range, `SnapToPlane`, `NewObjectState` with a
  wrong setup, the iMuse parameter calls with nil.

Hand-written tests, besides the per-frame walk and turn values:
- The walk ends one frame's step past the target on the original (more at a higher rate), with a final yaw 2.3 degrees off.
  After `PutActorAt` the original keeps walking. Changing the walk rate during a walk overshoots too.
- The original eases into `TurnActorTo`; ScummVM turns at a constant rate. `WalkActorForward` into a wall slides on the
  original and stops dead on ScummVM; a model actor walking into the outer wall stops on the original and slides on
  ScummVM. `WalkActorToAvoiding` does not move the actor on ScummVM.
- ScummVM did not fire the LUAV keys of a costume (`CR_LV` was never set): its text splitter lowercases a costume, so
  the component set `cr_lv`; the original keeps the name's case (fixed on klusark's `cleanroom`, 2026-11-07). Both set
  it at the frame times the chore keys give. Turn chores are not played on ScummVM. `IsActorChoring(a, nil)` gives the chore
  on the original, 0 on ScummVM; `GetActorChores` is nil on ScummVM. Chore fades differ.
- `GetActorNodeLocation` on the original gives the node offsets of the model without the actor's position or turn
  (the faceless model is never drawn, which may be what updates them). ScummVM gives world positions.
- Box collision (`SetActorCollisionMode(a, 1)`) between two faceless models gives NaN positions on the original; sphere
  collision matches ScummVM to 1e-6.
- Model header (`model_header.lua`, ScummVM commit dc7e5c2 "Fix collision handling for box models"). The end of a binary
  .3do has a radius, a bounding box, a centre and an insert offset. The original reads them and then throws them away:
  `rdModel3_LoadPostProcess` (0x40c090) works out the box from the vertices through the node transforms, the centre as
  the middle of the box and the radius as half its diagonal (`rdModel3_CalcBoundingBoxes`). The sphere of each actor in a
  collision is at its model's centre (`Collision_TestActorAgainstOthers`, 0x4939f0). Results, against the original:

  | tests | before dc7e5c2 | with dc7e5c2 |
  |---|---|---|
  | `model_collide` (box at the origin) | sphere stops elsewhere (the moving actor's sphere half the box up, the other's at its feet) | same (1e-6) |
  | `hdr_meshx_*`, `hdr_nodex_*` sphere (box 0.5 m to the side, by vertex or by node) | differ | within 1e-3 |
  | `hdr_ctrx`, `ctrz`, `bbig`, `bside` (header unlike the mesh) | differ | differ: ScummVM uses the header's centre, box and radius; the original gives what it gives for `cr_box` |
  | `hdr_float_*` (box from 1 m up) | differ | the mover is left up to 0.013 m off the floor; the original puts it back on the floor |

  So dc7e5c2 puts the spheres where the original has them for real models, whose header matches their mesh. Two
  differences remain. ScummVM should work the box, the centre and the radius out from the mesh as the original does, not
  read them from the file. And it should not leave the actor off the floor after a sphere push with a z part.
- Collision mode of the mover (`collision_mode.lua`, ScummVM commit 7240c11; report for the PR in
  `reports/7240c11-collision-mode.md`). On the original, only the mode of the other actor counts. On master, a mover with
  mode box walks through a box wall and takes another path around a sphere wall; with 7240c11 every mover mode gives the
  same result. grim-actor-fixes matches the original for every walk forward. No ScummVM build collides during
  `WalkActorTo` (`cm_to_*`), and the original does.
- Model formats (`model_format.lua`, models in assets.py `FORMAT_MODELS`). The original reads binary (LDOM) and text .3do
  (`rdModel3_Load` 0x40a980 picks by the magic) and after either works the box, the centre and the radius out from the
  vertices through the full node transforms (`rdModel3_AccumulateNodeBounds` 0x40c710: rotation, position and pivot). It
  uses neither the radius line of a text model nor the header of a binary one. ScummVM reads the binary header; from a text
  model it reads the radius and works the box out from each mesh's position plus its vertices, without the node's
  rotation (`Model::loadText`). Results, against the original:

  | tests | ScummVM |
  |---|---|
  | `mf_cr_tbox_*`, `cr_tnodex` walls, `cr_piv`/`cr_tpiv` walls, `cr_rot` (binary, turned) | same: text and binary agree when no node is turned |
  | `mf_cr_trad_*`, `mf_cr_brad_*` sphere (radius 3 m in the file, text or binary) | differ: ScummVM uses the file's radius, the original the box's half diagonal |
  | `mf_cr_trot_wall_box`, `mf_cr_tprot_wall_box`, `mf_cr_trotx_mover_sphere` (text, node turned) | differ: ScummVM's box for the text model is the unturned one; the binary ones are the same |
  | `mf_cr_tnodex`, `cr_piv`, `cr_tpiv`, `cr_prot`, `cr_tprot` as the mover, sphere | differ in either format: `Actor::getSphereInfo` puts the sphere at `_pos + _center` without turning the centre with the actor's yaw (20 degrees here; the box path does turn it) |
  | `mf_cr_float_*`, `mf_cr_tfloat_*` (box from 1 m up) | differ in either format (as `hdr_float_*`) |
  | `mf_rects` | `GetActorNodeLocation` on the original depends on the format: world positions for a text model (as ScummVM, but with the node's pivot counted twice: `cr_tpiv` node 1 at 1.5 m, ScummVM 1.0), the node offsets for a binary one (node 0 at 8 times the actor's position) |

  Fix: ScummVM branch `grim-model-bounds` (c678e70885d, on origin/master) works the box, centre and radius out from the
  vertices through the node transforms for both formats, as the original does. On grim-actor-fixes, 15 tests that differed match
  the original: the `mf_cr_trad`/`brad`/`trot`/`tprot`/`trotx` cases exactly, the `hdr_ctrx`, `ctrz`, `bbig`, `bside`
  sphere cases within 1e-3. `hdr_ctrz_both_sphere` goes from the same to within 1e-3; no test differs that did not.
  The lying box (`cr_rotx`) as a wall is too low (0.3 m) for the mover's sphere: no engine collides with it. The two engines
  turn a node the same way (the head node of `cr_trotx` is at the same place on both).
- Text position (`text_pos.lua`, with `cr_snap`). The original places the line of an actor once, when `SayLine` starts
  (`Actor_CreateSubtitle` 0x48b2e0): above the screen rectangle the actor was drawn in; for an actor without a costume, in
  the current set, centred above the point its position projects to (hidden or not); else, and when the point is off the
  screen or behind the camera, at the off-screen position. The `x` and `y` of SayLine's table replace that point (`y` is
  then the top of the text). The text is kept 40 pixels from the sides and 10 from the top and bottom, and wraps when it
  does not fit. ScummVM puts the line of an actor without a costume at the top left corner (the screen box of no costume is
  0, 0), ignores the table's `x` and `y`, puts a hidden actor's line at the off-screen position, and wraps a line wider than
  the screen into six at the left; the original keeps it on one line (11 to 627). The off-screen position matches, except
  at the corners (a few pixels). A model without faces is never drawn: both use the off-screen position for an actor with
  such a costume, so the placement above a drawn actor is not tested yet.
- The iris (`iris.lua`, with `cr_snap(key, "lit")`). On the original `IrisDown(x, y, ms)` / `IrisUp` store the clock, x, y
  and the time (IrisUp: negated); each frame `Engine_RenderFrame` takes t = |elapsed / time| and `Render_DrawIris`
  (0x486d00) blacks out the screen outside a rectangle from (t x, t y) to (640 - t (640 - x), 480 - t (480 - y)) (1 - t for
  IrisUp; t is a float, each edge truncated on its own). Stock ScummVM's iris is a frame ahead (it adds the frame time in
  the frame of the call; the original's first frame is t = 0: an `IrisUp(x, y, 1)` shows one black frame) and rounds the
  right and bottom edges differently, and TinyGL blacked one more column and row there; with the fix (klusark's branch
  grim-iris-timing, in `~/scummvm-cleanroom` too) all three renderers match to the pixel. The sign of the time is the
  direction on the original (`IrisDown(-ms)` opens); ScummVM ends a negative time at once. The original redraws only what
  changed: an iris started again from open leaves the old black until it closes back past it. A closed iris stays closed
  through `MakeCurrentSet`, and text objects are drawn over it, on both. `IrisComplete` (1 when no iris runs or it is
  closed; 0 for the 12 frames of a 170 ms one) and `IrisClear` (the screen open at once) are not in ScummVM.
- Renderers: `run.py scummvm` runs every test with each of Grim's renderers (`opengl`, `opengl_shaders`, `software`
  TinyGL; `--renderer` picks some), one log each (`logs/scummvm_<renderer>.log`). 2026-11-05: 3950, 3953 and 3954 tests the
  same as the original. With shaders, `WorldToScreen` is wrong (nil for points on the floor, the centre of the screen for
  one 3 m up) and so is every line placed by the position of an actor. TinyGL draws a model 1 pixel larger on each side
  than the other two, and `Is3DHardwareEnabled` is nil there, as the first value on the original.
- Drawn models (`draw.lua`, `keyframe.lua`, `head.lua`, `shadow.lua`, `sight.lua`; text models with faces and an 8-bit
  material, drawn without lighting in `cr_open`). A z-buffer of 0xffff hides every model on both engines; the backgrounds
  of the other sets keep it (`ScreenToWorld` reads the z-buffer: points on the floor there, NaN in `cr_open`, and the
  depth of the set before for a frame or two after `MakeCurrentSet`; ScummVM has no `ScreenToWorld`). In a material the
  second word of the texture format is the bits a pixel: 0 crashes the original.
  - A drawn box is at the same place on both engines, its top left corner 1 pixel further down and right on the original.
    `GetActorRect` gives x, y, width, height on the original and x0, y0, x1, y1 (1 or 2 pixels larger) on ScummVM.
  - The line of a drawn actor is above the rectangle it was drawn in on both, 2 pixels lower on the original.
  - The components (material cel, mesh shown or hidden, sprite, bitmap) do the same on both.
  - Lit models (`zz_lit.lua`, 2026-11-08: after the saves, as with them before it the original crashed in their loads now and then: the white box with lighting mode 3 in `cr_lit.set`, black, with an omni, a direct and
    a spot light; `cr_snap(key, "mean")`). The original draws it at the light level of its vertices (the 5th number of a
    vertex line, `formats.model3do_text` `vertex_light`: 1 gives 248, 0.5 gives 121, 0 black) whatever the lights do: none
    of them adds anything (rdModel_DrawMesh lights the mesh in mode 3 with rdLight_CalcVertexIntensities, which starts each
    vertex from that level; why no light of the set reaches the box is not known yet: its software renderer?
    `Last3DDevice` is none in the run). ScummVM ignores the vertices' level and lights the box with the set's lights (colour
    15 15 15, as the game's sets: ScummVM divides the intensity by 15). Found and fixed on `cleanroom`: a light turned off
    went on lighting the models in OpenGL and TinyGL (`Set::setupLights` left the GL slots past the lights that are on as
    an earlier frame had them), and TinyGL's spot lights lit nothing (`tglLightfv` passed a spot direction of zeros).
    OpenGL and TinyGL now give the same (a spot 239 or so); with shaders a spot is dimmer (33) and, with no light on, the
    box is lit unless its vertices' level is 0. A box rolled 120 degrees faces away from the direct light and is black on
    all of them (the original draws it at 248).
  - Keyframes: the box moves the same way on the screen, but `GetActorNodeLocation` on the original stays at the rest
    position while the keyframe plays; ScummVM gives the animated position. A Lua Variable track in a costume that also has
    a model never sets its variable on ScummVM (it does in a costume of only a Lua Variable). `GetActorChores` is a table
    on the original, nil on ScummVM.
  - Heads (`SetActorHead`, `ActorLookAt`): the head turns differently. Looking at a point in front of or behind the actor the
    original does not move the head at all; ScummVM pitches and turns it. To the side both turn it, by different angles.
  - Shadows set up as the game's scripts do (`SetActiveShadow`, `SetActorShadowPoint`, `SetActorShadowPlane`,
    `AddShadowPlane` on a special sector `shadow1`, `ActivateActorShadow`): the original draws none; ScummVM draws them,
    bright (not in the shadow colour).
- Archives (`lab.lua`, `cr_extra.lab` in the game folder): the same on both; a file that is both loose and in the archive
  is read loose.
- Paths (`paths.lua`, `cr_ell`): the walk round the corner of an L takes the same way, but the original stops about 3 cm
  past the point it was sent to. Walking forward at 45 degrees into the edge of the floor, the original stops at x = -0.90
  and ScummVM slides along the edge to the corner (x = -2).
- `MakeSectorActive` with a number does nothing on the original. A sector switched on stays on across a change of set on the
  original; ScummVM resets it. The current setup is kept across a change of set on the original; ScummVM goes back to 0.
  `GetCurrentSetup` of a set that is not current is 0 on the original and nil on ScummVM.
- Camera: `SetCameraFOV`, `SetCameraRoll` and `SetCameraPosition` change the setup on the original and nothing on ScummVM;
  `GetCameraLookVector` differs. `WorldToScreen` returns whole pixels on the original; with a rolled camera ScummVM is up to
  31 px off.
- `RotateVector` and `GetAngleBetweenVectors` are within 1e-3 (the original's sin/cos tables).
- Text: `LockFont` of the same font gives the same handle on the original; an empty text object is 12 pixels high on the
  original and 0 on ScummVM; wrapping at width 100 gives 94 on the original and 98 on ScummVM. `SetTextSpeed(20)` is
  clamped to 10 on the original.
- Primitives (`DrawLine`, `DrawRectangle`, `DrawPolygon`) are numbers on the original, userdata on ScummVM.
  `IsMoviePlaying` / `IsFullscreenMoviePlaying` are true on ScummVM with no movie.
- The original kills a script that runs between 100 000 and 1 000 000 loop steps without `break_here` ("Killing Lua script
  that ran without a break_here() for a really long time!"); ScummVM lets it run.
- `TextFileGetLine` / `TextFileGetLineCount` read the game folder on the original; ScummVM looks in the saves folder.
- Registry: an unset value reads 96 on ScummVM (nil on the original); numbers come back as strings on the original.
  `registry.lua` (2026-11-07): on the original only the keys of `grim.ini` (`good_times`, `GrimDataDir`) have values;
  ScummVM fills the game's keys from its own configuration (volumes, text speed, gamma, ... as numbers, the TRUE/FALSE ones
  as strings) and has no `good_times`. A value written is read back on both; digits written as a string read back as a
  number on ScummVM, as a string on the original.
- Number text: the original's C runtime writes 3-digit exponents (`1e+015`) and `1.#INF`; `tonumber("0x10")` is nil.
  `LocalizeString("no slashes")` gives `"//no slashes"` on the original. `FunctionName` is written differently.
- `GetMemoryUsage` and `GetTickCount` are numbers on the original, nil on ScummVM.
- About 87 Lua builtins exist only on the original; `sleep_for`, `pause_script`, `unpause_script` only on ScummVM.
- Saving and loading (`save.lua`, 2026-11-07). `Save(file)` / `Load(file)` happen between frames, and the Load brings the
  Lua tasks back: a test goes on after its `Save` a second time (the registry, which is not in a save, tells the two passes
  apart). The game saves from its menu, in `RenderModeUser(TRUE)`: the original's `Engine_LoadGame` leaves mode 4 (no actor
  moves, no chore advances) until `RenderModeUser(nil)`; ScummVM goes on at once (`save_mode`). Actors (place, attributes,
  costumes, a walk), sets (setup, sectors, lights), text objects, primitives, object states and Lua values (tables,
  functions, a task) come back the same on both. `SubmitSaveGameData` reads its strings from index 0; without a
  `system.saveGameCallback` the original writes none and `GetSaveGameData` is an empty table, ScummVM ends with "Unable to
  find requested section of savegame!" (`save_data_none`, a crasher); for a save that is not there ScummVM returns a table,
  the original nil. On the original, after `SetEmergencyFont` every Load crashes when it draws a text object
  (`TextObject_Draw` 0x48ca13, no font: `zy_save_emergency.lua`, last), and so did a Load when the task that saved runs a
  closure with upvalues (in `Lua.dll`): the save tests are one function, their cases in a table. `SetTextSpeed` is not in a
  save on the original.
- Sounds (`sound.lua`: `cr_tone.wav` and `cr_long.wav`, 16-bit PCM, `formats.wav`). Both engines start them and give the
  same params (`ImGetParam` play count, group, priority, volume, pan; out-of-range values clamped the same; a sound
  started twice has a play count of 2). Neither ends a sound or advances a fade within the test: the original runs on
  `NULLMUSE.DLL` with no sound driver, and ScummVM's iMUSE runs on the wall clock, which the 17 ms frames outrun.
- Movies (`movie.lua`, 2026-11-07: `formats.snm`, gzipped SMUSH as the game's: SHDR, FLHD, FRME frames of raw Blocky16
  (mode 0) with silent VIMA sound). The original's Insane player reads more of a frame than ScummVM: the frame size at +8
  and +12 of each Bl16 header (`Blocky16_DecodeFrame` 0x4ccd00) and the size and pixel format of FLHD's Bl16
  (`Blocky16_Prepare` 0x4cc3c0); without them it reaches an error message that crashes in `sprintf`. Both play the movie
  by real time while the test's frames run far faster: the tests wait for seconds of `date` (and raise their frame
  limit, `cr_allow_frames`). The same on both: the place on the screen (clipped at its edge; 0 0 without a place;
  fullscreen is not scaled), the end of a movie, looping, StopMovie, a missing movie. `PauseMovie` is the other way
  round: the original pauses with nil (FALSE) and goes on with TRUE (`Lua_PauseMovie`: `Movie_SetPaused(lua_isnil(arg))`),
  though the game's pause menu calls `PauseMovie(TRUE)` to pause; ScummVM pauses with TRUE. The original leaves the last
  frame of a movie that another replaced (it redraws what changed). TinyGL crashed on the second movie of a run:
  `GfxTinyGL::releaseMovieFrame` deleted the frame's blit image and kept the pointer (fixed on klusark's `cleanroom`).
- Voices and lip sync (`lipsync.lua`, 2026-11-07). `SayLine(a, "/id/")` plays `<id>.wav` through iMUSE and reads
  `<id>.lip` (`formats.lip`: `LIP!`, the count, then the start in 16 ms ticks and the phoneme of each entry); the voices are
  MCMP with the RIFF header stored and the samples in VIMA blocks, as the game's (`formats.mcmp`, `formats.vima`: the
  encoder runs the decoder of `vima.cpp` and picks the code nearest each sample). A talking costume (`cr_talk.cos`)
  sets `CR_LV` per chore: the first phoneme's shape plays (d: shape 2), a voice without a lip sync file mumbles, a lip
  sync file of silence plays stop_talk, ShutUpActor ends in stop_talk, the same on both. ScummVM plays stop_talk inside
  SayLine, the original on the next frame (the value at once differs). The original does not move a voice on (no sound
  driver), so only the start of a line is compared.
- Music (`music.lua`: `formats.imus`, iMUSE's own format with a MAP of regions, a TEXT marker and JUMPs, under the names
  of the state and sequence tables: `1001 - Manny's Office.IMC` and others). `ImSetState` / `ImSetSequence` open, stream
  and jump in ScummVM; `ImGetParam` by file name sees no music on either engine (the scripts never open it by name), so
  the tests show that the changes run, the same on both.
- `IsMoviePlaying` / `IsFullscreenMoviePlaying` are true on ScummVM as it starts (`aa_boot.lua`): the `MoviePlayer` starts
  with `_videoFinished` false, until a movie call deinits it, so the argument probe's values depend on what ran before.
- `GetTextObjectDimensions` of a killed text object crashes ScummVM (`TextObject::getBitmapWidth` with no object,
  `text_dims_killed`); the original gives a number.
- ScummVM's crashes in the argument probe at `WalkActorForward` (0xC0000409, 0xC0000374, in a different call from run
  to run) came from earlier calls (found by bisecting the tests, then gdb; fixed on klusark's `cleanroom`, 2026-11-07):
  `SetActorShadowValid` on an actor with no active shadow slot wrote `_shadowArray[-1]` and corrupted the heap, and
  `Actor::getSphereInfo` asserted on a costume without a model (the walking actor collides with every actor of the set).
  Two more showed once the run went on: any registry key ScummVM does not know (`WriteRegistryValue("CrSavePass", ...)`
  of `save.lua`) was the music volume, which was 0 after the next load (`ImGetMusicVol`); and after a movie that is not
  there (Theora fallback) the SMUSH player deleted the Theora decoder that `~MoviePlayer` then closed and deleted again,
  crashing ScummVM on the way out.
- EMI's movies (`emi_movie.lua`, 2026-11-07: `formats.bik`, Bink 1 revision i as the game's movies, written as
  `Movies/<name>.m4b`). The writer uses only what both decoders must have: every 8 x 8 block a fill block, each bundle's
  Huffman tree 0 (raw nibbles), no sound track, every frame a key frame; the 32 bits that start a BIKi frame are the
  byte offset of its second plane (the game's movies have it so; ScummVM and FFmpeg skip it). The original's
  `binkw32.dll` (1999) and ScummVM's `BinkDecoder` both play them to the end (ScummVM's frame is exactly the colour
  written). The original opens `Movies/<name>.m4b` as a file (`CreateFileA`, then `BinkOpen`), the Bink data at 0 when
  there is no SMUSH subtitle header; it replaces a name's extension by `.m4b`, where ScummVM added a second one
  (fixed on `cleanroom`). `StopMovie` while a movie plays crashes the original (an access violation at 0x422711, in its
  movie player, after `StopMovie` paused the Bink and deleted the player): not tested.
- 2D primitives (`primitives.lua`, `cr_snap(key, "count")`). The original draws them in software (`rdPrimit2_DrawLine`):
  lines with both ends and 4-connected (a step in x or in y, never both), an outline as four such lines, a filled
  rectangle row by row, `DrawPolygon` as an open polyline of up to 250 points. Every ScummVM renderer leaves out the end of
  a line and draws diagonals 8-connected; the outlines of OpenGL and TinyGL are a pixel wider and taller (`LINE_LOOP`
  through `x2 + 1`; the shader renderer's four quads match); `DrawPolygon` draws only two of the three segments of 4 points.
- Save files as files (`save_files.lua`, 2026-11-10: `grim03.gsv` and `grim07.gsv`, no Load). The original's
  `FileFindFirst(ext, dir)` searches `dir\ext` when ext has a dot and `dir\*.ext` otherwise (`stdFileUtil_NewFind`
  0x4c1170, mode 3), with `""` as dir when there is none, so `FileFindFirst("*.gsv")` looks in the root of the drive and
  finds nothing (and `"*.set"` of `file_find` none either). ScummVM ignores dir, takes ext as the whole pattern of its save
  files (`"gsv"` finds nothing) and turns `"*.gsv"` into `grim##.gsv`, so the other `.gsv` files of the folder are not
  listed. The same on both: the names in order, one name, the end of the list, `FileFindNext` after a dispose, a second
  `FileFindFirst`. `GetSaveGameImage` gives a picture with ScreenShot's tag on both. On the original it is the set's
  background drawn again, dimmed and scaled to 250 x 188 (`Render_CaptureThumbnail` 0x486f90), without the text on the
  screen. `BlastImage` blits it into the back buffer (0x4a3130), and it stays there after `FreeImage` until that area is
  redrawn. ScummVM's `savegameSave` takes the thumbnail from the stored display (`getScreenshot(250, 188, true)`), which
  only `DimScreen` stores (the menu calls it). With OpenGL a save made without one has a black thumbnail (the `SIMG` section
  all zero), and after `DimScreen` (`save_image_dim`) it is the dimmed screen, almost black (16 to 20 of 255 where the
  original's grey thumbnail has 88 and 120). With the shader and software renderers it is the scene, darker than the
  original's: a mean of 64.9 against 104. (The test patch's `cr_snap` stores the software renderer's display.)

## Not done yet

The builtins no test calls are the ones left out on purpose: the dialogs, SetGamma, execute, debug-only ones
(`TEST`, `quiet`, `vfx`, `debug`, `SpewStartup`) and the CD helpers.

Binary models are written without faces (`formats.model3do`); text models can have faces (`formats.model3do_text`).
Sounds are .wav, iMUSE's .IMC and MCMP (stored or VIMA blocks: "1008 - Domino's Office.IMC", "2001 - Climb Rope.IMC" and
the voices); VIMA is written mono, without escapes. Movies are Blocky16 modes 0, 2-6 and 8 (no mode 1 or 7: ScummVM has neither);
EMI's movies are Bink with fill blocks only (no DCT, motion or sound) and its music (`FullMonkeyMap.imt` and AIFF or VIMA tracks) has no writer yet.
Keyframes are text or binary (`formats.keyframe_binary`, `keyframe_bin.lua`: each engine plays the binary slide as the
text one; a binary file's fps does not change a chore's length on either). Bitmaps are raw or codec 3 (`formats.codec3`: `cr_obj.bm` and `cr_cams.bm`; both
engines decode them to the same pixels, so every test that draws them is unchanged).
