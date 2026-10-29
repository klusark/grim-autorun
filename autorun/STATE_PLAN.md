# Plan: tests without the game's state

State on 2026-10-25. The in-game suite (`test_nav.lua`: unit 58, walk 42, move 96, coll 162, turn 3, slide 6) gives the
same counts on both engines run after run, but it gets there by fighting the game: it loads a story save, enters the
real sets with their scripts, and undoes what each case leaves behind with a list that grows with every surprise. This
plan takes the game's state out of the tests, step by step, each step keeping the counts and ending with a check.

---------------------------------------------------------------------------------------------------------------

## 1. Where the state comes from today

* **A story save.** `ar_load(19)` loads the Year 2 checkpoint of the playthrough: `saves/grim19.gsv` on ScummVM,
  `GRIMDATA/grim19.gsv` on the original, two different files made by two different runs. They hold the whole story
  (inventory, puzzle states, running scripts, Manny's costume, the autorun's own task asleep in `ar_checkpoint`), and go
  stale whenever the autorun changes (`rebuild_saves.sh` plays 7 minutes to remake them).
* **The real sets' scripts.** `set:switch_to_set()` runs `CommonExit`, `CommonEnter`, `enter()`, the footsteps, the
  music, the costume rule: Velasco's idles, the door scripts of the set before, the pigeons, `at.watch_manny`.
  `ar_nt_place` fights them: `ar_nt_settle` (3 still frames, cap 3 s), up to 4 switches when the door scripts of the
  case before pull Manny away, `stop_script` of 7 of Velasco's scripts by name until he stays put for 5 frames, the
  `stairman`/`curbman` restart.
* **What a case leaves behind.** `ar_nt_reset` is a blacklist: collision mode and scale, running, the hands, 14 planner
  globals, the shrunk boxes (undone at the *next* placement), the climbing flag, the constraint. Each entry was a bug
  found after the fact; nothing says the list is complete.
* **Story actors as fixtures.** The collision tier borrows `velasco` and his costume, the unit/walk cases Manny's set
  costume. (The move tier already makes its own copy of the object and its actor: that is the right pattern.)
* **The original's launch.** 1 minute: fixed sleeps (12 s, 3 s, 3 s), `Load(19)` by remote Lua, then the F12 injection
  has to win a race against the autorun that the save holds (it sleeps 4 s in `ar_checkpoint` for that reason), 25
  minutes of real time for the suite.
* **The cost, measured** (`logs/tn_base.log`): about 390 s of game time go to the unit tier, whose plans take no game
  time at all: it is all placement and settling, about 6 s a case; 5 to 9 `NAVTEST placement:` lines a run where the
  game moved Manny after the placement; one order-dependent case (`lobby_long`) in the suite today, three a week ago.

## 2. Target

* A case is a function of its geometry, the actors it makes itself and its parameters: the same result alone, in any
  order, on both engines, from a cold start.
* No save file and no story script in the path of a test. The playthrough (`run_all.sh`, `orig_all.sh`) stays the one
  test of the story and the only user of the saves.
* Every case **declares** the state it needs (a fixture); one library applies it and checks afterwards that the world
  is as the case found it. A leak is a FAIL of the case that leaked, by name, not a flake of the one after it.
* The engine rules (turn, slide, edges, stairs, collision) are tested on hand-made geometry whose numbers are in the
  test, with the original's recordings as expected values; the real sets stay as the integration tier.
* Tiers are separate processes; on ScummVM they run at the same time.

## 3. What makes it possible (verified)

