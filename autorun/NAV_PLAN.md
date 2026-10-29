# Grim autorun pathfinding: design, review and test plan

Status: a plan, nothing in it has been run. It reviews the rewrite of `ar_nav.lua` (and the `ar_go` change in
`ar_lib.lua`) made on 2026-10-24, against the first run of `test_nav.lua` under ScummVM (`logs/test_nav.log`:
unit 10/24, walk 5/18), the game's own scripts (`C:\Users\Joel\grim_lua_src`), the ScummVM engine source and
decompiles of the original (`/v101/GRIMFANDANGO.EXE` in Ghidra). Where a cause is inferred from the log rather
than confirmed in code it says so.

Contents

0. The rule: one script, two engines
1. Ground truth: what the two engines do
2. Review of the current implementation
3. The design
4. Edge cases, with the real level data
5. Test plan
6. Order of work
7. Open questions that only a run can settle

---------------------------------------------------------------------------------------------------------------

## 0. The rule: one script, two engines

* The run (what `run_all.sh` and `build_original.sh` assemble from `ar_lib.lua`, `ar_nav.lua`, the data and the
  chapters) is the same code on both engines, with no branch on the engine. `AR_ORIGINAL` is removed from
  `ar_lib.lua` and the chapters; `ar_routes_original.lua` and `ar_route` are deleted (the planner is what makes
  them unnecessary; a route that is still needed on one engine marks an engine difference, see below).
* Any difference in behaviour between the engines that the run meets is a ScummVM bug and is fixed in
  `engines/grim`. It is never worked around in the scripts, not with a flag, not with a longer wait, not with a
  different route. The original is the reference.
* ScummVM builtins that the original does not have (`IsSectorActive`, `DumpSectors`, `SetImmediateTasks`) are
  development tools. They may be used to generate data (`ar_nav_data.lua` comes from `DumpSectors`), as oracles
  in the tests (tier B checks the `IsPointInSector` probe against `IsSectorActive` on ScummVM) and in the test
  harness. They are not called in the run. The run enforces it: the assembled script starts with
  `IsSectorActive = nil  DumpSectors = nil  SetImmediateTasks = nil`, so a call to one is a Lua error, the
  autorun task dies and the watchdog fails the run ("the script of the run has died"). A ScummVM full pass with
  that guard is part of the pass criteria (5.5).
* Engine-side switches of how the game is *driven* are not builtins and stay: `--autorun=` (ScummVM loads the
  script; the original gets it by the F12 injection), `--sim-fps` (the deterministic clock the ScummVM runs use;
  never `--time-scale`), the save-slot and config options.

What the run uses today that this rule removes (found by grep on 2026-10-24):

| Where | What | Replacement |
| --- | --- | --- |
| `ar_lib.lua` 484 `ar_note_camera` | calls `DumpSectors()` on every new set under ScummVM | a dev script `dump_sectors.lua` (or `DUMP=1` on `run_chapter.sh`) that visits the sets and dumps; the run does not dump |
| `ar_nav.lua` 149 `ar_nav_active` | `IsSectorActive` on ScummVM, "all on" on the original | the `IsPointInSector` probe on both engines (3.8), after the ScummVM fix E1 |
| `ar_routes_original.lua` 57, 79-85 | waits on `IsSectorActive("hl_elev")`, `("hl_door_psg1")` | the file goes; a wait that is still needed uses the probe |
| `ch38_chepito.lua` 61, 67 | `SetImmediateTasks(TRUE)`/`(nil)` round the Pearl cutscene (a ScummVM scheduling knob; a no-op stub on the original) | an engine difference: ScummVM must start a new task the way the original does without a switch (E4); the calls go |
| `ar_lib.lua` 429 | skip a line that never ends, original only | the same code on both (a line that never ends is skipped on either) or none |
| `ar_lib.lua` 827 `ar_fix_head` | reset the head joints when nothing is seen, original only | the same on both, or the cause (why nothing is seen) fixed |
| `ar_lib.lua` 959 `ar_approach` | push toward the object when the walk ends out of range, original only | the planner's goal snapping (3.5) ends the walk in range on both; branch goes |
| `ar_lib.lua` 1282 `ar_checkpoint` | the original saves from the menu render mode, ScummVM from the normal state | the menu's save sequence on both engines (one code path; the user asked for the menu's method anyway) |
| `ar_lib.lua` 1727 `ar_drive_to` | the original's wagon stops dead at the road edge, ScummVM's slides along it | an engine difference: fix the edge behaviour in ScummVM (E5); branch goes |
| `ch06`, `ch07`, `ch09`, `ch11`, `ch14`, `ch64` | `if AR_ORIGINAL then` waypoints, routes, waits | removed; each one that turns out to be needed is an engine difference to find and fix |

---------------------------------------------------------------------------------------------------------------

## 1. Ground truth: what the two engines do

Everything the planner models has to come from here. Each item names its source.

### 1.1 Walking

* `WalkActorForward` moves the actor `walkRate * dt` along its move yaw, clipped to `walkRate / 5` a frame,
  through the active walk sectors; at an edge with no neighbour it turns the actor along the edge by
  `angleWithEdge + 1` degrees and tries again, up to 3 times, unless the angle with the edge is more than the
  reflection angle (80) in which case it stops (`Actor::walkForward`, `engines/grim/actor.cpp`; original
  `FUN_004a8610`, the same shape). This is why a wall "turns Manny along itself" and why a heading more than
  80 degrees off a wall gets him nowhere.
* `TurnActor(h, dir)` adds one turn-rate step a frame to the *target* yaw; the actor eases toward it. ScummVM at
  60 fps turns about 1.4 degrees a frame, the original (about 15 fps) about 5.6. `ar_steer` already measures the
  step (`AR_TURN_STEP`) so both engines are steered by the same code.
* The original moves no actor while a fullscreen movie plays even with control back; `ar_steer` waits for the
  movie. Keep.

### 1.2 Sectors and Doorman

* Sector types: walk 0x1000, funnel 0x1100 (counted as walk by `ar_nav_data.py`: 4352), camera 0x2000,
  special 0x4000, hot (chernobyl) 0x8000. The data file has 99 sets, 405 hot sectors.
* `Doorman()` (`_system.lua` 1390) runs every frame of `TrackManny`: the first frame Manny is found in a hot
  sector (`find_sector_type(HOT)`), with `doorman_in_hot_box` false: if the set's `cheat_boxes[name]` is set he is
  teleported (`teleport_out_of_hot_box`), else if the set table has an object under that sector name:
  `climbOut` is called, or `Sentence("walkOut", obj)` is started. A hot sector with no object of that name does
  nothing. `doorman_in_hot_box` resets only when he is in no hot sector at all, so a door reacts to *entering*,
  not to standing in it.
