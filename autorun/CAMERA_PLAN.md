# Plan: a navigation never goes back to a camera setup

> **Not adopted (2026-10-31).** The rule was implemented (sections 1-5) and passed the speed run and `MODE=full`, but it did not help: the frames grew
> (502746 against 495150) and the paths changed in many walks for little. The check, the planner changes, the follower change, the ch64 exception and the
> synth camera tests were taken out again. Kept: `NAVDEBUG` (`ar_navdebug.lua`), `AR_CAMDBG`, `frames: N`, the camera polygons read by `nav_setfile.lua`,
> `REALTIME=1` for `run_chapter.sh`, the smaller status font, and the ScummVM `GetCameraFOV` / `GetCameraRoll`. The findings in sections 1 and 5 stand
> (the engine's camera is `GetPointSector` with `CAMERA`, the polygons agree with it; cheat-box links cost a flat 0.4 whatever they jump over).

State on 2026-10-31. The rule asked for: during one navigation (an `ar_go` or an `ar_walk_to`) the camera never returns to a setup it has already
shown during that navigation. A walk that steps into the sector of another view and straight back out is backtracking, and an error of the run.
The cutscenes' and dialogs' own cuts are not the walk's and are not looked at.

What is in the working tree today (uncommitted):

| piece | file | state |
|-------|------|-------|
| the check | `ar_lib.lua` (`ar_nav_begin`, the `system.camChangeHandler` hook, `AR_WALKING`, `AR_NAV_SEEN`) | works; speed run passes chapters 1-40 with it |
| the planner's camera penalty | `ar_nav.lua` (`AR_CAM_OK`, `ar_w_cambad`, `ar_nav_cams_at`, ×4 in `ar_w_step_cost`, refused in `ar_w_los`) | wrong: makes the Garage walk of ch06 fail (below) |
| camera sectors read from the set file in every mode | `nav_setfile.lua` (`nav.cn`, `nav.cp`) | works, needed by both |
| the re-enter step of the follower goes sideways, not back along the path | `ar_nav.lua` (`ar_follow_reenter`) | works (Hallway of ch01) |
| a cutscene in the middle of a walk resets what was seen | `ar_lib.lua` (hook), `ar_nav.lua` ("planning again after a cutscene") | works (Tube Room ch04, shuttle security ch21) |
| a waypoint round the narrow close-up sector of the foremans office | `ch41_chisel.lua` | works; should become unnecessary |
| the overlay `NAVDEBUG=1` | `ar_navdebug.lua`, `mode.sh`, `run_all.sh`, `run_chapter.sh` | works; logs the cameras along a path, the raw way of the search |
| `GetCameraFOV`, `GetCameraRoll` | ScummVM `engines/grim/lua_v1*.cpp` (were stubs) | built in `build-opt`, uncommitted |
| `frames: N` at the end of a run | `ar_lib.lua` (`ar_finish`) | works; speed run is 495150 frames on the committed code |
| `REALTIME=1` for `run_chapter.sh` | `run_chapter.sh` | works |

Facts established by running:

* The engine picks the camera with `GetPointSector(x, y, z, CAMERA)`: the first camera sector, in the set's order, that is on and holds the point. The
  polygon test of `ar_nav_cams_at` (set-file order, `ar_nav_inside`) gave the same sector as the engine in 513 of 513 samples along planned paths
  (chapters 1-6). Overlapping camera sectors were not among them: to be confirmed where two are on at one point.
* Failing the run from inside `camChangeHandler` (the engine's callback) hangs the engine. The hook only notes the failure (`AR_NAV_FAIL`); the walk
  reports it at its next `ar_note_camera`.
* Sectors of the same setup have different names (`ga_entha2` and `ga_entha` are both setup 1 of the Garage; `fo_berws`..`fo_berws4` are setup 0 of
  the foremans office). The rule is about setups, not sectors.

---------------------------------------------------------------------------------------------------------------

## 1. Why the penalty in the tree fails: the Garage walk of chapter 6

`ar_go(ga.gs_door, gs)` from (17.72, 5.57) to (0.84, 10.00). The raw way of the search (`NAVDEBUG`, `ar_dbg_raw`):

```
cell 12.93 6.89   G 5.66   ok            ga_entha2, setup 1
LINK c 12.49,7.03 -> 13.23,8.26  cost 0.4       jumps into ga_wshms, setup 2
cell 13.01 8.57   G 8.46   BAD
LINK c 12.57,8.97 -> 11.15,8.23  cost 0.4       jumps out into ga_entha, setup 1 again
cell 10.85 8.25 .. 3.48 8.09     BAD           ga_entha (1), ga_rckha (3), ga_rckws2 (5)
LINK c 9.27,8.53 -> 6.12,8.49    cost 0.4
LINK c 5.33,8.29 -> 4.13,8.07    cost 0.4
cell 2.68 8.73 ..                ok            ga_ofcha, setup 7, the goal
```

Three faults, each of them enough:

1. **Bad by sector name.** `AR_CAM_OK` holds the names of the start's and the goal's camera sectors. `ga_entha` is the same view as the start's
   `ga_entha2` but another name, so the straight way pays the penalty from x = 11.9 on, as the detour does. Both ways pay for about the same length
   (372 of 613 samples against 269 of 480): there is nothing to choose, and a ×50 penalty changes nothing.
2. **Links pay nothing.** A cheat-box link costs a flat 0.4 whatever it jumps over (here 1.4 and 1.6 m) and gets no penalty: the two links at
   x = 12.5 are the cheapest metres of the set, and they are what takes the way through setup 2.
3. **The straightening pass refuses bad cells.** The committed planner found the same raw way and `ar_w_los` pulled it straight into the 11-point
   line that never enters setup 2. With bad cells refused in `ar_w_los` the detour stays as it is. (The refusal is right once "bad" is right.)

---------------------------------------------------------------------------------------------------------------

## 2. The design

### 2.1 The camera of a cell, by setup

* `ar_nav_cam_setup(nav, x, y)`: the setup number of the first camera sector that is on and holds the point, by the polygons (`nav.cn`, `nav.cp`,
  `system.currentSet.setups[name]`), nil where none. Cached per cell in `w.cams[k]` (the camera sectors that are on do not change during one plan;
  the cache is dropped with `w.tmp` at the start of each `ar_nav_go`). This replaces `ar_nav_cams_at` + `ar_w_cambad` by name.
* The order of the sectors: the set file's, as today. Where two camera sectors that are on overlap, the engine's choice is checked against it with
  the overlay's report (`ar_dbg_report` logs every disagreement); if they differ, the order is taken from the engine's `getSearchSector` order
  (the last loaded first) instead.

### 2.2 What a walk may be in: `AR_CAM_OK` by setup

* At the start of a plan: the setup of the start cell and the setup of the goal cell are allowed; in a replan after a repeat (2.4) the setups the
  way had to cross are added. Everything else is "bad".
* A cell is bad when its setup is not allowed and not nil. A cell with no camera sector is never bad (the camera stays where it was).

### 2.3 Costs

* Floor cells: `d * (1 + pen^2 * 0.6) * held * (bad and AR_CAM_PEN or 1)`, `AR_CAM_PEN` 4 as today (a penalty, not a wall: a corridor through one
  view has to stay possible).
* Links: the link's cost gets the penalty of its landing cell and of the cells it crosses, sampled every cell along the jump (`ar_w_add_link` keeps
  `px, py` and `lx, ly`): a cheat box that jumps into another view costs what walking there would. The stair links the same.
* `ar_w_los` refuses a line through a bad cell, as today: the straightening may not bring in a view the raw way did not have. It may cut through cells
  whose setup the raw way already passes (they are allowed, 2.2).

### 2.4 The check of the plan, and the replan

* After `ar_w_way`: sample the way every 10 cm (as `ar_dbg_report` does), take the run of setups, drop the nils and the repeats of the same setup in
  a row. If a setup occurs twice in the run, the way goes back to a view.
* Then: every setup strictly between the two occurrences is added to a forbidden set (`AR_CAM_FORBID`, cost ×25 like a door's sector: a wall for all
  practical purposes, not infinite, so that a set that forces it still gets a way) and the search runs again. Up to 3 times. The result of the last
  try is taken whatever its run is; the run is logged (`nav: the way shows setups 1 2 1 3, no way round`) so that the failure the check then raises
  is explained.
* The cost of a search is logged already (`cells searched`, frames). The replan is rare (only where the first plan repeats a setup); its cost is
  the one to watch in the speed run's frame count.

### 2.5 The follower

* `ar_follow_reenter` (done): the step out of a trigger sector goes 30-60 cm sideways onto plain floor off every hot sector, not back along the path.
  Add: the spot's setup must be the one Manny stands in (`ar_nav_cam_setup`), so the step does not change the view.
* The wiggle (`AR_WIGGLE`, 30 degrees to one side) and the held-up learning (`ar_w_obst_learn`) do not move Manny far; no change. A replan after
  "Manny was moved by the game" starts a new plan, whose `AR_CAM_OK` is the current setup and the goal: right, since the game's move is not the
  walk's.
* A cutscene in the middle of a walk resets what was seen (done).

### 2.6 The check in `ar_lib.lua` (done, two refinements)

* `AR_NAV_SEEN` is a set of setups seen in this navigation in the set it began in. Same-frame changes (a skipped cutscene's own cuts) are not
  counted (`cutSceneLevel > 0` resets). Keep.
* The failure is reported by the walk, not the callback (the engine hangs otherwise). Keep; add the `ar_note_camera` call to `ar_nav_go`'s loop
  so the report comes within the walk, not at its end.
* `AR_NO_FLIP_CHECK = TRUE` around a step: for a chapter where the game itself forces a repeat (none known yet; the Albinizod tunnel's close-up
  was a cutscene's cut, not a walk's).

### 2.7 Clean-up

* Remove the by-name code (`ar_nav_cams_at` by name, `AR_CAM_ON` as a name set), the `AR_HW` override and the camera dump in `ar_nav_go` (or
  keep the dump under `AR_NAVDEBUG`).
* Remove the waypoint in `ch41_chisel.lua` once the planner keeps out of `fo_bercu2` by itself; the run is the test.
* Commit the ScummVM opcodes (`GRIM: implement GetCameraFOV and GetCameraRoll`, `Assisted-by:` trailer) when the user says so; the overlay needs them.

---------------------------------------------------------------------------------------------------------------

## 3. Tests

### 3.1 Without the game (`sh synth/run.sh`)

* Camera sectors in the synthetic sets: `nav_setfile.lua` reads `type camera` now; `defset` in `synth/run.lua` gets a `setups` table
  (`{ cam_a = 0, cam_b = 1, cam_c = 2 }`) so `system.currentSet.setups[name]` resolves.
* `camera.set`: a room with three camera sectors A | B | A' (A and A' the same setup) where the straight line from a point in A to a point in A'
  clips a corner of B. Check: the way's setup run is `0` only (no B). Same room, goal inside B: run is `0 1`. A corridor room where B is the only
  way: run `0 1 2`, one pass through B.
* `camera_link.set`: a cheat box whose jump lands in B, with a floor way round: the way does not take the link. (Needs `cheat` in `defset`; the
  synth harness has it.)
* Regression: `git show HEAD:autorun/ar_nav.lua > /tmp/old.lua; AR_NAV_FILE=/tmp/old.lua sh synth/run.sh` must fail the new checks (the committed
  planner knows nothing of cameras; its line through A B A' is the straight one).

### 3.2 In the engine, speed mode

* Chapters from their saves with `run_chapter.sh` (quick): ch01 (Hallway), ch04 (Tube Room), ch06 (Garage, must take the 11-point way again),
  ch21 (shuttle security), ch41 (foremans office, without its waypoint), ch55 (le mans lobby, open today), ch64 (meadow exterior, open today).
  Each with `NAVDEBUG=1`: the `path cameras` line shows the setup run of every plan.
* The whole run: `LOG=cam sh run_all.sh`, `RESULT PASSED`, no `FAIL the camera of`, and the `frames:` line against 495150 of the committed code.
  The frames a detour costs are the price of the rule and are reported, not hidden; a growth of the search (`cells searched`) is not acceptable
  beyond a few percent of wall time (109 s today).
* Then `MODE=full` (voices on, simulated time) once; it passed before the planner change.

### 3.3 Order of work

1. 2.1 + 2.2 (setup, not name) and 2.3 (links pay). Run ch06: the Garage must pass with the 11-point way. Half an hour.
2. 3.1 synth sets and checks, failing on the old code. An hour.
3. 2.4 the replan on a repeat. Run ch55 and ch64. An hour.
4. 2.5 the reenter spot's setup; remove the ch41 waypoint; 2.7 clean-up. Half an hour.
5. 3.2 the whole speed run, frames compared; `MODE=full`; the real-time ch06 for the user to watch with `NAVDEBUG=1 REALTIME=1`.

---------------------------------------------------------------------------------------------------------------

## 4. Open questions

* A set where every way to the goal must return to a view (a loop round a pillar seen from one camera, say): error of the run, or a logged exception
  per step (`AR_NO_FLIP_CHECK`)? The plan makes it an error until one is found.
* The overlay draws text objects, which are part of a save and cost a bitmap each: a frame of the overlay is cheap now that only the changed marks
  are redrawn, but an engine-side debug draw (lines and points in the 3D pass, correct depth, nothing in the game's state) would be the right tool
  if the overlay is to stay. Not in this plan.

---------------------------------------------------------------------------------------------------------------

## 5. State after the implementation (2026-10-31)

Built as in section 2, with these differences found by running it:

* **First plan without cameras.** Penalising every view in every plan changed the paths of most walks and the frames with them (a puzzle that waits for
  a timer, ch12 and ch42, swings by thousands of frames on any change of arrival time). The first plan is the planner's own. Only a way that shows a setup
  twice, or that skims along the edge of a view, is planned again, with the cameras (`ar_w_plan`). 89 of about 490 plans are planned again; 16 end with
  "no way round".
* **What counts as a repeat** (`ar_nav_way_repeat`): the polygons (not the cells of the grid: the sliver `fo_bercu2` is narrower than a cell) sampled every
  5 cm along the way, a setup counting only if it holds 3 samples (15 cm) in a row. The first run is the setup the camera is in now.
* **What counts as skimming** (`ar_nav_way_skim`): the length of the way within two cells (16 cm) of an edge between two views (a setup, or none, not between
  two sectors of one setup), less 35 cm for each crossing; over 40 cm is skimming. Le Mans lobby: the way ran along the lower edge of `ly_lavha` at 15 degrees
  and Manny stepped out and in four times. Not looked at for a way into the sector of a door (`AR_GOAL_REGION`): the door is left there.
* **Costs** (`ar_w_cambad`): the views of the start and the goal are free, another view ×`AR_CAM_PEN` (4), a view the way crossed to come back ×25, the cells
  by an edge ×`AR_CAM_EDGE` (3). A link costs what its jump crosses (`ar_w_link_cam`). `ar_w_los` refuses a line through such a cell.
* **The re-enter step of the follower** (`ar_follow_reenter`) goes back along the way as before, and sideways only where the way back crosses into another
  view (the Hallway of ch01: +172 frames against the old step back).
* **A walk that begins where no camera sector holds Manny** (`AR_NAV_NOCAM`): the first change of the camera is the view settling to that of the place, not
  the walk's (the meadow of ch62 in `MODE=full`).
* **Exception**: ch64 walks the meadow corridor past `me_shtgh` (setup 2 between two sectors of setup 5), which has no way round: `AR_NO_FLIP_CHECK` around
  the walk. The waypoint of ch41 is gone: the planner keeps out of `fo_bercu2` by itself.
* Failing from the camera callback hangs the engine: the hook sets `AR_NAV_FAIL`, `ar_note_camera` reports it.

Results:

| run | before (committed) | now |
|-----|--------------------|-----|
| speed, `RESULT` | PASSED | PASSED, `frames: 502746` both times (committed code: 495150, +1.5%), 111 s (committed: 106-111 s) |
| `MODE=full` | PASSED | PASSED, 831294 frames |
| `sh synth/run.sh` | 21 | 27 passed (`test_camera.lua`: a patch of another view is gone round; no way round: a way through; the planner without cameras crosses it) |

The frames grow by walking round a view and by the puzzles that wait: against the committed code ch02 +300, ch06 +250, ch18 +465, ch34 +620, ch64 +1500 and
ch42 +1800 (a loop that uses the ashtray until Meche flicks her ash) and ch12 swing ±4000 with any change of the arrival time, as they did with the first
changes of this work that had nothing to do with the planner (the follower's step out of a trigger: ch12 +2385). The frame count is the measure of the
cost of the rule; what the speed run needs to beat is 495150.

Tools added on the way: `NAVDEBUG=1` (`ar_navdebug.lua`: the path, the camera sectors and Manny on the screen; the cameras along every plan asked of the engine
with `GetPointSector`; the raw way of the search), `REALTIME=1` for `run_chapter.sh`, `AR_CAMDBG = TRUE` (every change of the camera with Manny's place),
`AR_NO_CAMAVOID = TRUE` (the planner without the cameras), `frames: N` at the end of a run. ScummVM: `GetCameraFOV` and `GetCameraRoll` implemented
(`lua_v1_set.cpp`), uncommitted.
