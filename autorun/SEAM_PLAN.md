# Plan: hold-ups of the walk (stairs, seams) must not cost the run time

State on 2026-10-31, after the measurements of the first version of this plan (which was about gaps between floor sectors; there are none, see
section 1). A hold-up is the follower standing still on a way: the way left has not shrunk for 2 s (then the stick is slanted 30 degrees,
`AR_WIGGLE`), 3 s (the cells are blocked and the way planned again), or 1 s inside a trigger sector (a step out and in; since today after the
slant, `AR_NO_WIGGLE_FIRST` for the old order). Each costs 2-3 s of game time and moves the frames of the chapter by hundreds, which is what
makes the frame count of a run jump when anything about a walk changes.

| what the speed run has (`logs/hu.log`, today, 497391 frames) | count |
|------|-------|
| hold-ups of 2 s, the slanted stick | 46 |
| of them in a stair or curb sector (`stairs`, `stair1..3`, `stairs_14/15/16/24`, `mg_stairs`) | 30 |
| against an actor or a box the scripts switch (ch21 drill and bottle, ch13 `sect_30`, ch55 `charlie_box`) | 6 |
| at a seam between floor sectors (rf, cc ×2, xb ×2, and the Hallway one that the slant now takes without a log) | 6 |
| hold-ups of 3 s, planned again | 6 |

About 6000 frames of the run, two thirds of them on stairs. The places repeat: the two stairs of the Elevator Station on the way to the cafe
in nine chapters (ch15, 17, 18, 24, 25, 31, 32, 36), the Tube Room stairs in ch02 and ch04, eight in ch13.

---------------------------------------------------------------------------------------------------------------

## 0. What the engine does (the facts the plan rests on)

* **One walker.** The keys and `manny:walkto` both end in `Actor::walkForward` (`engines/grim/actor.cpp` 1110-): the step is walked sector by
  sector; at the exit point of the sector the next one is looked for with the exact test; where there is none the actor is turned along the
  edge by (angle with the edge + 0.2) degrees, up to 3 times, only when that angle is under the reflection angle (80) and, with `exact_edges`,
  only toward a held turn key unless he runs; otherwise he stands. No gap is jumped for Grim (the 10 cm jump is EMI only).
* **The exact test** (`Sector::isPointInSector(p, true)`, FUN_004a6980): a point is in a walk sector when it is within **5 mm of the sector's
  plane** (`_gHeight` = 0.005 for walk sectors, `sector.cpp` 703) and inside the polygon with a tolerance of 2e-5 in cross-product units (well
  under a millimetre). On a stair (a sloped plane) or at a height step a point 3 cm along the floor at the *old* height is already off the
  plane: a probe that does not project onto the plane sees "no sector" where there is one.
* **The game's own walks** cross between sectors at shared corners (`Set::grimPlanPath`: `planNeighbours`, `planPortal`; `planSmooth` keeps the
  crossing on the corner) and snap the actor onto each point of the path within a step and a quarter (`updateWalkGrim`, `placeOnWaypoint`).
  The stick has neither.
* **Constrained sectors** (stairs, curbs; NAV_PLAN 1.3): `stairman` / `curbman` (`_system.lua`) call `SetActorConstrain(TRUE)` the frame Manny is
  found in a sector named `stair` / `curb`, `FALSE` when he has left them all. `Actor::setConstrain` (`actor.cpp` 2050) computes the line of the
  constraint (`grimConstraintLine`: from where he stands to the opposite edge at the fraction he came in at, clamped 0.15..0.85), **sets his yaw
  to the line**, and from then on `walkForward` moves him only along the line, either way, and **not at all when his heading is more than 80
  degrees off it**; at an edge he is turned along it whatever the angle and the line is re-derived (`actor.cpp` 1284). It does nothing during a
  scripted walk (`_walking`).
* **The follower on a stair** (`ar_follow_frame0`, `ar_nav.lua` 2279-2360): a stair is two points of the way, "s" at the entry and the exit (the
  links of `w.lk`); from the entry it aims at the exit with the stick (`ar_steer`, turn keys with an 8 degree band) and presses forward while
  the heading is within 70 degrees of the aim (`AR_IN_CONS`); off the stair past its end.

---------------------------------------------------------------------------------------------------------------

## 1. What was measured, and what the measurement got wrong

Built: `tools/seams.py` (every shared edge of the walk sectors of every set, out of the LABs: overlap, gap, height step, portals) and
`ar_dbg_holdup` (`ar_navdebug.lua`, with `NAVDEBUG=1`: after every "held up" line, what `GetPointSector` finds where Manny stands and 3 cm
ahead, ahead left, ahead right, 6 cm ahead, the shrunk boxes, the hot sector). The results above come from it. Two things in it are wrong and
are fixed first (section 2):

* the probe points are at Manny's height, so on a stair and at a height step "nil ahead" is the 5 mm plane tolerance, not a missing floor;
* "ahead" is along his yaw at the moment of the log, which after 2 s of standing and steering is not the way's direction (cc: yaw 127 logged, the
  way's direction -23). The probe has to go along the way (toward the next point) and along the yaw, both.