* Hot sectors are tested with the same point-in-sector routine as walk sectors, so an inactive
  (`MakeSectorActive(name, FALSE)`) hot sector does nothing.
* Cheat boxes: `GetSectorOppositeEdge(actor, name)` (ScummVM `lua_v1_set.cpp` 175, same in the original by the
  earlier Ghidra work): a ray from the actor *backwards along his puck vector* finds the edge he came in by
  (vertices k, k+1); the fraction along it is measured from vertex k+1; he is put on the edge (k-2, k-1) at that
  fraction from vertex k-2. The box must have 4 vertices (ScummVM warns otherwise). Because Doorman runs a frame
  after he crossed the edge, the fraction is of the back-projection along his heading, not of the exact crossing
  point: entering square to the edge they coincide, entering at an angle they do not.
* The sets with cheat boxes (the game's own tables): al (1), ea (1), fh (1), ga (8), ha (1), lx (2), me (1),
  rf (2); `tg.cheat_boxes = { cheat_box1 }` is a list holding nil, so Temple Gate's cheat box never fires in
  either engine. Hot sectors named `*_cheat*` in other sets (lb_cheat1/2) are *not* in `cheat_boxes`: they are
  objects with a `walkOut` that calls `manny:setpos` to the other one (`lb.lua` 451, 462), i.e. a teleport by
  script that the planner cannot see from the sector data.

### 1.3 Constrained sectors (stairs and curbs)

* `stairman`/`curbman` (`_system.lua` 932, 969), started by `TrackManny`, poll `find_sector_name("stair")` /
  `("curb")` (substring match) and call `SetActorConstrain(actor, TRUE)` the frame he is found in one, `FALSE`
  when he has left all of them. `TrackManny` also clears the constraint when it starts.
* The original's `SetActorConstrain` (`FUN_004a85b0`, via `FUN_004933e0`): if the actor is not on a scripted
  walk and stands on a walk sector, it computes a line (`FUN_004a7520`): a ray from his position *backwards*
  along his puck vector finds the entry edge (if the exit is at a corner along an edge, the other edge of that
  corner is taken); the fraction along that edge, clamped to 0.15..0.85, is taken on the opposite edge
  (vertices k+1 .. k-2) and the line from where he stands to that point is the constraint direction. While
  constrained, `WalkActorForward` (`FUN_004a8610` top) moves him only along that line, either way, and not at all
  if his heading is more than the reflection angle off it; at a wall it turns him along the edge and re-derives
  the line. Measured on the Blue Casket stairs (probe, 2026-10-24): headings 0/30/60/300/330 move up the axis,
  120..240 down, 90 and 270 not at all.
* ScummVM's `SetActorConstrain` was a stub. It is now implemented in `actor.cpp` (`Actor::setConstrain`,
  the `_constrained` branch in `walkForward`; save minor version 34). Unverified against the original beyond the
  probe above: the test plan below is how it gets verified.
* Nineteen sets have constrained sectors (walk or hot): office steps, st (curb1..5), rubamat exterior,
  cafe office, Elevator Station (stairs_14/15), Blue Casket Exterior (stairs), Blue Casket interior, high roller
  lounge (stair_bot_box/stair_top_box, hot), track stairs, lol gate (6 + stair_box), shuttle security, police
  station (4), lola zapata, crane conveyor, truck depot, mayan workshop, theater sewer, le mans lobby (3),
  morgue.

### 1.4 Sector activity

* ScummVM: `IsSectorActive(name)` exists (exact name, `isVisible()`); the original has no such builtin.
* The original's `IsPointInSector(x, y, z, name)` (`FUN_0049c4c0`) walks the sector list, substring-matches the
  name and tests the point with `FUN_004a6980(pt, 1)`, which returns false when the sector's word at +0x2c is 0
  or its visibility word at +0x28 is 0. So on the original a point test on an inactive sector is nil: activity
  *can* be read, by testing a point known to be inside each sector.
* ScummVM's `Lua_V1::IsPointInSector` uses `Set::getSectorBySubstring(name, pos)` (`set.cpp` 1102), which does
  not check `isVisible()`. This is an engine difference and must be fixed in ScummVM (section 3.9). The game
  itself calls `IsPointInSector` in `al.lua` 82 (the elevator box), so the fix also matters to the game.
* Vertical tolerance of a point test: original `|dist to plane| <= height` with height replaced by 0.005 for
  walk sectors whose height is 0 or missing (loader `FUN_004a7bc0`); ScummVM `|dist| <= height + 0.01` when
  height < 9000. Close enough for planning; noted so nobody is surprised by a 1 cm difference at a ledge.

### 1.5 Lua facts the code depends on

* `TRUE = 1`, `FALSE = nil` (`_system.lua` 5, 6). Storing `FALSE` in a table stores nothing.
* Lua 3.1: no `local function`, no `break`, 32 locals a function, closures cannot capture locals, `format("%s")`
  with an empty string prints stale buffer contents (seen in the test log: `links [he goal;]`). Build log
  strings by concatenation, never `%s`.
* `start_script` returns a task value (`tostring` gives "task: N"); `call()` breaks yielding.

---------------------------------------------------------------------------------------------------------------

## 2. Review of the current implementation

### 2.1 What is right and should stay

* One search over one world model, with the cheat boxes and the stairs as links the search *uses* rather than
  obstacles it avoids. This is the correct shape and the user's stated requirement.
* The cheat-box link geometry matches `GetSectorOppositeEdge` (fraction measured from vertex e+1 on entry,
  landing at the same fraction from vertex e-2 on the opposite edge).
* A door is reached by walking into its hot sector and letting Doorman act; the use-point-and-USE path is the
  fallback. `ar_go` lost its out-point and elevator special cases.
* Cells of 8 cm with "a cell is floor if any floor polygon reaches into it" (the 2.5 cm bottle passage on the
  ship is found; test `thin_passage` passes on ScummVM, 6.9 s).
* One follower with few rules: aim a little ahead, turn on the spot when far off, exact only at link steps and
  the goal, "held up" by the way-left metric, soft-block the cells ahead and replan.
* The ScummVM `SetActorConstrain` implementation and the save-version bump.
* `test_nav.lua` as the idea: the same cases on both engines, Manny teleported in, plan and walk checked
  separately.

### 2.2 Deficiencies

Design level

