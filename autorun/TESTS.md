# The navigation tests

One command: `sh test_all.sh [offline] [scummvm] [original] [flaky]` (default: offline scummvm flaky). It writes
`logs/navtest_summary.md` and adds a line to `logs/navtest_history.tsv`. Plan and reasons: `TEST_PLAN.md`.

## Tiers

| Tier | What | Where | Time |
| --- | --- | --- | --- |
| A | the plan of every case, with the real sector data (the set files, read from the LABs) | `tools/lua31/run.sh`, in the Lua 3.1 of the game (`LUA.DLL`), no game | 1 s |
| unit | the same cases in the game, after placing Manny | `test_nav.lua`, either engine | ScummVM ~20 s |
| walk | the walk with the keys from the same start | `test_nav.lua` | ScummVM ~40 s |
| move | a target (an actor) that is somewhere else or moves: 96 cases | `test_nav.lua` | ScummVM ~60 s |
| coll | collision with another actor: 81 starts x (steered walk, static heading with a per-frame trace) | `test_nav.lua` | ScummVM ~60 s |

ScummVM: `EXTRA="nav_cases.lua nav_coll_expect.lua nt_run.lua" sh run_chapter.sh test_nav.lua 900` (`nt_run.lua` holds the
switches below). Original: `sh test_nav_original.sh` (25 min; for a part, put the switches in a file, cat it in front of
`test_nav.lua` and run `TESTFILE=<that file> sh resume_original.sh 19 test`). Never run two of the original's scripts at
once: they kill every `GRIMFANDANGO.exe`.

Switches (globals set before `test_nav.lua`): `AR_NT_ONLY = "<id>" | "move" | "coll"`, `AR_NT_IDS = { id = 1 }`,
`AR_NT_MODE = "unit" | "walk"`, `AR_NT_SHUFFLE = <seed>` (the same shuffled order on both engines), `AR_NT_TRACE = TRUE`.

## A case

`nav_cases.lua`: `{ id, set, from = {x,y,z}, to = {x,y,z} | door = "<object>", ... }`. Fields: `link = "s"|"c"|"ss"` (a link
of that kind must be on the way), `tol`, `yaw`, `off`/`on` (sectors forced off/on), `shrink`, `nowalk` (unit only), `nounit`
(walk only), `ingame` (not in tier A), `obst = { {x,y,r} }` and `clear` (the way must keep that far from the actor),
`len` (the length of the way in the run it came from), `minlinks`, `setfile`, `probe`.
`nav_cases_run.lua` (made by `python tools/gen_cases.py logs/all_pass1.log`) holds the walks of a full run as cases. Not in the default in-game suite (they start from the state of a fresh set, not of the story, and many fail on the committed engine too): `RUNCASES=1 python tools/test_all.py scummvm` adds them.

## The original is the reference

* Collision end points: `nav_coll_expect.lua`, recorded from the original (`NAVTEST coll_rec <id> x y` lines of its
  log; `python`-regenerate it from `logs/orig_coll_record*.log`).
* Per-frame traces: `NAVTRACE <id> <frame> x y z yaw`; `python tools/compare_trace.py a.log b.log [limit_m] [prefix]` prints,
  per case, the first frame in which two logs differ by more than the limit.
* `python tools/compare_navtest.py a.log b.log [tier]`: the cases that pass in one log and fail in the other.

## Reading a failure

