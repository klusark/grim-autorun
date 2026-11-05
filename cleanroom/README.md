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
| `formats.py` | writers: LAB, grim.tab (RCNE), .bm/.zbm (raw, RGB565), .cmp, text .set, text .cos, binary and text .3do (no faces; a header or radius of your own if asked; `model_bounds` works out the box as the original does) |
| `assets.py` | the data: three sets (`cr_flat`, `cr_edge`, `cr_stair`), backgrounds, the text table, `cr_luav.cos` |
| `lua/_system.lua` | the runner (`cr_test`, `cr_log`, `cr_frames`, `cr_until`) |
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
  vertices through the node transforms for both formats, as the original does. On grim-actor-fixes it turns 18 tests from
  differ or close to the same as the original (every `mf_cr_trad`/`brad`/`trot`/`tprot`/`trotx` case and the `hdr_ctrx`,
  `ctrz`, `bbig`, `bside` sphere cases) and makes no test worse.
  The lying box (`cr_rotx`) as a wall is too low (0.3 m) for the mover's sphere: no engine collides with it. The two engines
  turn a node the same way (the head node of `cr_trotx` is at the same place on both).
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

Models are written without faces (`formats.model3do`): no materials (.mat), so nothing is drawn. Faces and a material
writer come next: box collision and node positions probably need a model that is drawn. Keyframes (.key, for walk chores),
sounds, text objects and fonts (.laf) have no writer yet.
