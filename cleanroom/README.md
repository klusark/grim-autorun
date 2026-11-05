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
python run.py original --save --only a,b     # new or changed tests: only theirs are replaced in the expected log
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
  `patch.dll` and `grimlaunch.exe` are built from `../launcher` into the run folder whenever the sources are newer.
  The game is started only through `grimlaunch.exe` (debuglog, simtime, config and windowed patches). `grim.ini` points
  `GrimDataDir` at the run folder and sets `good_times` (no CD check).
  `run.py` does not start if a `GRIMFANDANGO.exe` is running already, and it kills only the process it started.
- **ScummVM:** a build with `scummvm/grim-test-data.patch` (a detection entry for the marker file `grimtestdata.txt`,
  flag `GF_TESTDATA`: no `gfupd101.exe`, no `grim-patch.lab`, no md5 check, loose files and the folder's own LABs;
  `PrintDebug("CRSNAP:<file>")` saves a picture of the screen; an `error()` ends ScummVM at once, with its message in the
  log, instead of opening the debugger and waiting there).
  `scummvm/build.sh` builds it in the worktree `~/scummvm-cleanroom` (`git worktree add --detach ../scummvm-cleanroom
  <branch>` and `git apply` the patch first). `SCUMMVM=` selects another exe. Without `--sim-fps` (branches without the
  autorun options) the frame times are real ones and the per-frame values do not match.
- **No windows on the screen:** ScummVM and Grim's original run on a desktop of their own (`tools/offscreen.c`, built into
  `run/offscreen.exe`): they draw as before (OpenGL, DirectDraw), but nothing shows and they cannot take the focus. The
  program and what it starts are in a job that ends with `offscreen.exe`, so killing a run that hangs kills them all. EMI's
  original cannot start Direct3D on another desktop, so it runs on the user's desktop with grimlaunch's `offscreen` patch:
  its window opens at -20000,-20000, without a taskbar button, and never takes the focus. `CR_VISIBLE=1` shows them all.

## Escape from Monkey Island

```sh
python run.py original --game emi --save   # the original Monkey4.exe v1.1: expected/emi_original.log
python run.py scummvm --game emi           # ScummVM's EMI against it
```

The same runner runs on EMI. A test file runs on a game when the end of its first line says so: `-- games: grim emi` (no tag:
Grim only). The tag goes on the first line so that no line number of the file changes, because some results hold them
(`script_names`). Inside a shared file, `CR_GAME` (`"grim"` or `"emi"`) guards the parts that need one game's data. Each
game's original is its own reference, so "shared" means the same test source, not the same values. The EMI runs use
`build_emi/`, `run/emi/`, `logs/emi/` and `expected/emi_*`.

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

ScummVM's EMI on 2026-11-05 (opengl), before `zz_args_emi`: 24 of 73 tests differed. The main differences:
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