`NAVTEST <tier> <id> FAIL <why>`. Alone: `AR_NT_ONLY = "<id>"`. A `NAVTEST placement:` line before it means the game moved Manny
after the placement (it is not the planner's fault). `flaky` in the summary means the case gave different results in the
listed order and in the two shuffled ones: it depends on another case or on timing; fix that before trusting its result.

## Adding a test

Every fix or difference found gets a case in the same turn (`feedback-always-add-tests` in the memory): a planner fix in
`nav_cases.lua` (tier A first), an engine fix with the original's values recorded and checked in. Say which in the report.


## Added 2026-10-25: turn tier, frames, real mode, coverage

* **turn tier** (`AR_NT_ONLY = "turn"`, in `test_nav.lua`): SetActorRot on an actor that never walked, turned or followed boxes (no walker in the
  original, FUN_00490730 makes it on the first of those) sets the angle exactly (the tumblers of the safe in vd compare it as a whole number);
  with a walker the angle that is read changes in the frame after the SetActorRot, not in it, and is within 0.1 degrees of the asked one.
  Both engines pass (the original: `sh orig_test.sh` with `AR_NT_ONLY = "turn"` in front of `test_nav.lua`).
* **Head-on slides** (box collisions) go to either side of the line of the approach in the original, depending on the whole history of the angles
  of the actors: the same case gave 2.5421 alone and 2.8580 in the full run. `test_nav.lua` accepts the end on the other side for the cases in
  `nav_known.lua`; `SYM=1 python tools/compare_trace.py a.log b.log 0.002 collisionS_` does the same for the traces (81 of 81 the same).
* **Frames** (the two engines side by side): `FRAMES=<ms>` in `run_all.sh`/`run_chapter.sh`/`build_original.sh` makes the autorun mark a frame that
  often, counted from the start of each chapter (`ar_frame_chapter`): ScummVM writes `<DUMPDIR>/<chapter>_<n>.png` itself (the `DumpFrame` builtin,
  config key `dump_frames_dir`); for the original `tools/framecap.py <outdir> <log>` copies the game window at every `FRAMEMARK` line of the log.
  `python tools/framediff.py frames/orig frames/sv frames/diff` writes `index.html` (original | ScummVM | difference, worst first).
  Several runs at once: `LOG=<name> SAVES=<dir>` in `run_all.sh` keep their logs and saves apart.
* **Real mode** (`REAL=1` in `run_all.sh`/`run_chapter.sh`/`build_original.sh`): no cutscene and no line is skipped (`AR_REAL`), the voices are on
  (no `speech_mute`, no TEXT_ONLY), the long waits are ten times longer. ScummVM passes the whole game this way (508 s of real time, 11.9 million ms
  of game time).
* **Coverage**: `build-cov` is a gcov build (`CXXFLAGS="--coverage -O0 -g"`), `SVM_BUILD=build-cov` runs any script with it; `python tools/covreport.py`
  writes `coverage/index.html` (one page per file, the lines that never ran in red) and `coverage/summary.txt`. 65.6% of the lines of engines/grim
  (without lua, emi, remastered, tinygl and two EMI codecs) ran in the full game, the full game in real mode and the tests.
* The `run_*` cases of `nav_cases_run.lua` (made from a full run) are not in the default suites any more: they start from a fresh set, not from the
  story, and fail on both engines (`RUNCASES=1` brings them back).


## Added 2026-10-25 (later): fixtures, no save (STATE_PLAN.md steps 1-3)

* `ar_fixture.lua` (after `nav_cases.lua` in EXTRA / in `build_original.sh`'s TESTFILE build): the state a case starts from and what it may leave.
  `ar_fx_open(case)` closes the case before it; `ar_fx_close()` compares a snapshot with the baseline taken after the placement
  (`NAVTEST leak <id> PASS|FAIL <field old->new>`: Manny's collision mode and scale, other actors left in a collision mode, the item held, the boxes shrunk,
  climbing, a cutscene level) and puts everything back, also the boxes of the set that shrank them. Tier `leak` counts in the summary and fails the run.
  The engine cannot be asked for a collision mode, so `SetActorCollisionMode/Scale/Constrain` are wrapped to keep what was set.
* Sets are entered with `switch_to_set("noenter")` (the game's own switch: `MakeCurrentSet` only; no idles, no door scripts, no music) and
  `make_objects_visible()`. A case that needs the set's scripts says `enter = TRUE` (`ladder_up_to_door`, `start_off_floor`: the door does not work without
  them); a case that goes through a door is exempt from the mode/scale leaks of the next set's scene (`door`), one that ends on a ladder says `climbs`.
* **No save**: `test_nav.lua` starts with `ar_wait_for_control()` in a new game on both engines. The original: `sh orig_test.sh <file> <max s> <log copy>`
  starts `run_original.sh` (new game, F12 after `ORIG_F12` s, default 12); `LOADSLOT=<n>` keeps the old way from a save.
* `AR_FX_DUMP = TRUE` in `nt_run.lua` prints every `AR_*` global at the start of each case (`FXGLOBAL <id> <name> <value>`): diff two orders of the same
  case to find a leak. Found this way: `AR_GOAL_LINKS` / `AR_GOAL_CELLS` / `AR_GOAL_LINK_OF` of the plan before made `stair_to_sliver_door` plan a stair after
  `thin_passage` (now reset in `ar_nt_reset`), and the planner's world is made again at each placement.
* Result on ScummVM: unit 58/58, walk 42/42 (`lobby_long` no longer order dependent), move 96/96, coll 162/162, turn 3/3, slide 4/6 (the two edge
  differences), leak all, 0 flaky over the listed order and two shuffles; 80-90 s a run (it was 117 s).


## Added 2026-10-25 (night): hand-made sets, the rules tier, tiers side by side (STATE_PLAN.md steps 4-6)

* **Hand-made sets**: `python tools/mk_set.py` writes `t_flat t_edge t_stair t_sliver t_hot` (exact numbers in the script: a 4 m floor; two floors that share
  an edge, a gap of 2e-5, a floor that is off, a wedge; three stairs of 3 slopes; slivers of 3/5/10 cm and a passage of 2.5 cm; a hot sector) and packs them
  into `tests/sets/DATAUSR.LAB`. ScummVM: `TESTSETS=1 sh run_chapter.sh ...` (ini `datausr_load=true`, `extrapath=tests/sets`). Original: copy the LAB to
  `GRIMDATA/DATAUSR.LAB` (done; the original reads new files from it). Sector ids must be 0..n-1 (ScummVM uses the id as an array index and crashes on
  others). `ar_fx_make_sets()` makes the Set objects. Use `switch_to_set("noenter")` and put Manny into the set in the same frame (`ar_fx_enter_set`
  does): a frame with Manny at a point outside the sectors of the new set ends the original (exit code 1).
* **`test_rules.lua`** (273 cases): `point_*` which sector holds a point (edges, gaps, slivers); `flat_dir/flat_run` the walk rate; `flat_wall`, `edge_cross`,
  `edge_wedge` into walls and over a shared edge, each with a turn key (-1, 0, 1); `edge_gap`, `edge_off`, `sliver_*`, `stair_*`. Expected values:
  `rules_expect.lua`, generated by `python tools/make_rules_expect.py logs/orig_rules.log` from a run on the original
  (`sh orig_test.sh $PWD/test_rules.lua 2400 $PWD/logs/orig_rules.log`, 11 minutes). `AR_RULES_ONLY = "<id prefix>"` runs part.
* **ScummVM differs from the original in 120 of the 273** (153 agree). Recorded as KNOWN with the group's reason in `rules_known.lua`
  (`python tools/make_rules_known.py logs/test_rules.log`): at an edge the original answers with the *last* sector that holds the point and a point up to
  about 1e-5 outside it (FUN_004a6980), ScummVM the first and exactly (14 `point_*`); walks with a turn key against a wall and the slide along an edge or a
  wall end up to 7 cm / 1 degree apart (the sector walk, FUN_004a8610). This is the test bed for the edge rules that were ported and reverted: change
  ScummVM, regenerate `rules_known.lua`, the list shrinks. A new difference outside the list fails.
* **Side by side**: `tools/test_all.py` runs `unit`, `walk`, `move`, `coll`, `turn+slide` and `rules` as six ScummVM processes at once
  (`AR_NT_TIERS`, `LOGTAG`, logs `logs/tn_<tag>_<group>.log`): the whole suite in 47 s wall time.
* **The original's launch**: `orig_test.sh` sends the first F12 after `ORIG_F12` s (default 2: a probe is done in 6 s, was 40), `resume_original.sh`
  waits for the log's first `Switching to set` instead of 12 s, and `orig_test.sh` writes the focus of the window every 5 s to `<log copy>.focus`.


## Added 2026-10-26: the original on a fixed frame time (tools patch_simtime.py)

* `python patch_simtime.py <exe> <out> 17` (grim_tools): the 5 bytes at 0x401721 (`mov eax,[0x4f5a48]`) become `mov eax,17`: every frame of the original is a frame
  of 17 ms (the fixed-step path of FUN_00482990 -> FUN_004a3c80), whatever the machine does. `sh tools/orig_clock.sh simtime|realtime` switches the install's exe
  (`GRIMFANDANGO.exe.simtime` / `.realtime`). ScummVM's `sim_frame_ms=17` (ini; `SIMMS=17` in run_chapter.sh / run_all.sh) gives the same step:
  the walks of `flat_dir_*` are the same to 4 decimals on both (0.2040 in 30 frames; the old 16/17 ms jitter gave 0.1996, ScummVM at 60 fps 0.2000).
* Speed: the walker logic has no limit (the probe of 273 cases: 6 s). Dialogue and movies run on the real clock (iMuse, SMUSH): chapter 13 takes 369 s at 60 fps,
  157 s at 240, 119 s at 480, 120 s at 720; at 1000 the speech path fails (`tools/orig_try.sh <fps> <chNN>`). The whole game at 480 fps: about one hour
  in pieces (it was hours), with ch23, ch47, ch50 as known failures (3 tries each) and ch64 on the second try. `GRIM_FPS=480 sh orig_all.sh`.
* Autorun changes for it: the budget of a wait does not run while a cutscene's movie plays (`IsMoviePlaying()` with `cutSceneLevel > 0`); the skipper stops a
  cutscene's movie that has played 200 s of wall clock (`ar_wall()` from `date()`); a movie with the control back is an ambient one that loops by design (ch16, ch47).
  `ar_checkpoint` waits for no movie before it saves (a save with a movie playing makes the loaded skipper stop it in the first frame: the game ends).
  `orig_all.sh` restarts a game that is not there 90 s after it was started.

* **Turn rate (2026-10-26)**: `turn_key_rate` (turn tier, `t_flat`): 30 presses turn `rate x frame time` a frame; both engines 1.445 degrees at 17 ms (rate 85). The earlier
  2.257 (original) vs 1.417 (ScummVM) came from the original's real-clock frames. `walker_close` passes on the original at the fixed frame time (removed from `nav_known.lua`).
  The tests read the rate with `GetActorTurnRate`, which ScummVM has only on a test branch (no new opcodes in the engine); the sign rule of `SetActorTurnRate` (FUN_0049b1d0) is in.


## Added 2026-10-26: the edge rules of the original in ScummVM (all in `engines/grim`, uncommitted)

Decoded in Ghidra (names in `GHIDRA_NAMES.md`) and ported, each judged by the rules tier and the walk tier:

* **Sector geometry** (`Sector_Construct`, `SectorVertexPool_GetOrAdd`, `Sector_ContainsPoint`): vertices closer than 1e-4 are welded (first loaded wins); Newell normal and the two dominant axes;
  a point is inside when its cross product on every edge is >= -2e-5 (so 2e-5 / edge length outside still counts) and it is within 0.005 of the plane (walk sectors and height 0; other types their height);
  the sectors are searched from the last one loaded. ScummVM: `Sector::weldVertices/prepareGrimGeometry/isPointInSector(p, exact)`, `Set::_searchOrder`. Used by the scripts' queries
  (`IsPointInSector`, `GetPointSector`, `GetActorSector`, `IsActorInSector`: `exact = true`); `stairman` relies on it. The 14 `point_*` rules cases now agree.
* **Sector walk** (`Walker_WalkSectors`), when no boxes are shrunk: the whole step is taken if it ends inside the current sector by that test (also along an edge); the neighbour is looked up
  at the exit point itself, newest first, **excluding every sector left in this step** (the original keeps them switched off for the rest of the step; this stops the bounce between two sectors
  on a shared edge, lobby door of ch04); the turn along an edge is the angle with the edge + 0.2 degrees (not 1), and not against a turn key that is held; for a constrained actor (stairs) also 0.2.
* **TurnActor** (`Actor_TurnKey`): the key is ignored while the angle between the heading that is seen and the walker's heading, as it was before the last update (`_turnLeft`), is more than two steps.
* `GetActorTurnRate` (test branch only), the sign rule of `SetActorTurnRate`; `sim_frame_ms` (17 ms frames like the fixed-time original).
* Switches (configuration, default on): `exact_edges`, `turn_key_rule` (`NOEXACT=1`, `NOKEYRULE=1` in `run_chapter.sh`), to find which rule a script cannot take.
* Tools: `trace_manny.lua` (EXTRA=: `MANNYTRACE x y z yaw sector` every 6 frames; `EXTRALIB=` does the same on the original through `build_original.sh`), `tools/orig_try.sh <fps> <chNN>`.
* New cases: slide tier `slide_stairwall_{right,none,left}` (ts, ch19; original values in `nav_slide_expect.lua`), a stair wall with the key held.

Result: rules tier 193 of 273 equal to the original (was 155; 80 known), walk 42/42 (known: pc_stair_to_morgue, ledge_window, dam_slivers, listed with reasons), slide 7/9, the others unchanged.
**Full playthrough on ScummVM: fails at ch23** at -3.54 6.09 on the police-station stair, where the original fails too (-3.55 5.78): ScummVM now has the original's behaviour there and the autorun needs a route
for ch23, ch47b and ch50 (tests them at ScummVM speed, then confirm on the original). **Open**: the original's `ShrinkBoxes` (FUN_004a9d00: shared vertices move together, sectors that
fail are switched off) is not ported, with boxes shrunk ScummVM keeps its old rules; the visible-yaw lead of a fraction of a degree (rules `_k+-1` cases, 3 degrees at most after 120 frames).

## Added 2026-10-26 (later): ShrinkBoxes of the original in ScummVM

`Set::shrinkBoxesGrim` / `Sector::grimShrinkOffsets` / `grimCollapseShortestEdge` / `grimClampPoint` port FUN_004a9d00 (names in `GHIDRA_NAMES.md`): each walk sector that is on moves every vertex
inward along the bisector of its edges by radius / sin(half angle), if the new place is in the sector and radius - 0.001 from every edge line; if not, the shortest edge is collapsed and it is tried again, and a
sector that cannot be made smaller is switched off; the shifts are the mean over the vertices that sectors share (the pool: vertices equal after the welding) and apply to every sector that has them, of any type.
`GetShrinkPos` uses the original's nearest-point routine (the height from the plane, the point moved onto the edge). Saves write a sector that the shrink changed in its unshrunk form.
Tests: `test_rules.lua` `shrinkpos_*` (56: GetShrinkPos on t_flat, t_edge, t_stair, t_sliver at two radii) and `shrinkwalk_*` (60: walks with boxes shrunk), values recorded from the original: 113 of 116 equal;
the others are a point exactly between two shrunk regions (a tie) and two stair walks that end at the same place with the heading 3.7 degrees off. The `!boxesShrunk()` guard on the exact edge rules is gone.
Result: rules tier 393 of 393 (84 known: the turn-key cases and a few slides), the playthrough passes ch1-ch22 and stops at ch23 like the original.

## Added 2026-10-28: turning (branch grim-time-scale)

Turn tier (`AR_NT_ONLY = "turn"`), measured on the original (26/26): SetActorRot with the turn flag sets pitch and roll at once and eases only
the yaw (`setrot_*`); a SetActorRot without it to the angle that is there leaves the turn rate negative and the next turn jumps
(`setrot_snap_pending`); TurnActor is ignored while the body is more than two steps from the heading (`key_ignored_while_easing`); PointActorAt
jumps in the next frame (`pointat_next_frame`); the puck vector is the heading (`puck_is_heading`); SetActorRot ends a walk to a point
(`setrot_stops_walk`); eased turns play the right turn chore whichever way they go, the key its own side, the rest chore stops in the first
frame (`chore_*`); IsActorTurning / IsActorResting are walker+0x28 / +0x14 (`setrot_turning_*`, `turnto_turning`, `resting_flag`);
TurnActorTo steps rate * frame time without the time scale, true while a whole step was taken (`turnto_*`). The original's right turns are
0.022 degrees short a step (its sine table), so `turnto_step_size` / `turnto_true_count` accept both 0.9847 and 1.0 of rate * frame time.
The cases take their points from `AR_NT_O` (the start of Manny), so the same functions run on a plain save through a debugLua hook.
Lua 3.1 allows 32 locals in a function: the tier is split in functions (`ar_nt_turn_*`).

## Tests without game data (2026-10-30): `synth/`

`sh synth/all.sh` (under a minute, needs only Lua 5.1: `pacman -S mingw-w64-ucrt-x86_64-lua51`, and Python): the planner and the follower of
`ar_nav.lua` on small sets made for the purpose (`synth/sets/*.set`, the text format of the game's set files), with the Lua 3.1 of the game replaced by
`synth/compat.lua`. No archive, no ScummVM, no game.

* `synth/run.lua` (`sh synth/run.sh [part of a name]`): the checks of `test_planner.lua` (rooms, islands, a gate that is off, a 12 cm neck, a ramp),
  `test_follow.lua` (a simulated Manny that turns, steps 2.5 cm and slides along walls follows the way; the rule that a turn is not cut over the void
  at the foot of a ramp) and `test_door.lua` (the trigger of a door whose way through is off).
* `synth/fuzz.lua [seed [count]]` (`sh synth/fuzz.sh`): random sets of rooms that touch along parts of their edges, random pairs of points, every way
  checked to stay on the floor (1 cm tolerance) and followed to the end. A failure prints the seed; `FUZZ_TRACE=1 FUZZ_PAIR=<n> FOLLOW_TRACE=<frames>`
  shows the rooms, the way and the walk.
* `synth/bench.lua`: the time of a plan on a large world and where it goes (a sampling profile).
* `synth/test_tools.py`: `tools/logts.py` and `tools/gaps.py`.
* A check for a fix should fail on the code before it: `AR_NAV_FILE=/tmp/old.lua sh synth/run.sh` runs the same checks on another copy of `ar_nav.lua`.

## Where a run waits (2026-10-30)

`run_all.sh` stamps every AUTORUN line with the wall clock (`logs/<name>.ts`, `tools/logts.py`); `python tools/gaps.py logs/<name>.ts [seconds]` lists the
stretches without one, longest first, with the lines on both sides and the chapter. `STALL=<seconds>` (default 90) kills a run that logs nothing for that
long (`stall_watch.sh`, with a report of the scripts that are running, `stall_diag.lua`).