* **Both engines read `DATAUSR.LAB`.** The original reads it for files that are *new* (checked 2026-10-23: the marker
  file in `DATAUSR_test.LAB` was loaded; `DATA006.LAB` is the one that overrides existing files, which is how it runs
  ScummVM's Lua patches). ScummVM reads `datausr.lab` when the ini has `datausr_load=true` (`resource.cpp:150`).
  `mk_datausr.py <dir> <out.lab>` packs one. So new set files and new Lua files reach both engines from one archive.
* **The game ships a debug set.** `testroom.set` (DATA000.LAB, 1.5 KB: a colormap, 5 setups with their own
  backgrounds `testroom.N.bm`/`.zbm`, one light, `numsectors 0`) and `testroom.lua` (`testroom = Set:create(
  "testroom.set", "testroom", { })` with a `switch_to_set` of its own that does only `CommonExit`/`CommonEnter`/
  `MakeCurrentSet`/`enter`). `_sets.lua` sources it last. A test set is the testroom's header plus a hand-written
  `section: sectors`.
* **`set:switch_to_set("noenter")`** is in the game's own `_sets.lua` (line 151): it skips `CommonExit`, `CommonEnter`,
  `enter()`, the footsteps, the music and the costume rule, and only does `MakeCurrentSet`. That is the switch for the
  real sets in tests: the sectors as the file has them, no idles, no door scripts.
* **The original starts a new game on its own.** `run_original.sh` (the playthrough's start) boots it into a new game
  and injects the autorun with Backspace+F12; no `Load` is needed for a test, the saves were only a habit of the
  chapter resumes.
* `nav_setfile.lua` already parses the real set files with the game's `readfrom` (`SETFILE` probe: 0 differences on
  ha, ga, si, os), so a generated set file can be checked against what the engine loaded (`DumpSectors`, ScummVM).

## 4. The steps

### Step 1. Measure the leaks (1 day)

`ar_fx_snapshot()` and `ar_fx_diff(before)` in a new `ar_fixture.lua`: the current set file; Manny's position, yaw,
costume, collision mode and scale, running, climbing, holding, constraint; `system.currentSet.boxes_shrunk`; the
sector states as the fixture set them (a Lua shadow table: in tests only the fixture calls `MakeSectorActive`, so it
knows; the original has no builtin that reads a sector's state, ScummVM's `IsSectorActive` checks the shadow in a
development run); the actors the case created; `find_script` of `stairman`, `curbman`, `Sentence`.

Every case gets a snapshot before and a diff after. A difference is logged as `NAVTEST leak <id> <field> <before> ->
<after>` and fails the case. Run the suite, list the leakers, fix each at its source. This step changes no case; it
only names the order dependence the shuffles find by chance today.

Check: the leak list is empty on ScummVM over the listed order and two shuffles; the original's run shows the same.

### Step 2. Fixtures instead of `ar_nt_place` / `ar_nt_reset` (2 days)

`ar_fx_begin(case)`:

* `set:switch_to_set("noenter")` when the set is not the current one; one `break_here()` for `MakeCurrentSet` to
  take. No settling: nothing runs. Then `set:make_objects_visible()` (the one thing of `CommonEnter` the approach
  tests need, so that the game offers the objects).
* Sectors: the file's defaults (`nav.off`), then `case.on`/`case.off`, through the shadow table.
* Manny: `put_in_set`, position, yaw; the costume only when the case says (`costume = "..."`, the ladder cases).
* Actors: `case.actors = { { name, costume, pos, yaw, mode, scale } }`, made with `Actor:create` and freed at the end;
  never the story's `velasco`. The 7-script stop list and the "placed < 4" loop go.
* Stairs: `SetActorConstrain(nil)`, `stairman`/`curbman` restarted, in this one place.

`ar_fx_end(case)`: free the created actors, collision off, boxes unshrunk, constraint off, `stop_climb_ladder` if
climbing (and a leak line: a case may not end on a ladder), the planner's globals back, then `ar_fx_diff`.

Cases that need the set's scripts (today `ladder_up_to_door`: the sewer ladder's scene) say so with `enter = TRUE` and
get the old switch: a visible list of exceptions, not the default.

Check: the counts unchanged (unit 58, walk 42, move 96, coll 162, turn 3, slide 6); zero `NAVTEST placement:` lines;
zero flaky over the listed order, two shuffles and three repeats; the original's agreement not worse than today (4
differences: `cheat_roof`, `ledge_window`, `stairs_narrow_side`, `bs_stair_down`).

### Step 3. Boot without the save (1 day)