Not done: EMI models, costumes and chores (`.meshb`, `.animb`, EMI's `.cos`), the rotation of a setup's camera, and sharing
Grim's set, actor and walk tests (they need Grim's points turned over and EMI's sets).

`args_collectgarbage_none|r` is in `expected/unstable.txt` by hand: the count `collectgarbage()` returns changes with
every edit to the test sources. A full `--save` writes the file again without it.

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
| `snaps.py` | pictures of the screen (`cr_snap`): reads the .bmp files and logs the box of the bright pixels |
| `formats.py` | writers: LAB, grim.tab (RCNE), .bm/.zbm (raw, RGB565), .cmp, text .set, text .cos, binary and text .3do (text models may have faces with materials; a header or radius of your own if asked; `model_bounds` works out the box as the original does), .mat (8-bit, one texture a cel), text .key |
| `assets.py` | the data: the sets (`cr_flat`, `cr_edge`, `cr_stair`, `cr_open`: cr_flat with a far z-buffer, where models are drawn; `cr_ell`: an L of floors), backgrounds, the text table, costumes, drawn models, a keyframe, `cr_extra.lab` |
| `lua/_system.lua` | the runner (`cr_test`, `cr_log`, `cr_frames`, `cr_until`, `cr_snap`) |
| `tests/*.lua` | the tests |
| `expected/original.log` | the original's results, the reference for ScummVM runs |
| `expected/unstable.txt` | values the original does not repeat run to run (not compared) |
| `scummvm/` | the engine patch and its build script |
| `tools/labls.py` | lists the members of a LAB (to look at the layout of the game's formats; nothing is copied) |
| `tools/read3do.py` | prints the structure of a binary .3do (checks what `formats.model3do` writes) |

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

What Lua cannot read can be looked at on the screen: `cr_snap(key)` saves a picture of it, and run.py logs under `key` the
box of its bright pixels (`x0 y0 x1 y1`, or `none`). The tests draw white text on the dark backgrounds, so the box is that
of the text. The call is `PrintDebug("CRSNAP:<file>")`: on the original, patch.dll saves the back buffer with the game's own
screenshot function (`Render_SaveScreenshotBmp` 0x487340, the Backspace+S debug key; only on v1.01, whose bytes it checks);
on ScummVM, the test patch draws the scene and saves it (ScummVM's picture is grey, which does not change the box).

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
- `IrisUp` / `IrisDown` without a running iris never return. `NextSetup` / `PreviousSetup` in a set with one setup and
  `MakeCurrentSetup` of a setup that does not exist crash.
- The rest of the crashes with wrong arguments are listed in `expected/crashers.txt` (found by the argument probe).

## Coverage of ScummVM

A gcov build of the cleanroom worktree measures which lines of engines/grim the tests run:

```sh
mkdir ~/scummvm-cleanroom/build-cov && cd ~/scummvm-cleanroom/build-cov
CXX="ccache g++" CC="ccache gcc" CXXFLAGS="--coverage -O0 -g" LDFLAGS="--coverage" \
    ../configure --disable-all-engines --enable-engines=grim,monkey4
sed -i 's/^CXXFLAGS := \(.*\)$/CXXFLAGS := \1 -DCR_GCOV/' config.mk   # Exit() writes the counters (see below)
make -j16
find . -name '*.gcda' -delete
SCUMMVM='C:\msys64\home\Joel\scummvm-cleanroom\build-cov\scummvm.exe' CR_TIMEOUT=1500 python run.py scummvm
python ~/grimL_ar/tools/covreport.py <outdir> 'C:\msys64\home\Joel\scummvm-cleanroom\build-cov' 'C:\msys64\home\Joel\scummvm-cleanroom'
```

`SCUMMVM` must be a Windows path. After the whole suite ScummVM crashes on the way out (0xC0000005 after `exit()`), which
loses the counters: with `-DCR_GCOV` the test patch calls `__gcov_dump()` in `Exit()` first. 2026-11-05: 42.3% of the lines
(11596 of 27397, without lua, emi, remastered, tinygl), from 38.5% before the drawn models, keyframes, the costume
components, the archive, paths, heads and shadows. What is left is mostly sound and movies (no data of ours yet), the
shader renderer (the tests use `gfx_mode=opengl`), saving and loading, and the debugger.

## Wrong arguments and coverage

`tests/zz_args.lua` is generated by `tools/gen_args.py`. It calls every builtin of the original with no arguments, nil, a
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
Until then, tests must not depend on table order. `--save` keeps any value that varies in `expected/unstable.txt`.

## Differences found (ScummVM grim-actor-fixes, 2026-11-05)

4740 tests: 3886 the same, 3 close, 851 differ (most of them in the argument probe). Every difference is a ScummVM bug
to look at, whether ScummVM is stricter or more permissive than the original.

Argument probe (`zz_args.lua`, 4580 calls; classified from the logs):
- 64 builtins of the original are missing in ScummVM (503 calls): among them `GetActorScale`, `GetCameraInterest`,
  `IsActorLooking`, `GetLightPosition` / `Intensity` / `Type` / `Angles`, `IsLightOn`, `FindLight`, `PutActorAtOrigin`,
  `WalkActorToInterest`, `SnapToPlane`, `GetSectorVertices`, `ScreenToWorld`, `GetTickCount`, `ascii`, `exp`, `log`,
  `log10`, `atan2`, `getenv`, `rename`.
- 36 builtins crash or hang ScummVM with arguments the original takes (145 calls, `logs/scummvm_known_crashers.txt`): the
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
- ScummVM does not fire the LUAV keys of a costume, with or without a model (`CR_LV` is never set); the original does,
  at the frame times the chore keys give. Turn chores are not played on ScummVM. `IsActorChoring(a, nil)` gives the chore
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
- Number text: the original's C runtime writes 3-digit exponents (`1e+015`) and `1.#INF`; `tonumber("0x10")` is nil.
  `LocalizeString("no slashes")` gives `"//no slashes"` on the original. `FunctionName` is written differently.
- `GetMemoryUsage` and `GetTickCount` are numbers on the original, nil on ScummVM.
- About 87 Lua builtins exist only on the original; `sleep_for`, `pause_script`, `unpause_script` only on ScummVM.

## Not done yet

The builtins no test calls are the ones left out on purpose: the dialogs, Load/Save, SetGamma, execute, debug-only ones
(`TEST`, `quiet`, `vfx`, `debug`, `SpewStartup`) and the CD helpers.

Binary models are written without faces (`formats.model3do`); text models can have faces (`formats.model3do_text`).
Sounds (.imu, .wav), movies (.snm), lip sync (.lip), compressed bitmaps (codec 3) and binary keyframes have no writer
yet.