D1. Working state in ~25 globals (`AR_G`, `AR_PARENT`, `AR_VIA`, `AR_SZ`, `AR_PX/PY/PSI/PPART`, `AR_PEN`,
    `AR_HEAP`, `AR_GOAL_K`, `AR_GOAL_LINKS`, `AR_GOAL_LINK_OF`, `AR_GOAL_REGION`, `AR_GOAL_HOT`, `AR_HX/HY`,
    `AR_W_E/X/Y/HOT`, `AR_NEAR_X/Y`, `AR_NAV_GOAL_X/Y/FOR_X/FOR_Y`, `AR_SEARCH_STEPS`). The 32-locals limit forced
    globals, but they are reset inconsistently: `AR_GOAL_LINK_OF` is only cleared when a link goal was found
    (`ar_nav.lua` 1223), so a stairs plan leaves cell keys that a later plan in *another set* can match (cell keys
    are small integers and collide across sets); `AR_NAV_GOAL_X` is cleared in `ar_nav_go` but read by `ar_far`
    and the tests; `ar_w_code` leaves its result in `AR_W_E/X/Y/HOT` that every caller must copy before the next
    call. Confirmed in code; the test log is consistent with it (plans that "end 1.0..1.8 m from the goal" right
    after the stairs cases) but that is inferred.
    Fix: one search-state table `S` created per plan (`S = { g = {}, parent = {}, ... goal = {...} }`), passed
    explicitly, dropped at the end; `ar_w_code` returns a record instead of setting globals (a table return is
    one local).