* ScummVM: the suite starts a **new game**. The autorun gets control in `mo` after the intro (seconds in simulated
  time, `ar_skipper` skips the movie); `ar_load(19)` goes out of `test_nav.lua`; `run_chapter.sh` gets a `NOSAVES=1`
  that points `--savepath` at an empty scratch directory, so nothing in `saves/` can reach a test.
* The original: a **new game too, no save at all.** `run_original.sh` already does this for the playthrough: the game
  boots into a new game (the `GrimLastSet` key in the VirtualStore is deleted first), Backspace+F12 injects the script,
  the autorun skips the intro and gets control in `mo`. `orig_test.sh` switches from `resume_original.sh 19 test` to
  `TESTFILE=... run_original.sh`, and the F12 goes out as soon as the log shows `_system.lua` sourced, during the
  intro, instead of after a fixed 20 s: the autorun's `ar_skipper` then skips the logo and the intro through the game's
  own Escape (`call_override()`), as it does on ScummVM. Fallback if a `dofile` during a fullscreen movie proves
  unsafe on the original: `postf12.exe` generalised to `postkey.exe <vk>`, posting `VK_ESCAPE` to the game's windows
  every second until `Switching to set: mo` is logged. `Load` and the saves stay only in the playthrough's resume
  (`resume_original.sh`, `orig_all.sh`); no test uses them.
* Both engines then start from the same state: a new game, Year 1 costume, nothing done, and no file of a run before.

Check: `python tools/test_all.py scummvm` with `saves/` renamed away; the original's suite from a new game with the same
counts as from slot 19; `grep -c Load` over the test scripts is 0.

### Step 4. Hand-made sets for the engine-rule tiers (3 days)

`tests/sets/` with set files written by `tools/mk_set.py` from a short description (rectangles with heights, the type
word, on/off at the start, an id), using the testroom's header (its colormap, `testroom.0.bm`/`.zbm`, one setup, one
light) so the engines have a picture to draw (`DumpFrame` keeps working; the geometry sits within 2 m of the origin,
where that camera looks):

* `t_flat.set`: one 4 x 4 m walk box. Turn rate, walk rate, `SetActorRot` with and without a walker, the collision ring
  (today on `re`'s floor at -3.4, which was only ever an open floor with Velasco on it).
* `t_edge.set`: two walk boxes sharing an edge; a third at a 2e-5 gap (the containment tolerance of FUN_004a6980); a
  wall edge; a corner of 132.7 degrees. The slide tier (today the `bs` corner), and the exact edge rules that were
  ported and reverted (the neighbour at the exit point, the extra degree, the 2-cm cap, the held-key rule), each as
  its own case with the original's trace.
* `t_stair.set`: the sector kind `stairman` watches for, between two floors, at three slopes: the `pc` and `bs` stairs
  where the original's autorun is held up, reproduced on their own.
* `t_sliver.set`: slivers of 3, 5 and 10 cm (the dam), a passage of 2.5 cm (the bottle).
* `t_hot.set`: a `chernobyl` sector with an object whose `walkOut` changes the set, and a cheat box: triggers, doors
  and teleports with nothing else in the set.

Each has a `t_*.lua` (`t_edge = Set:create("t_edge.set", "t_edge", { })`, no `enter`, the door objects). All of it is
packed into `DATAUSR.LAB` and copied to GRIMDATA for the original; for ScummVM the ini gets `datausr_load=true` and an
`extrapath` to `tests/sets/`, so the install stays clean. Expected values recorded from the original into
`tests/expect/*.lua` by one command (`sh tools/record_original.sh <tier>`), as `nav_coll_expect.lua` is today.

The real-set cases of `nav_cases.lua` stay (they are the integration tier: real slivers, real stairs), now on the
fixture library of step 2.

Check: slide, turn and coll tiers on `t_*` with the original's recordings, bit for bit where the trace compare says so;
the reverted edge-rule port tried again against `t_edge` alone before it is let near the walk tier.

### Step 5. One file per tier, one process per tier (1 day)

`tests/run.lua` and `tests/tiers/{unit,walk,move,coll,turn,slide}.lua`; the switches as today through the generated
`nt_run.lua` (`AR_NT_TIERS = { "slide" }`). `test_all.py` starts one ScummVM process per tier, all at once: the wall
time becomes the longest tier (about 40 s) instead of 117 s, and a crash in one tier does not take the others down.
The original keeps one process per run (an injection is a minute) and relies on step 2 for the isolation.

The result line gets the command that reproduces the case alone on each engine: `NAVTEST <tier> <id> <PASS|FAIL|KNOWN>
<msg> | repro: ...`; `test_all.py` takes the tier names from a list, not from a regex of four.

### Step 6. The original's launch (1 day)

`run_original.sh` and `resume_original.sh`: wait for the log's markers (the first `Switching to set`, the load's
`Won't reload service_release.lua`) instead of the fixed sleeps (12 s, 3 s, 3 s, 20 s), and inject at once.
`orig_test.sh` writes the foreground window's title into the log every 20 s (`tools/focus_log.ps1`), so that a stall
can be matched with the focus, which is the open question of the playthrough's stalls at ch06/25/27/64.