What stands: there is **no gap** in the set files at any of the seam places (rf `sect_25`/`$ect_33`, cc `sect_14`/`dumb_name`/`floor_29`, Hallway
`5`/`sect_43`: the shared edges coincide to the millimetre, `seams.py --all`), and the `WALK` constant of the scripts is not the engine's (with it
`GetPointSector` answers nil everywhere; without a type it answers). And the cc place is a corner where three sectors meet, two of them 5 and
8 cm wide, narrower than a cell of the planner's grid (8 cm): the way's point `p(-0.34 1.16)` is the corner itself, a centimetre into `sect_14`.

---------------------------------------------------------------------------------------------------------------

## 2. First: a hold-up explains itself (tools; a day at most)

1. **The probe on the plane and along the way.** `ar_dbg_holdup(q, tx, ty)`: the points 3 and 6 cm toward the aim of the follower (`tx, ty`,
   passed from `ar_follow_progress`) and along the yaw, each at the height of the floor there (`ar_nav_find_z` + `ar_nav_z` of the polygons; the
   engine's answer `GetPointSector` taken at that height). Plus: the sector Manny's own puck is in (`manny:find_sector_name("")`), whether the
   set has him constrained (`find_sector_name("stair")` / `("curb")`, what `stairman` looks at), the line of the constrained sector he stands in
   (`ar_w_cons_dir`) and the angle of his yaw and of the way to it.
2. **The last second before the hold-up.** The follower keeps a ring of the last 60 frames (position, yaw, `is_moving`, the keys pressed, the
   sector) and `ar_dbg_holdup` dumps it. This is what shows whether he stopped dead (the walker refused the step), crept (the slide along an
   edge), or oscillated (the steering).
3. **What the engine holds him to.** A debug opcode `GetActorConstrain(actor)` → `constrained, dir.x, dir.y, dir.z` (the `_constrained` and
   `_constrainDir` of `actor.cpp`; no script of the game asks for it, like `GetCameraFOV`), logged in the hold-up line. ScummVM change, built in
   `build-opt`, uncommitted until the user says; the hold-up line does without it where it is not there.
4. **A probe chapter for a stair**, `tests/probe_stairs.lua`: from the chapter 15 save, the two stairs of the Elevator Station (`stairs_14`,
   `stairs_15`) walked with the stick at headings 0, 10, 20 ... 80 degrees off the line, up and down, with and without a turn key held, each
   logged per frame. The table it gives (heading → moved per frame) is the engine's rule as it is, against NAV_PLAN 1.3's "0/30/60 move, 90 not".

Run the speed run once with `NAVDEBUG=1`: the 46 hold-ups with their cause. Then the fixes, by cause.

---------------------------------------------------------------------------------------------------------------

## 3. Stairs: the 30 hold-ups were not hold-ups (done 2026-10-31)

The trace of section 2 (`NAVDEBUG=1`, hold-up lines with the constraint and the last second) shows what the stairs did: Manny is **constrained to the
line of the stair, his yaw is 0-2 degrees off it, the aim is 0-2 degrees off it, and he is walking** (the last second: 0.3 m a second down the
Tube Room stairs, `is_moving` nil only because the walk is by the stick). The hold-up detector measured the way left from the point of the way
that is the *entry* of the stair, which he has passed and which stays the current point while he is on the stair (`AR_IN_CONS`): from the entry the
way left grows all the way up or down the stair, 2 s of that is a "hold-up" and the stick is slanted for the points after the stair. 30 of the
47 events were that. The walk was never stopped, so the frames are untouched: 497391 before and after the change.

The change (`ar_follow_progress`): on a stair the way left is measured from the exit (`j + 1`), `AR_STAIR_PROGRESS_OLD = TRUE` for the old
measure. Hold-up lines 47 → 13 (one of them on a stair, ch29 `stair2` at the end of a way: yaw 18 and aim 33 degrees off the line, a real one).
Speed mode passes, 497391 frames, 105 s.

The two changes planned for the stairs (aim along the line of the stair, the square approach to the foot) are **not needed**: the follower aims
along the line already and the engine takes the walk along it. They are dropped.

Corrected cost of the hold-ups: the 6000 frames of the first estimate were 47 events × 2 s of standing. Only the real ones stand. 13 are left
(section 4), at most 13 × 2 s ≈ 1500 frames of the 497391, many of them overlapping the waits of the chapters (ch21's Scrimshaw timings).

---------------------------------------------------------------------------------------------------------------

## 4. The 13 that are left, by what the trace says

The probe of section 2 (the floor under points 3 and 6 cm toward the aim and along the yaw, at the floor's height) classifies them
(`logs/hu3.log`, `NAVDEBUG=1`):

| where | count | the trace | what it is |
|-------|-------|-----------|------------|
| ch21 Scrimshaw: `bottle1`, `bottle`, `drill_box3` (x4) | 4 | the sector he is in has the next floor ahead in one probe and none in the other; the boxes are the scripts' (the drill and the bottle move) | boxes that a script switches; the sectors are there or not from frame to frame |
| ch36 cc: `dumb_name` (-0.39, 1.03) and (-0.35, 1.15) | 2 | nothing 3 cm toward the aim; `floor_29` ahead at the second | the three-sector corner with 5 and 8 cm wide sectors; the point of the way is the corner itself |
| ch34 / ch51 xb: `$ect_20`, the aim a cheat box "c" | 2 | nothing toward the aim or along the yaw | in front of a cheat box (the planner's link `c`): the box is not entered |
| ch06 rf `sect_25` holding the balloon cat | 1 | yaw 5322 (a turn that has run 15 times round), nil along the yaw, floor toward the aim | the stick turning on the spot against an edge: the turn key rule |
| ch04 Tube Room `floor_16`, boxes shrunk (an item in hand) | 1 | floor ahead | the shrunk boxes (ScummVM's shrinking) |
| ch13 `sect_30`, ch55 `charlie_box` | 2 | floor ahead, same sector | an actor that collides |
| ch29 `stair2` | 1 | constrained, yaw 18 and aim 33 degrees off the line | the end of a stair, the way turns at the exit |

None of them is a gap: the sectors are there toward the aim in all but the xb ones. Fixes, each by itself and measured on its own chapter first:

* **cc corner (ch36)**: the way's point is the corner of three sectors, narrower than a cell. A point of the way that is `part` of its cell is
  moved onto the floor of the sector it is in (`ar_w_geo` has it) before the straightening; and `ar_w_los` may not pass within a cell of a vertex
  where three or more sectors meet unless it goes through it.
* **xb cheat box (ch34, ch51)**: what the follower does at the foot of a cheat box: the point "c" is the step into the box and the aim is "as far
  again" past it (`ar_follow_frame0`); he stands at (39.67, -13.53) with the box 3 cm ahead nil. The probe at the box's edge says whether the box
  is entered square; the hold-up is 8 s into a walk of 0.47 m, so the approach to the box is the thing to look at.
* **rf turn (ch06)**: a yaw of 5322 means the turn keys were held for 15 turns: `ar_steer` against an edge that the walker will not turn him
  along (`exact_edges`: only toward a held key). The follower releases the turn key when the walker has refused a step for 0.3 s.
* **Scrimshaw (ch21)**: boxes the scripts switch; wait for them (`ar_wait_for` the sector to come on) rather than slant: a rule "the sector
  ahead is off at the planner's last look, on now: plan again" exists (the second try of the planner); the 2 s is the cost of finding out.
* **The rest (actors, shrunk boxes, the stair end)**: no change; they are the follower's rules doing what they are for.

---------------------------------------------------------------------------------------------------------------

## 5. Tests and measures

* **Without the game** (`synth/`): a `stairs.set` with a sloped constrained sector 12 cm wide between two floors, the synthetic Manny of
  `test_follow.lua` given the engine's rule (moves along the line only, not at all when more than 80 degrees off it, yaw set to the line on
  entry); checks: the way approaches the foot along the line, the follower is up within N frames, from both ends. A `corner.set` with three
  sectors meeting at a vertex, two of them 5 cm wide: the way's points lie in a sector, the straightening keeps the vertex. The checks fail on
  the committed `ar_nav.lua`.
* **In the engine**: `NAVDEBUG=1` on ch15, ch02, ch13 (stairs), ch36, ch34, ch06 (seams), each with the hold-up lines counted. The whole
  speed run: `RESULT PASSED`, hold-ups 47 → 13 now, to under 8 after section 4, "frames:" against 497391 (today) and 495150 (committed); the run should get shorter.
  `MODE=full` once. The NAVCASE lines of walks without a stair or a seam unchanged (`diff`, addresses normalised).
* **For the user to watch**: `NAVDEBUG=1 REALTIME=1 sh run_chapter.sh ch15_letters_book.lua` (the two stairs of the Elevator Station).

---------------------------------------------------------------------------------------------------------------

## 6. Order of work

1. Section 2.1-2.2 (the probe on the plane and along the way, the ring of the last 60 frames): two hours. 2.4 the stair probe chapter: two
   hours. One speed run with `NAVDEBUG=1`: the table of causes. 2.3 (the engine opcode) only if 2.1-2.4 leave the stairs unexplained.
2. Section 3: the aim along the line and the square approach to the foot: half a day; then whichever the trace named.
3. Section 4 by kind, each measured first: half a day to a day.
4. Section 5: the synth sets, the whole run, frames compared.

## 7. Open questions

* The 2 s before the slanted stick fixes the frame of every hold-up that remains; it is not changed in this work (the comparisons with the
  original, NAV_PLAN 0). Whether to shorten it afterwards is a decision of its own, with the frame count before and after.
* The hold-ups against actors (6): the planner learns an actor that collides and goes round it after 3 s (`ar_w_obst_learn`); a hold-up of 2 s
  against one is the slant trying first. Whether an actor's box should be known before the walk (the actors of a set are listed, TESTS.md) is a
  separate item.