D2. Goal snapping is silent and unbounded. A goal with a wrong height, or in a sector that is off, is moved to
    the nearest active floor *at about that height* (`ar_nav_closest` with `zf`), possibly metres away, and then
    walked to. In the test: `cheat_alley` and `lobby_long` goals were typed with z = 0 where the floor is at
    another height (lb_cheat2's use point is at z = -0.74), and the reports say "ended 7.3 m from the goal" while
    Manny stands on the typed x, y; the hallway goal (7.12, 0.90) lies on floors that are off until the elevator
    arrives, so it snapped to the nearest active floor, the garage door passage, and Manny walked through the
    garage door trigger into the Garage. Inferred from the log; the mechanism is confirmed in code.
    Fix: snap distance cap (0.5 m) beyond which the plan fails with "the goal is off the active floor", and the
    snapped goal always logged; `z` resolved from the sector data when the caller's z is more than 0.35 off every
    floor at (x, y) and only one floor is there.

D3. Sectors of doors and triggers are passable at 25x cost. A hot sector whose object has `walkOut` changes set
    (or starts a cutscene) when entered; routing through one for a goal that is not it is never right. The
    hallway walk above ended in the Garage for this reason. Fix: `walkOut`/`climbOut` sectors impassable unless
    they are the goal; hot sectors whose object has no `walkOut` (eva_chat_box: a chat) passable at a mild cost;
    "no way" is then the honest answer and the chapter must use `ar_go` with a via point.

D4. Stairs are modelled twice: as links (entry edge -> walk the line -> landing) and, for a goal *on* the
    stair, as "goal links" (`ar_w_goal_links`, `AR_GOAL_LINK_OF`) with a special way construction; the start on
    a stair has a third path (`ar_w_plan_off_cons`, which uses Manny's *facing* rather than the engine's line
    rule). Three of the four stairs cases fail: `stairs_to_point_on_them` (the plan ends 0.85 m short, the walk
    stands 2 cm from the goal for 8 s because the goal check measures to the plan's last point),
    `stairs_start_on_them`, `stairs_up`. Fix: one model (section 3.4): a constrained sector is a set of
    *lines*; a link is one line from its entry point to its exit point; the goal test matches any point on a
    line within the goal tolerance; the start on a stair uses the same back-projection rule as the engine.

D5. A start cell that is not plain floor (inside a cheat box or a door sector, or off the floor after an
    elevator) has no moves: `ar_w_step_cost` returns nil for code 3, links start only from floor cells.
    `cheat_garage_back` from (15.62, -0.50): "no way, 48 cells searched" (inferred: the start is in or at a
    cheat box). Fix: the first step out of the start cell is always allowed, whatever the cell is.

D6. Script teleports (lb_cheat1 -> lb_cheat2 and back) are unknown to the planner: `lobby_long` walked into
    lb_cheat1, was "moved by the game", replanned, and arrived (the 13.45 m in the report is D2, the typed z).
    One replan is acceptable; six are a failure. Fix: learned links: when the game moves Manny more than 0.5 m
    while he is in a hot sector, record `(sector -> landing point)` in a per-set table that persists in a data
    file (`ar_nav_learned.lua`), and plan with it next time. Generic: it also covers cheat boxes whose landing
    differs from the geometry.

D7. The original cannot read sector activity today (`IsSectorActive` nil -> everything on). The planner will
    route over the ship's `bottle` sectors while they are off, or to the hallway's elevator floors before the
    elevator comes, and Manny stands at the edge "held up" until the replans run out. Fix (section 3.8): read
    activity on the original with `IsPointInSector` at a point known to be inside each sector, after the
    ScummVM `IsPointInSector` fix so that both engines answer the same question.

D8. Soft blocks on "held up" cover 3 cells in the heading direction. An actor in the way (Toto and Naranja at
    the table, the forklift) is wider than that; the walk alternates "held up / replan" up to 6 times. Fix: block
    a disc of radius 0.2 m ahead, and raise the cost rather than forbid (already so), with a cap of 4 replans
    before failure.

D9. Door "from inside" (standing in the door's sector): step out to the nearest floor cell, then in. The test
    `door_from_inside` (Manny's Office door) came back "now in Manny's Office": the step out probably ended
    inside the sector (the nearest plain-floor cell within 0.8 m may still be inside a larger hot box, or
    `doorman_in_hot_box` never cleared). Fix: step out to a cell outside *all* hot sectors, wait one frame
    (Doorman must see him out), then in; and verify with `find_sector_type(HOT)` being nil before the step in.

D10. `ar_w_geo` caches "not floor" as `FALSE`, which is nil: every miss recomputes the full sector scan.
    Confirmed (`FALSE = nil`). Fix: cache 0 and test `g == 0`.

D11. The region goal "a step further in": the last point is moved up to 15 cm into the door's sector along the
    last stretch; with a narrow sector (hq_al_box is 0.4 x 0.525) and an approach from the side this can be
    outside. Minor; the follower's `ar_w_in_goal_hot` check ends the walk on entry anyway.

Follower level

F1. Running/walking toggles every frame near the 0.8 m / 20 degree thresholds (`set_run` each frame is harmless
    but the chore restarts). Add hysteresis (run above 1.0 m, walk below 0.6).
F2. The lookahead LOS test runs `ar_w_los` (up to 9 samples, each a `ar_w_code` and `ar_w_pen`) every frame; on
    the original's Lua that is measurable. Cache the aim point until Manny has moved 4 cm or the point index
    changed.
F3. "held up" uses 3 s with no 3 cm shortening; a stair link of 1.5 m walked at the walk rate (0.4 m/s) shortens
    fine, but the *turn* onto a link entry (limit 15 degrees, turning on the spot) can take 3 s on the original
    at 5.6 degrees a frame only if it is 180 degrees; acceptable. Keep, but count turning-on-the-spot frames as
    progress as the old follower did (`bestat = waited` while turning).
F4. A `Sentence` running ends the walk ("the game took over"). Any sentence does, including one the chapter
    started a moment before (an item use). Restrict to a sentence whose verb is `walkOut`/`climbOut`
    (`system.currentSet`'s door objects) or to Manny being in a door sector.

Engine level

E1. ScummVM `IsPointInSector` ignores activity (1.4). Must be fixed; it is also the probe the original will use.
E2. ScummVM `SetActorConstrain`: implemented, unverified on anything but the Blue Casket stairs. The follower
    assumes it; the stairs cases of the test are its verification.
E3. The original has no `IsSectorActive`; after E1 the planner needs no engine-specific branch (3.8), and by
    the rule of section 0 it may not have one.
E4. `SetImmediateTasks`: ch38 switches ScummVM's task scheduling so that `start_script(manny.walkto)` has the
    actor walking in the same frame, as the Pearl cutscene expects. That is the original's behaviour; ScummVM
    must do it always (find in `ltask.cpp` why a new task waits a frame, compare with the original's
    `lua_updatetasks`), and the builtin goes.
E5. The wagon at the edge of the road: the original stops it dead, ScummVM slides it along the edge
    (`ar_drive_to`'s `AR_ORIGINAL` branch backs up and drives on). The vehicle is an actor driven by the same walk
    code; find why `walkForward` reflects where the original does not (the reflection angle, or the vehicle's
    `_followBoxes`), fix ScummVM, remove the branch.

Test harness level (`test_nav.lua`)

T1. Hand-typed coordinates with wrong heights (alley rope ledge, lobby far end): D2 turned them into bogus
    failures and bogus passes are also possible. Goals must be taken from objects (`set.obj.use_pnt_*`,
    `obj_x/y/z`) or have z resolved from the sector data; every case logs the resolved goal.
T2. World state is not set up: the hallway elevator floors, the ship's bottle sectors, doors that are locked
    (`mo.ha_door` early in ch01?) differ from the story moment. Each case must list the sectors to switch on/off
    and the object states it needs; the harness applies them and logs `IsSectorActive`/`IsPointInSector` for
    each sector it touches, on both engines.
T3. `set:switch_to_set()` runs the set's enter code; twice the harness logged "the game never gave control
    back" (Blue Casket Exterior). Use the skipper during placement, or `START_CUT_SCENE/END_CUT_SCENE`-free
    placement: `set:switch_to_set()` then `ar_skipper` for 3 s, then `ar_wait_for_control()` with a 10 s cap and
    the case marked "placement failed" rather than counted as a walk failure.
T4. `format("%s")` garbage in the reports (1.5). Concatenate.
T5. No per-plan timing, no cell count thresholds, no canonical way string: the two engines cannot be diffed.
T6. No offline run: every iteration costs a game start (ScummVM ~90 s to the first case; the original ~30 s plus
    the resume). A parse error (a 33rd local, a `local function`) is only found by the game as well.

### 2.3 Verdict on the plan

The architecture is the right one and should not be thrown away. The failures are concentrated in three places
that the architecture did not address: state hygiene (D1), the model of stairs (D4) and the model of what a goal
is (D2, D3). Fix those three and the engine difference E1, and the remaining items are small. The test as written
cannot tell a planner bug from a data or state error (T1, T2), so it must be fixed before it is used to judge
anything.

---------------------------------------------------------------------------------------------------------------

## 3. The design

### 3.1 Data

`AR_NAV[set name] = { n, t, p, hn, hp }` as today (names, types, polygons of the walk sectors; names and polygons
of the hot sectors), made by `ar_nav_data.py` from ScummVM's `DumpSectors` output. Add:

* `ar_nav_learned.lua`: `AR_LEARNED[set name] = { { from = "hot sector", x, y, z = landing, n = times seen }, ... }`
  written by the integration runs (3.6) and read by the planner. Checked in like the data file.
* Per set, an interior probe point for every sector (`pp`, `hpp`): the centroid if inside, else the point of the
  sector nearest to the centroid moved 1 cm in. Computed once by `ar_nav_data.py`, not at run time; used by the
  activity probe (3.8).

### 3.2 World model (per set, built on entry, cached by set)

Cells of 8 cm over the bounding box of all sectors. For each cell, computed on demand and cached:

    geo[k] = 0                       -- no floor reaches into the cell
    geo[k] = { e = { { si, x, y, part, h = { hot sectors at (x, y) } }, ... } }

one entry per walk sector that reaches into the cell, with the sector's point for the cell (the centre if inside,
else the sector's nearest point moved up to 1.6 cm in; `part = TRUE` then). This is what makes a 2.5 cm passage a
chain of cells and keeps two floors over each other (Ledge: four levels within 0.4 m of x, y) apart.

`code(k, zref)` -> the entry whose height is nearest to `zref` (within 0.35; `part` entries lose a 1 cm tie) among
the *active* sectors, and its kind:

    FLOOR      plain floor
    CONS       a constrained sector (walk sector or hot sector whose name holds "stair" or "curb")
    CHEAT      inside an active hot sector that is in set.cheat_boxes
    DOOR       inside an active hot sector whose set-table object has walkOut or climbOut
    TRIGGER    inside any other active hot sector (does nothing or starts a chat)

The classification of a hot sector is done once per set (`w.kind[h]`), activity is read per query (3.8).

### 3.3 Links

A link is `{ kind, fk, tk, px, py, pz, ex, ey, lx, ly, lz, cost }`: from the floor cell `fk` at the pre-point
(px, py) over the step-in point (ex, ey) to the landing (lx, ly) in cell `tk`.

* Cheat box (4 vertices, active, in `cheat_boxes`): for each edge, at fractions 0.25/0.5/0.75 from vertex e+1,
  pre-point 22 cm outside square to the edge, step-in 6 cm inside, landing at the same fraction from vertex e-2
  on edge (e-2, e-1), 12 cm outside it. Both ends must be FLOOR (or DOOR when that is the goal). Cost 0.4 m.
  When the 22 cm pre-point is off the floor (a box flush against a wall) shorten it to the longest of 22/14/8 cm
  that is on the floor (section 7, the meadow and factory hub).
* Constrained sector: for each edge and fraction 0.2 .. 0.8, the entry point 4 cm inside; the line by the
  engine's rule (`ar_w_cons_dir`: back-projection to the entry edge, corner rule, fraction clamped 0.15..0.85,
  opposite edge); the line is walked in 3 cm steps while inside any constrained sector and on floor within 0.35
  in height; the link's landing is 10 cm past the exit. The link also keeps its *line* (`lx0, ly0, lx1, ly1`)
  so a goal on it can be matched (3.5). Cost = length + 0.4.
* Learned (3.6): from the sector's cells to the landing, cost 0.4.

### 3.4 Search

A* over cells, 8-connected, no corner cutting (both side cells must be FLOOR), diagonal 0.113 m. From the start
cell, every step out is allowed whatever the start cell is (D5). Step cost into a cell:

    FLOOR / goal DOOR     d * (1 + 0.6 * pen^2) * held
    TRIGGER (not goal)    d * 4 * held
    DOOR, CHEAT, CONS     not steppable (reached by links only; CONS also not steppable: the engine would not
                          let him walk across it freely)

`pen` = 2 next to a non-FLOOR cell, 1 one cell further, 0 otherwise (keeps the way off the walls);
`held` = 1 + 8 * (soft blocks on the cell this walk). Heuristic: straight distance to the goal point. From a cell,
its links are relaxed with the link cost; the landing's height is the link's. Between two cells of different
sectors, or where either point is `part`, the midpoint must be floor within 0.35 in height (no gap, no wall).
Cap 100000 pops; the garage (18 x 11 m) has ~31000 cells.

All search state lives in one table `S` created by the plan and dropped after it (D1).

### 3.5 Goals

A plan is asked for either a point or a door.

* Point (x, y, z): if no active floor holds it within 0.6 in height, snap to the nearest active floor point at
  that height moved 3 cm in; if the snap is more than 0.5 m, or there is none, the plan fails with the reason and
  the snapped point (D2). The goal cell is the nearest FLOOR or DOOR cell within 0.25.
  If the point is on a CONS sector, the goal is any cell whose link line passes within the tolerance (0.12) of
  the point: the way then ends with the link's pre-point ("x"), the step ("s") and the goal ("g") on the line.
* Door: the active hot sectors the set names after the door object (`ar_nav_door_hot`). The goal is any cell of
  those sectors; the heuristic aims at the centroid of the first. If Manny already stands in one of them, the
  walk first goes to the nearest cell outside *all* hot sectors, waits a frame, then plans in (D9).
* The start on a CONS sector: the line is derived by the engine's rule from Manny's position and heading; the
  way out is along it, either direction, whichever gives the cheaper total; then the normal plan from the exit.

### 3.6 The way and the follower

The way is a list of `{ x, y, z, kind }` with kinds `p` (passed), `x` (reached within 5 cm), `c` (step into a
cheat box), `s` (step onto a stair), `g` (goal). Between links, runs of `p` points are pulled straight with a
line-of-sight test that may not pass nearer to non-floor than the cells it replaces (`pen` cap).

The follower, each frame:

1. Advance past `p` points that are behind (projection past the point or within 6 cm), `x` within 5 cm, `c` when
   he is nearer to the landing than to the step, `s` once he has been inside and is out again (or within 4 cm).
2. Aim: for `p`, the point 35 cm ahead along the way if the floor between is clear, else 15 cm, else the point;
   for `c`/`s`, straight on over the step (twice the last stretch); cached until he has moved 4 cm (F2).
3. Run only on a straight stretch longer than 1.0 m with the heading within 20 degrees, walk under 0.6 m (F1).
4. Steer (`ar_steer`); step forward when the heading is within 40 degrees (`p`), 15 degrees (`x`, `c`, `s`
   before the step), 70 degrees once on the stair (the engine holds the line).
5. Progress: the way left (distance to the current point + the rest); no 3 cm shortening in 3 s = held up
   (turning on the spot counts as progress, F3): soft-block a disc of 0.2 m ahead (D8) and replan. A move by the
   game of more than 0.5 m: if a `c` step was expected and he landed near its landing, go on; else record a
   learned link if he was in a hot sector (3.1) and replan.
6. Done: in a sector of the goal door; or at the goal within 4 cm, or past it (nearest was under 12 cm and the
   distance grows); or held up at the last point within 20 cm (the use point is behind a wall).
7. Over: the set changed, `stop_when`, a walkOut/climbOut sentence is running (F4), the keys are blocked (chain,
   floating), the budget is spent (a failure).

Replans: at most 4 per walk; then a failure naming the cells blocked. Budget: 4 s + 2 x (way / walk rate +
turns / 85 deg/s).

### 3.7 `ar_go` and `ar_approach`

* `ar_go(door, target[, via])`: via point first (if given); then into the door's sector (3.5); if the door has
  no active sector or the plan fails, to the use point and USE; three attempts with the shut-door retry; the
  outcome is "the set changed" (or `AR_SEEN_STICKY`).
* `ar_approach(obj)`: unchanged in intent: to the use point (or face it when already near), then creep and scan.
  It calls `ar_walk_to`, which calls the planner; the planner's failure reasons propagate.

### 3.8 Sector activity on both engines

`ar_nav_active(nav, i)`, the same on both engines (section 0):

* `IsPointInSector(pp.x, pp.y, pp.z, name)` with the sector's probe point, nil when off (needs E1 on ScummVM).
* `IsSectorActive(name)` (ScummVM only, exact name) is never called by the planner; tier B uses it as the oracle
  the probe is checked against.
  Substring match: the probe answers for the first sector whose name *contains* the string and holds the point;
  with the probe point inside the named sector that is the named sector unless another with a longer name
  containing it also holds the point (e.g. "stair1" vs "stair11": the point of stair1 is not in stair11). Cases
  where two sectors with such names overlap must be listed by `ar_nav_data.py` (a warning) and resolved by the
  ScummVM `IsSectorActive` answer in tier B; today's data has "stair1"/"stair11" only in sets where they do not
  overlap (to be checked by the script).
* Cached per plan (one table in `S`), not per query.

### 3.9 ScummVM changes

Done: `Actor::setConstrain`, the constrained branch of `walkForward`, `Lua_V1::SetActorConstrain`, save minor
version 34.

To do:

* `Lua_V1::IsPointInSector`: reject sectors that are not visible (match `FUN_004a6980(pt, 1)`). Either a
  `getSectorBySubstring(name, pos, visibleOnly)` or a loop in the Lua binding. Check the game's own use
  (`al.lua` 82) still behaves.
* Review `IsActorInSector` the same way (it uses the same substring-with-position lookup; the original's
  `GetActorSector`/`IsActorInSector` probably also pass flag 1; confirm in Ghidra before changing).
* E4 (`SetImmediateTasks`) and E5 (the wagon at the road edge): section 0 and the E items above.

---------------------------------------------------------------------------------------------------------------

## 4. Edge cases, with the real level data

Each case: set (table), the geometry that makes it hard, start and goal, and what must happen. Coordinates are
from `ar_nav_data.lua` and the set scripts; z is the floor's. These are the cases of `test_nav.lua` after the
fixes of T1/T2.

### Stairs and curbs (constraint)

S1. Blue Casket Exterior (be), down the stairs into the door. `stairs` (0.35..-0.375 x, -0.3..-0.7 y, z 0 -> 0.26),
    hot `bw_box` below it. From (0.00, 0.66, 0) into `be.bw_door`. Expect: one `s` link, the walk ends in bw_box,
    set becomes blue casket wide. (ch16, ch20; the original stalled here for 8 s before the constraint was
    understood.)
S2. be, to a point on the stairs: `be.bw_door` use point (0.0589, -0.604, 0.19). Expect: the way ends on the
    stair line within 12 cm; the walk stands within 4 cm. (Failed: D4.)
S3. be, start on the stairs at (0.02, -0.50) heading 180, to sect_19 (0.17, -1.10, 0.26). Expect: out along the
    line downward, then floor. (Failed: D4.)
S4. be, up: from sect_19 (0.05, -0.85, 0.26) to floor_2 (0.00, 0.66, 0). Expect one `s` link upward. (Failed.)
S5. Elevator Station (ev), `stairs_14`/`stairs_15`, a multi-level set (-0.1 .. 1.2). From (0.18, -1.12) to
    (1.11, 0.92) (the ch15/ch18 route). Expect two `s` links or one, no level mixing.
S6. high roller lounge (hh): the constrained sectors are *hot* (`stair_bot_box`, `stair_top_box`), levels
    0 .. 1.9. Expect: the hot-constrained classification; a way up the stairs.
S7. st (curb1..5): curbs are constrained the same way (curbman). A walk along the street that crosses a curb.
S8. lol gate: six stairs and a `stair_box`, levels 19.5 .. 22.2: the longest chain of constrained links.
S9. A heading more than 80 degrees off the stair line must not be used: the follower's 70 degree limit while on
    the stair and the planner's link entry square to the edge. Negative test: place Manny on `be.stairs` facing
    90, hold forward for 1 s, expect no movement on *both* engines (verifies E2).

### Cheat boxes (teleport links)

C1. Hallway (ha), `ha_cheat_box_1` (3.96..6.25 x, 0.09..1.12 y) spans the corridor. (0.84, 0.12) -> (7.12, 0.90)
    with the elevator floors on (`floor_2`, `floor_3`, `_1041998_11_59pm`, `ha_elevos_*`: set up by the case).
    Expect one `c` link each way. (ch01; failed: D2/D3 via sector state.)
C2. ha, start at the box's edge (4.16, 0.60) -> (0.84, 0.12): the first step out of a CHEAT cell (D5).
C3. Garage (ga), eight boxes: (0.83, 9.64) -> (17.72, 5.57) and (15.62, -0.50) -> (1.42, 9.90). Expect `c` links,
    no "no way" (D5), under 25 s of walking. (ch02/03.)
C4. Alley (al), `al_cheat_1`: (0.08, 1.44) -> the rope (-0.36, 7.59) at the *ledge's* height (resolve z; T1) and
    back. (ch05.)
C5. Roof (rf), two boxes: (-13.44, 11.05) -> (-2.31, 4.77). Passed: keep as the regression.
C6. lighthouse exterior (lx), `lite_tele_box` and `cheat_box_1`, levels 0 .. 3: links on the right level only.
C7. meadow exterior (me) `cheat1`, temp factory hub (fh) `cheat_box1`, exterior airlock (ea) `pole_cheat`: the
    link count of the world (>= 1 each). (`links_meadow` and `links_factory_hub` reported 0: both ends of the link
    must be floor at the box's height; to be looked at with the offline harness.)
C8. Temple Gate (tg): `cheat_boxes = { cheat_box1 }` is broken in the game; the box is a TRIGGER that does
    nothing. Expect: passable, no link, no teleport on either engine.
C9. Entering a cheat box at an angle: the landing fraction is of the back-projection. The follower enters square
    (aim twice the stretch over the step); test: a link whose pre-point is approached from 45 degrees still lands
    within 0.3 m of the predicted landing (compare `moved` in the walk log).

### Thin passages and narrow floors (113 walk sectors are under 6 cm wide)

N1. Scrimshaw Interior (si): `bottle` (2.5 cm wide) and `bottle1` between the table and the fridge, switched off
    while Naranja drinks. (-0.22, -0.22) -> fridge use point with them on. Passed; add the variant with them off:
    expect "no way" within one plan, then a wait, then success when they come back (ch20 waits up to 40 s).
N2. Ledge (le), floor_11 (11 cm wide, 1.3 m long) into floor_10 at a right angle, levels -0.06, 0, 1.2, 2.5, 4.16
    within the same x, y: (-0.05, 2.36, 1.2) -> (-1.16, 3.65, 1.2). Expect: all points at 1.2, the corner kept
    (not cut), no "held up". (Failed: held up at the corner; inferred: the lookahead aimed into the inner corner.)
N3. Hallway gates `ha_co_gate`, `ha_do_gate` (5 cm) that are switched on and off by the doors: a plan through
    them only when on.
N4. lobby `pk_pass2` (3.5 cm), Copal's Office `floor_18` (2 cm), Packing Room `floor_43` (3 cm): planner-only
    cases (offline): the cells chain through.

### Doors and triggers

D1. headquarters (hq), `hq_al_box` (1.025..1.425 x, -0.275..0.25 y) at the edge of the floor: from (0.50, 0.00)
    into `hq.al_door`. Passed (1.4 s). Keep.
D2. Manny's Office (mo), standing in `mo_ha_box` -> out and in again -> Hallway. (Failed: D9.)
D3. Hallway -> Garage through `ga_door_trigger` (6.58..6.85, 1.68..2.33): as a *goal* it is a door; as a
    non-goal it must be impassable (D3): a plan to (7.12, 0.90) must not touch it.
D4. ha `eva_chat_box`: a TRIGGER (walkOut starts a chat, no set change): passable at a cost.
D5. Lobby for Beaver Room (lb): `lb_cheat1` (7.20, -4.10, -0.51) <-> `lb_cheat2` (10.54, -8.70, -0.74), script
    teleports: first run "moved by the game" once and learns the link; second run plans with it (D6).
D6. A door whose sector is off (an elevator with the car away): the plan fails fast ("no way into the sector")
    and `ar_go` falls back to the use point and USE.

### Goals and starts

G1. Goal off the floor (a use point in the wall): snap within 0.5 m, 3 cm inside, logged. Fridge use point in si.
G2. Goal on an inactive sector: fail with the reason, no walk (C1 before the floors are on).
G3. Start off the floor (out of an elevator, standing in a box that is off): wait up to 4 s for it to come on
    (the old code did), then the nearest floor cell.
G4. Start inside a cheat box or door sector (after a teleport, or a save made there): first step out allowed.
G5. Goal within 4 cm of a wall and a goal behind an actor: "done" by the held-up-at-the-end rule.

### Actors and dynamic obstacles

A1. si: Toto and Naranja at the table, the way to the fridge passes them; Manny has collision off, they may not,
    the engine pushes him. Expect at most 2 replans with the 0.2 m soft disc (D8).
A2. de (truck depot) forklift at its use point: 3 cm goal tolerance, the shove case from the old notes.

---------------------------------------------------------------------------------------------------------------

## 5. Test plan

Three tiers, cheapest first. Every tier uses the same case table (`NAVTESTS`), so a case added in one is run by
all.

### 5.1 Tier A: offline planner tests (no game, the original's own interpreter)

`ar_nav.lua` is plain Lua over `AR_NAV` plus three things it asks the game: `IsPointInSector` (sector activity,
3.8), `system.currentSet.cheat_boxes` and the set table (which hot sectors are doors), and
`manny:getpos()/getrot()`. It is run offline on the original's interpreter: `tools/lua31/lua31.exe`, a C host of about 100 lines, 32-bit,
built with the installed i686 toolchain (`/c/msys64/mingw32/bin/gcc.exe`) against `C:\GOG Games\GRIMDATA\LUA.DLL`
(import library made with `gendef` + `dlltool`, or `LoadLibrary` + `GetProcAddress` for the dozen entry points).
The DLL exports the Lua 3.1 API the host needs: `lua_open`, `lua_strlibopen`, `lua_mathlibopen`, `lua_dofile`,
`lua_dostring`, `lua_pushCclosure` + `lua_setglobal` (what `lua_register` expands to), `lua_lua2C`
(`lua_getparam`), `lua_getnumber`, `lua_getstring`, `lua_isnil`, `lua_pushnumber`, `lua_pushstring`,
`lua_pushnil`, `lua_error`.

Why not Lua 5: the game's Lua numbers are 32-bit floats (both engines), its `format`/`strfind`/`cos` are the 3.1
ones (degrees, the `%s` bug), and its parser enforces the 32-locals limit and rejects `local function`. A Lua 5
harness would compute every threshold near 1..3 cm in doubles and would accept code the game rejects. The DLL
host computes exactly what the original computes, and the parser error comes out of `lua_dofile` in a second
instead of out of a game run. (ScummVM's `engines/grim/lua` is the same Lua 3.1 with the same float type; a
second host built from it is the fallback if a plan ever differs between the engines and the interpreter is
suspected. It needs stubs for the `common/` headers, `liolib` and `g_grim->getFrameTime()`, so it is not built
unless needed.)

The host registers, in C: `PrintDebug` (to stdout), `break_here`/`sleep_for` (no-ops: offline only plans run),
`IsPointInSector`/`MakeSectorActive` (over a table the case fills; no `IsSectorActive`: the planner may not use
it, section 0), `GetActorYawToPoint`
(the engine's formula), and runs in order: a prelude (`tools/lua31/prelude.lua`: `TRUE`, `FALSE`, a fake `manny`
with `getpos`/`getrot`/`setpos`/`setrot`, a fake `system.currentSet` with `name`, `cheat_boxes` and the door
objects as `{ walkOut = TRUE }`, built from `ar_nav_sets.lua`, which `tools/set_tables.py` extracts from the set
scripts in `grim_lua_src`), then `ar_nav_data.lua`, `ar_nav.lua`, and the case runner `tools/lua31/run_cases.lua`
over the same `NAVTESTS` table the in-game test uses (moved to `nav_cases.lua`, shared by all tiers).

Risks to check first: `lua_dofile` on text (the DLL has a `lua_assume_binary` flag, off by default; the game's
own text refusal is in the exe, not the DLL); the task model (`lua_Initialize`/`lua_updatetasks` may need to be
called once before `lua_dostring`); the DLL's C runtime for file reading (`ar_nav_data.lua` is large).

The runner checks, per case: found/not found as expected; link kinds present (`link = "c"/"s"`); every point on
the required level; the way ends within tolerance of the resolved goal (or inside the door's sector); no `p`
point nearer than 1 cell to a DOOR/CHEAT cell; cells popped under a cap; the plan under a time cap (wall clock,
a regression for the original's own speed, since it *is* the original's interpreter). It prints a canonical way
string (`"p 0.00 0.66 0.00; s 0.04 -0.26 0.02; ..."`, 2 decimals) that the in-game tiers print too, so the three
can be diffed. Runs in seconds; this is where D1/D4/D5 get fixed and where every new failure from a game run is
first reproduced (the game run logs the set, start, heading, goal and sector state; the case is added verbatim).

Lua 3.1 compatibility of the planner is enforced by the real parser: `lua31.exe ar_nav.lua` fails on a 33rd
local or a `local function`, so no separate checker is needed.

### 5.2 Tier B: in-game unit tests (plan only), both engines

`test_nav.lua` with `AR_NT_MODE = "unit"`: for each case, place Manny (3 below), set the sector state, plan,
print the canonical way string and the checks of 5.1 using the real `IsSectorActive`/`IsPointInSector`,
`cheat_boxes` and set tables. Differences from tier A point at the fakes (wrong assumption about the game) or at
E1 (sector state read differently by the two engines); differences between the engines point at E1/E2.

### 5.3 Tier C: integration tests (the walk), both engines

`AR_NT_MODE = "walk"`: the same placement, then `ar_walk_to`/`ar_nav_enter_door`; checked: arrived within
tolerance (or the set changed), no `FAIL` logged, replans <= 2, time of walking under the case's cap (per engine:
the original's clock runs at its own frame rate; the cap is in game time), and the learned links recorded. Each
case logs: start, resolved goal, plan string, walking time, replans, held-ups, cells blocked, end position, the
set. The reports are machine-readable (`NAVTEST <mode> <id> PASS|FAIL k=v ...`) and a Python script
(`tools/navtest_report.py`) tabulates ScummVM vs original side by side from the two logs.

Placement (T3): `set:switch_to_set()`, then run `ar_skipper` for up to 3 s and `ar_wait_for_control()` for up to
10 s; if control does not come back the case is reported `SKIP placement` and not counted; `manny:put_in_set`,
`setpos`, `setrot`, two `break_here()`. Sector state: `MakeSectorActive` for the case's `on`/`off` lists, then the
state of every sector the case names is logged with both `IsSectorActive` (ScummVM) and `IsPointInSector` (both).
Objects: `make_touchable`/`open` as the case lists (door D2 needs `mo.ha_door` openable).

Goals (T1): a case names an object field (`goal = { obj = "fridge", pt = "use" }` or `"obj"`) or a point with a
height resolved from the data (`ar_nav_find_any` ignoring z when exactly one floor is at (x, y); a case on a
multi-level set must give z). The resolved goal is logged.

Running: ScummVM `sh run_chapter.sh test_nav.lua 1200` (sim time; make `ar_load(19)` configurable: the test
starts from a save that has all sets' scripts loaded, slot 19 works today); original
`sh test_nav_original.sh` (built with `TESTFILE`), results in `grimdebug.log`. Both from the same `NAVTESTS`.

### 5.4 Tier D: the full game

Unchanged: `sh run_repeat.sh N` for ScummVM (every script change needs one full pass, as the standing rule
says), and the original resumed per chapter (`resume_chapter.sh chNN`) until it goes through ch65. Every walk
failure in a full run becomes a tier A case first.

### 5.5 Pass criteria for the rewrite

* Tier A: all cases pass; no plan over 2 s wall clock in `lua31.exe` (the original's interpreter on this
  machine; in the game it runs the same code with the engine's frame on top).
* Tier B: tier A's way strings and tier B's agree on ScummVM for every case; ScummVM and the original agree
  except where a case documents why (none expected after E1).
* Tier C: every case arrives on both engines; walking time within 1.5x of the better engine's; replans <= 2.
* Tier D: three ScummVM passes in a row (today 255-273 s of sim time each) with the section 0 guard in place
  (the dev builtins set to nil); the original through ch65.

---------------------------------------------------------------------------------------------------------------

## 6. Order of work

0. The section 0 cleanup: remove `AR_ORIGINAL` from `ar_lib.lua` and the chapters, delete
   `ar_routes_original.lua`, move `DumpSectors` to a dev script, add the nil guard to the assembled run. Each
   branch that was load-bearing becomes an entry in 3.9 (E4, E5 are the two known).
1. ScummVM `IsPointInSector` visibility (E1); build; one `IsActorInSector` check in Ghidra (3.9).
2. `ar_nav_data.py`: probe points per sector; the overlapping-substring-name warning. `tools/set_tables.py`:
   `ar_nav_sets.lua` from the set scripts. Regenerate the data from the existing pass logs (no game run needed:
   `logs/all_pass*.log` hold every set's dump).
3. Tier A: `tools/lua31/` host against `LUA.DLL` (check the three risks of 5.1 first); `nav_cases.lua` shared by
   all tiers; reproduce the failures of the first in-game run offline.
4. Planner: state table `S` (D1); `geo` cache (D10); goal rules and the 0.5 m cap (D2); impassable door
   sectors (D3); start cell steps (D5); one stairs model (D4); activity probe on both engines (D7/3.8).
5. Follower: hysteresis, aim cache, turning as progress, walkOut-only sentence stop, 0.2 m soft disc (F1-F4, D8);
   learned links (D6); door-from-inside (D9).
6. `test_nav.lua`: T1-T5; run tier B then C on ScummVM, then on the original; fix until 5.5 holds.
7. Tier D: one ScummVM full run (the rule); then the original from ch20 on.

---------------------------------------------------------------------------------------------------------------

## 7. Open questions that only a run can settle

* Why `links_meadow` and `links_factory_hub` have 0 links (both ends of each link must be floor at the box's
  height; the boxes may be flush against a wall so the 22 cm pre-point is off the floor: then shorten it to
  what the floor allows, as 3.3 now says).
* Whether `IsActorInSector` on the original passes the visibility flag (Ghidra, not a run).
* The exact cause of `narrow_corner_ledge` holding up at the corner (tier A will show whether the plan cuts the
  corner or the follower's aim does).
* Whether the original's constrained walk matches ScummVM's new one off the Blue Casket stairs (S5-S9 on both).
* The cost of a plan on the original's Lua for the garage (31000 cells): tier A measures it directly, since it
  runs the original's interpreter; if it is seconds, the heuristic weight or a coarser first pass (16 cm) is
  needed.
* Whether `LUA.DLL`'s `lua_dofile` accepts text and whether `lua_Initialize` must run first (5.1 risks).

---------------------------------------------------------------------------------------------------------------

## 8. Status of 2026-10-24: what was built, and what differs from the plan above

The plan above was implemented; where the build departs from it:

* **Set data comes from the set files, not from dumps.** `nav_setfile.lua` reads the `.set` file of the current set with
  `readfrom` (which opens files inside the game's LAB archives on both engines) and builds the same `nav` tables the
  planner uses (`ar_nav_of(set)`, cached in `AR_NAV[set.setFile]`). The pre-dump files (`ar_nav_data.lua`,
  `ar_nav_off.lua`, `ar_nav_static.lua`, `dump_nav.lua`) are gone (kept in `../backups/predump`). The offline host
  (`tools/lua31/host.c`) reads the LAB archives itself, so tier A needs no dump either.
* **Tier A runs in the Lua of the original game.** `tools/lua31/lua31.exe` loads the game's own `LUA.DLL`;
  `tools/lua31/run.sh` runs all cases in about a second (53 cases).
* **Teleports are learned, not listed.** `PutActorAt` is wrapped (`ar_tele_note`): a jump of Manny during a walk
  records its hot sector and landing, the follower replans from where he is, and `ar_w_links` makes links over the
  learned edges.
* **Planning is strict, then optimistic, then partial.** Strict: sectors that are on. Optimistic: off walk sectors
  counted as floor (a gate that a trigger opens). Partial (`AR_ALLOW_PARTIAL`): the closed node nearest the goal. Nodes
  carry a floor level, so winding stairs and floors over floors plan correctly; goals on a stair, doors over stairs
  (region links, `ar_w_hot_zok`) and a goal on the stair Manny stands on (projected on the line of the stair) are handled.
* **Ladders.** A sector whose object has `climbOut` is tried when there is no way to the goal's level
  (`ar_nav_try_climb`); when a scene of a sector puts Manny on a ladder during a walk, the follower holds up/down
  toward the goal's height (`ar_climb`) unless the caller's `stop_when` has already been met.
* **Moving targets.** An object whose actor rides about is approached where the actor is (`ar_approach_actor`),
  again when it has moved on; the walk goes as near as the floor does.
* **E4 (`SetImmediateTasks`) turned out to be a different bug.** The original starts a new task in the next frame as
  ScummVM does. The real difference was the turning flag: `SetActorRot` in the original leaves `IsActorTurning` true
  for the frame (costume + 0x28), fixed in `engines/grim` (`Actor::setRotPending`). The builtin is removed.
* **Search is spread over frames** (`AR_SLICE`, 300 cells per frame) so that a big plan does not stall one frame.

Tests (all with real level data, the same cases on both engines):

* tier A, offline, `sh tools/lua31/run.sh`: 53 cases;
* tier B/C in the game, `EXTRA=nav_cases.lua sh run_chapter.sh test_nav.lua 900` (ScummVM) and `test_nav_original.sh`:
  unit 51, walk 33, and 96 moving-target cases (3 objects x 4 starts x 8 routes of the actor, each with an object and
  actor of its own because the game puts the real actors back). Placement faces the goal, or heading 0, because the line a
  stair walks Manny along is made once from his heading when he steps on it.

Full runs: ScummVM passes ch01-ch65 three times in a row with the dev builtins set to nil. The original is being run from ch01.