## 5. Order, and what stays

Order: 1, 2, 3, 5, 4, 6. Step 4 is the biggest gain for the engine rules but needs the fixture library of step 2;
step 6 is independent. About nine working days.

Stays: `nav_cases.lua` (integration, on fixtures), tier A offline, `nav_known.lua`, the trace compare, the
playthrough with its saves.

Goes: `ar_load(19)` in tests, `ar_nt_settle`, the retry loop of `ar_nt_place`, Velasco's stop list, the blacklist of
`ar_nt_reset` (the snapshot/diff replaces it), the move tier's `base.touchable` juggling (own objects, own actors).

## 6. Risks

* **A hand-made set the original refuses.** The syntax is the one `nav_setfile.lua` parses from the real files
  (`sector <name>`, `ID`, `type walk`, `default visible`, `numvertices`, `vertices:`); `mk_set.py` writes those words
  and ScummVM's `DumpSectors` checks what was loaded. If the original still refuses a set outside its LABs, the
  fallback is an override of `testroom.set` through a `DATA006`-style archive (which it does read for existing names).
* **`noenter` and the objects.** `make_objects_visible` is in `CommonEnter`; the fixture calls it. Anything else a
  case misses from `enter()` is a bug of the case's declaration, found by the leak diff or by the case failing alone,
  and is written into the case, not into the library.
* **The costume.** Slot 19 has the Year 2 costume, a new game the Year 1 one: walk and turn rates are the actor's,
  not the costume's; the ladder and stair cases set the costume they need.
* **Camera.** The testroom's setups look at the origin from 2 m: geometry further away draws nothing; the engine does
  not care, `DumpFrame` does.

---------------------------------------------------------------------------------------------------------------

## 7. Status, 2026-10-25 (evening)

* Steps 1 and 2 done: `ar_fixture.lua` (snapshot/diff, `NAVTEST leak`), `ar_nt_lib.lua` (placement with `noenter`), exceptions declared in the cases
  (`enter`, `climbs`, `door`, `shrink`).
* Step 3 done: no `ar_load` in `test_nav.lua`; the original starts a new game (`orig_test.sh`, F12 after 12 s, `LOADSLOT` for the old way).
* Step 4 started: `tools/mk_set.py` writes the sets `t_flat t_edge t_stair t_sliver t_hot` and `tests/sets/DATAUSR.LAB`. Verified on both engines:
  ScummVM reads it with `datausr_load=true` + `extrapath` (`TESTSETS=1` in `run_chapter.sh`), the original from `GRIMDATA/DATAUSR.LAB`. The sector id is the
  index into an array on ScummVM: ids must be 0..n-1 (others crash). `test_rules.lua` holds 273 cases (point-in-sector on edges, gaps and slivers; walks
  into walls, over edges and stairs, with turn keys), expected values in `rules_expect.lua` recorded from the original.
* Step 5: `tools/test_all.py` runs `unit`, `walk`, `move`, `coll`, `turn+slide` and `rules` as six ScummVM processes side by side (`AR_NT_TIERS`, `LOGTAG`).
* Step 6: not done.
