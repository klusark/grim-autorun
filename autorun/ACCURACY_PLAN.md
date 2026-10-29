# Plan: proving that ScummVM plays Grim Fandango as the original does

State on 2026-10-25, night. What exists today proves that one scripted route through the whole game ends the same way on both
engines, and that the walker (planning, walking, turning, box collision) ends within centimetres of the original on about 700
placed cases. It does not yet say anything about animation, sound, text timing, rendering, saving, or the Lua interpreter, and
"ends in the same place" is not "did the same thing every frame". This plan says what accurate means, what is proven now and how,
where the holes are, and how the proof is made so that it can be shown, repeated and kept.

---------------------------------------------------------------------------------------------------------------

## 1. What "accurate" means here

The original exe (v1.01, with ScummVM's Lua patches in DATA006.LAB) is the oracle. ScummVM is accurate when, for the same game
data, the same script, the same inputs at the same frames and the same frame time, every observable thing is the same:

| Quantity | Same means | Why not exact |
| --- | --- | --- |
| pure math (sin tables, asin, turn frame, normalize) | bit for bit | nothing: the tables are the original's |
| positions, yaws after N frames | within 1 cm / 0.5 degree, and the same first frame of contact with an edge or an actor | float order and 80-bit intermediates in the original |
| which sector, which setup, which set | identical | |
| chores: which chore is playing, its frame, its loop state | identical in the same game frame | |
| sounds, music states, movies, saylines: start and end frames | within 1 frame | the mixer and the clock step |
| text shown and its position | identical | |
| frames drawn | pixel difference under a threshold, with the renderer's known differences listed | software renderer vs software renderer, same size |
| save files | a load continues identically to the uninterrupted run (determinism), both engines | formats differ by design |

Every tolerance is written next to the test that uses it, with the reason. A difference that is accepted goes into a "known" list
with its reason and the function of the original it comes from (`nav_known.lua`, `rules_known.lua`); the list is part of the proof,
and shrinking it is the work.

## 2. What is proven today, and how (the evidence)

| Area | Test | Oracle recording | Result 2026-10-25 |
| --- | --- | --- | --- |
| sin/cos/asin tables, turn frame, normalize | `tools/origmath/check.sh` (C++ ports vs values read from the exe's tables) | `*_original.txt` | bit exact |
| planner + walker on real sets | `test_nav.lua` unit 58, walk 42 | the original's own PASS/FAIL | 2 differ (`bs_stair_down`, `ledge_window`) |
| moving targets | move 96 | | 0 differ |
| box/sphere collision, 81 starts x steered/static, per-frame traces | coll 162, `compare_trace.py SYM=1` | `nav_coll_expect.lua`, traces | 0 differ beyond the chaotic head-on slide (listed) |
| SetActorRot semantics | turn 3 | | `walker_close` differs (listed, unexplained) |
| edge slides on the temple stairs | slide 6 | `nav_slide_expect.lua` | 2 differ |
| engine rules on hand-made geometry | `test_rules.lua` 273 | `rules_expect.lua` | 120 differ (listed: edge order/tolerance, slides) |
| state isolation of the tests | leak 637 | | clean |
| the whole story, one route | `run_all.sh` (ScummVM, 3 passes in a row), `orig_all.sh` (original) | each engine's own PASS | both pass; the original needs retries at 4 chapters and skips 3 (23, 47b, 50) |
| frames at the same script points | `FRAMES=0`, `framecap.py`, `framediff.py` | frames/orig | pipeline works; not yet run over a clean full original run |
| code reached | `build-cov`, `covreport.py` | | 65.6% of engines/grim; gfx_opengl, font, resource, lua_v1, set are the low files |

What this does **not** cover: everything under "3".

## 3. The holes

1. **Frame-by-frame equality of the story run.** The playthrough compares end states of steps, not the frames between: Manny can
   take a different path, a chore can run twice, a sound can start a second late and the step still passes.
2. **The turn rate.** The turn tier only prints it: today's logs say 2.257 degrees a frame on the original and 1.417 on ScummVM, in
   the state of a new game (an earlier measurement from the slot-19 save gave 2.33 vs 2.335). Measured, not explained: the first
   thing to assert and chase (section 6.1).
3. **Animation.** Nothing compares chores: which plays, at which frame, how long, the blend at the end, `is_choring`, `is_resting`,
   the walk chore's frame against the distance walked (foot slide), the idle chores (`random`).
4. **Timing.** `sleep_for`, `wait_for_message`, `break_here` counts, the order the tasks run in a frame (`runtasks`), the frame time
   itself (the original's `system.frameTime` is 16/17 ms in a pattern; ScummVM's sim clock is 16.67 ms: whole-ms rounding changes
   turn steps and distances).
5. **Sound and music.** `ImStartSound`, `ImStopSound`, `ImSetState`, `ImSetParam`, `ImFadeParam`, `ImSetSequence`, music states
   per set: no comparison of when they happen or of what the iMuse state machine does with them.
6. **Text and speech.** The sayline duration without voices (the formula from the text length), with voices (the sound's length),
   lip sync, text positions, line breaking, the fonts.
7. **Movies.** Start/end frames, frame counts, what happens to actors and scripts while a movie plays (the original does not update
   actors: found once, not tested).
8. **Rendering.** Nothing is compared pixel-wise yet. ZBuffer against bitmaps, sprite sorting, object states (layers), lighting,
   shadows, text rendering, the overlays of the menus.
9. **The Lua interpreter.** ScummVM's Lua is a modified 3.1: `format`, `strfind` patterns, `tonumber`, number printing, the order
   of `next`, `gsub`, `sort`, integer/float behaviour. A difference here changes every script's behaviour quietly.
10. **Builtins as functions.** 244 registered builtins; for most there is no test that the return value for a given input is the
    original's (`GetActorYawToPoint`, `GetAngleBetweenVectors`, `IsPointInSector` order, `GetActorNodeLocation`, `GetActorChores`,
    `GetTextObjectDimensions`, `ImGetParam`, ...).
11. **Saves.** No determinism test: save at a step, load, continue, compare the trace to the uninterrupted run.
12. **Inputs.** Key press/release semantics (the backward walk needs the release; `GetControlState` polling for driving), key repeat,
    the mouse (menus).
13. **Other routes.** One route through the puzzles, one set of dialog choices, Manny walking (not running) most of the time; the
    cases of `nav_cases_run.lua` (the walks of a run) are not in the default suite.
14. **Breadth of code.** 35% of engines/grim never runs under any of this.

## 4. The method: one trace, two engines, one comparator

Everything below uses the same shape, which the collision work already proved out:

1. **A common trace from the Lua side.** The autorun library wraps the builtins that matter (`SetActorChore`, `PlayActorChore`,
   `StopActorChore`, `ImStartSound`, `ImStopSound`, `ImSetState`, `ImSetParam`, `StartFullscreenMovie`, `StartMovie`, `SayLine`,
   `ShutUpActor`, `MakeCurrentSetup`, `MakeSectorActive`, `PutActorAt`, `PutActorInSet`, `SetActorRot`, `SetActorConstrain`,
   `Save`, `Load`) and logs `EV <frame> <name> <args>`; a per-frame task logs `FR <frame> <set> <setup> <x> <y> <z> <yaw>
   <sector> <chore state>` for Manny and, when asked, for every actor in the set. Same script on both engines, so the trace is the
   same text; the frame counter is the autorun's own (counted in a `break_here` loop), not the engine's.
2. **An engine-side trace for what Lua cannot see**: ScummVM through a debug channel (`--debugflags=trace`: chore frame numbers,
   the mixer's starts, the setup's draw list); the original through `grimtrace.exe` breakpoints on the functions Ghidra named
   (chore update, `ImStartSound`'s C side, the blitter) writing to `grimdebug.log` with the same frame counter (read from a Lua
   global by address, or logged by the Lua wrapper in the same frame).
3. **A comparator** (`tools/compare_events.py`): aligns the two traces on the script's own marks (`=== chapter`, `PASS step`), then
   reports per chapter the first frame where any quantity differs beyond its tolerance, what differed, and the two values. Positions
   use the SYM rule where the head-on slide applies. Output: one table per run, kept as `logs/accuracy_<date>.md`.
4. **Determinism first, then equality.** Each engine is run twice; a trace that differs from itself is a flake to fix before the
   two engines are compared. (`run_repeat.sh` does this for the end states; it has to do it for the traces.)
5. **Known-difference lists** with a reason and the original's function for each entry, machine-readable, counted apart from
   failures (the pattern of `nav_known.lua`). An entry without a reason is not allowed.

## 5. Making the two engines comparable (the preconditions)

1. **The same clock on both engines.** ScummVM's `--sim-fps` steps a fixed time per frame; the original measures the wall clock
   (`FUN_004a3c10`: `timeGetTime() - last`, capped at 300 ms), so its frame times are 16/17 ms with jitter and long frames at loads,
   and a trace indexed by frame drifts within seconds. The fix is in the original: its per-frame update `FUN_00482990(draw, fixedMs)`
   already has a fixed-step path (`FUN_004a3c80(fixedMs)`) chosen by the one-shot global `DAT_004f5a48` that the frame function
   `FUN_004016a0` passes and zeroes each frame. `tools/patch_simtime.py`: the 5 bytes at `0x401721` (`mov eax,[0x4f5a48]`) become
   `mov eax,17`; every frame is then a 17 ms frame whatever the wall clock, as in ScummVM (`--sim-fps` set to the same whole-ms step;
   a 16/17 pattern is possible later by letting the `grimdlg.dll` hook write the next value). With the limiter off the original runs
   at about 850 fps with the same game logic: the suite in two minutes instead of 25.
   What stays on real time: the SMUSH player paces itself with `timeGetTime` (`FUN_004891b0/2a0`) and iMuse runs on the audio
   clock. Two modes therefore: (a) fixed step, full speed, text only, movies skipped (the nav, rules, animation tiers and the
   frame-by-frame trace of the story); (b) fixed step held to 60 fps by the limiter, voices on (sound, speech and movie timing: the
   logic trace still aligns frame for frame, only the sound lengths come from real time, on both engines).
   Fallback if the patch misbehaves somewhere: the trace records the original's `frameTime` per frame and ScummVM replays that
   sequence (`--sim-frame-times=<file>`); each original run is then a complete oracle with its timing, and ScummVM has to match it
   exactly, while the original is compared with itself by game time, not by frame.
   Tests: `turn_rate` and `flat_dir_*` equal to 4 decimals; `system.frameTime` logged every frame on both is the same constant;
   a 1000-frame walk ends at the same point.
2. **Randomness.** The scripts call `random()` for idles, pigeons, the roulette. For the comparison runs, the autorun replaces
   `random` and `randomseed` with the same LCG on both engines (Lua-side, so the engine's `rand` is never asked). Any engine-side
   randomness found (ScummVM C++ `getRandomNumber` in the Grim engine, the original's `rand` calls outside Lua) is listed.
3. **Inputs.** The autorun gives keys; it must give them at the same frame counter on both engines (it does: same script, same
   `break_here` loops), and the real-time waits (`ar_wait_for` with ms) become frame counts (`ar_fr`) everywhere.
4. **The voice/text mode.** Two comparison modes, both run: text only (fast, deterministic durations) and voices on (the sound
   lengths rule the durations; the original's and ScummVM's decoders must give the same lengths: a test of its own, 6.6).
5. **Data pinning.** `tools/pin_data.py` writes the md5 of every LAB, the exe, DATA006.LAB and DATAUSR.LAB into the report; a
   recording made with other data is not an oracle.

## 6. The work, by area, each with its test and its oracle recording

### 6.1 The walker, to the end (2 days)
* The turn rate: done (see hole 2).
* The edge rules on `t_edge` (120 known): port `Set::findPointSector` order (last containing sector) and the 1e-5 tolerance of
  FUN_004a6980, then the sector walk of FUN_004a8610 against `edge_cross_*`, `flat_wall_*_k*`; each fix must keep `test_nav.lua`
  and the playthrough green (that is what stopped the first port; the rules tier now isolates each rule).
* `walker_close`: done: it was the wall clock's frame jitter; passes on both at 17 ms.
* `bs_stair_down`, `ledge_window`: the stair constraint line (FUN_004a8500 `GetActorYawToPoint`, reverted once) on `t_stair`.

### 6.2 Animation (3 days)
* A chore trace: per frame, for Manny, `GetActorChores`/`IsActorChoring` of the walk, run, idle, talk chores, and the frame of
  the chore (engine-side: ScummVM `Chore::_currTime`, the original's chore struct at the actor's costume, by breakpoint).
* Cases on `t_flat`: walk 60 frames (the walk chore's frames vs distance, both engines), stop (the blend-out), run, turn in place
  (the turn chores), `play_chore` once, `play_chore_looping`, `stop_chore`, `set_chore` at a frame, `fade_in/out_chore`, two
  chores on one costume (priority), a costume pushed and popped, `set_time_scale`. Expected values recorded from the original.
* The idle: with the LCG in place, the idle choice sequence over 2 minutes standing still.
* Head look (`Head_Control`): the head node's yaw/pitch per frame toward an object (`GetActorNodeLocation`), on `t_flat` with a
  test object.

### 6.3 Timing and scheduling (2 days)
* `sleep_for(n)` for n in 0..100 ms vs frames slept; `break_here` per frame; the order in which 5 tasks started in one frame run
  (a trace of their first lines); `wait_for_message`, `wait_for_actor`, `wait_for_sound`; `start_script` in the same frame runs in
  that frame or the next (E4, measured once, not a test).
* The frame time pattern (5.1) as a test.

### 6.4 Sound and music (3 days)
* The event trace of all `Im*` calls over the whole playthrough, both engines (text-only mode): the comparator's first difference
  per chapter.
* `ImGetParam(IM_SOUND_PLAY_COUNT, ...)`, `IM_SOUND_VOL`, `IM_SOUND_PAN` after `ImStartSound`/`ImFadeParam`/`ImSetParam` for a
  set of sounds, read back every frame for 3 s: the fade curves of the original vs ScummVM.
* Music states: `ImSetState`/`ImSetSequence` per set entry, and the engine's hooks (ScummVM `Imuse::_curMusicState`, the
  original's state variable by address) per frame over the playthrough.
* Sound lengths (6.6 feeds this).

### 6.5 Text and speech (2 days)
* Sayline durations in text-only mode for 50 lines of different lengths (frames from `SayLine` to `IsMessageGoing` false), with
  `talkspeed` as the original has it.
* With voices: the same lines, the durations equal to the sound lengths; lip sync: the mouth chore frame per frame for 3 lines.
* `GetTextObjectDimensions`, `MakeTextObject` positions, line breaks for 20 strings at 3 widths; the fonts' glyph widths (engine
  side: `Font::getCharWidth` vs the LAF data the original reads).

### 6.6 Movies and decoders (1 day)
* For every SMUSH movie the playthrough plays: frame count and length (engine side, both), start/end frames in the trace, and
  that actors are frozen while a fullscreen movie plays (a position trace of a walking actor across a movie start).
* Every voice/sound file's decoded length (ScummVM: a dev builtin that returns it; the original: `ImGetParam` play count over
  time or the iMuse sound header).

### 6.7 Rendering (3 days)
* Frames at every PASS step of the playthrough, both engines, 640x480, ScummVM's **software** renderer (the original runs `-w`,
  software): `framediff.py` per step with a percentage of pixels differing by more than 8/255 per channel; the first steps with
  the largest differences are looked at by hand and each cause becomes a known entry (dithering, z-fighting of a layer, text
  antialias) or a fix.
* On `t_flat`: one actor, one light, a text object, an object state bitmap: the smallest frames that show each renderer feature.
* Z ordering: `ObjectState` layers and the zbuffer against Manny walking behind a layer in `mo`/`ha` (frames at 10 positions).

### 6.8 The Lua interpreter and the builtins (2 days)
* `tests/lua_conformance.lua`: `format` with %d/%f/%g/%s/%c widths, `tonumber` edge cases, number to string (`tostring(0.1)`,
  big numbers), `strfind` patterns the scripts use, `gsub`, `strsub` negatives, `sort` stability, `next` order on a table built in
  a fixed way, integer division and `mod`, `type`, `rawget`, tag methods used by the scripts, `dostring`, `call` with error. One
  file, both engines, outputs diffed line for line. The original's Lua is the oracle; ScummVM's modified 3.1 the subject.
* Builtins as functions: for 40 builtins with no side effects (`GetAngleBetweenVectors`, `GetActorYawToPoint`, `IsPointInSector`,
  `GetPointSector`?, `GetActorPos`/`GetActorRot` round trips, `GetActorNodeLocation`, `GetTextObjectDimensions`, `GetSectorOppositeEdge`,
  `GetActorWalkRate`, `ImGetParam`, `GetCameraPosition`...) a generated input set and the original's outputs recorded
  (`builtins_expect.lua`), compared exactly or within a stated epsilon.
* A call-count profile: which of the 244 builtins the playthrough calls, how often (wrap them all in a profiling mode): the
  builtins that are never called are untested by definition and are listed.

### 6.9 Saves (1 day)
* ScummVM: play a chapter with the trace; save at each PASS step; load each save and play to the chapter's end; the trace after
  the load equals the uninterrupted one. The original the same with its saves (the `RenderModeUser` way). This is determinism and
  save completeness in one.

### 6.10 Inputs (1 day)
* Key down/up semantics on both: walk backward (needs the release), run with shift held, key repeat, two keys at once; the
  `GetControlState` poll of the driving scripts (the Bone Wagon) with a faked state: the wagon's path over 10 s, both engines.

### 6.11 Routes (ongoing)
* Variant playthroughs as switches of the same chapters: `RUN=1` (Manny runs everywhere), `TALK_ALL=1` (every dialog branch
  exhausted), `ORDER=b` (puzzles in another admissible order). Each variant is a new oracle run on the original and a new
  comparison. Add `nav_cases_run.lua` (the walks of a run) to the default suite once it is green.

## 7. The proof: a report that is generated, not written

`tools/accuracy_report.py` writes `ACCURACY.md` from the latest logs: for every row of section 2's table (and the new rows of
section 6), the test file, the date and md5s of the oracle recording, the counts, the known list's size with the reasons grouped,
the first-difference-per-chapter table of the trace comparison, the frame-diff percentiles, the coverage per file, the trend
against the last report (`logs/navtest_history.tsv` already has the start of this). Rules for the report to count as proof:

1. Every number comes from a log that one command regenerates (`test_all.py all`, with the original run when asked).
2. The oracle recordings are files in the repo with the command and date that made them, and the data md5s match (5.5).
3. Every accepted difference has a reason and the original's function; the report lists them and their count, and the count's trend.
4. A difference outside the lists fails the run.
5. Determinism is reported separately (each engine against itself) from equality (the two against each other).
6. Coverage says what the proof does not reach, per file, and the untouched builtins by name.

That is what can be shown: not "it looks the same", but "these N quantities were compared over these frames with these tolerances,
M differ, each for this stated reason, and here is how to run it again".

## 8. Order and effort

| # | Item | Days | Why first |
| --- | --- | --- | --- |
| 1 | 5.1 the sim-time patch of the original, 5.2 LCG random, the event/frame trace + comparator (4) | 3 | without the same clock nothing can be compared by frame |
| 2 | 6.1 walker to the end (turn rate first) | 2 | measured difference in hand, isolated by the rules tier |
| 3 | 6.8 Lua conformance + builtins | 2 | cheap, and a difference there explains others |
| 4 | 6.2 animation | 3 | the biggest unknown that players see |
| 5 | 6.4 sound/music + 6.6 decoders | 4 | second biggest; needs the trace |
| 6 | 6.5 text/speech, 6.3 timing | 4 | |
| 7 | 6.7 rendering | 3 | pipeline exists; needs a clean full original run with frames |
| 8 | 6.9 saves, 6.10 inputs | 2 | |
| 9 | 7 the report generator | 2 | can start at step 1 and grow |
| 10 | 6.11 routes, coverage gaps | ongoing | |

About 25 working days for the first full report; the report is useful from step 1 on.

## 9. Open findings to carry into this (from the logs of today)

* Turn rate: resolved, it was the original's wall-clock frames (hole 2).
* `IsPointInSector` at a shared edge: the original answers the last sector that holds the point and accepts 1e-5 outside;
  ScummVM the first, exactly (14 point cases).
* Slides with a turn key held, along an edge or a wall: up to 7 cm / 1 degree apart (106 cases).
* `bs_stair_down`, `ledge_window`: the stair constraint and a goal 3 cm off the floor on the original.
* The original's playthrough fails at ch23, ch47b, ch50 and stalls at ch06/25/27/64: the autorun's route, not the engine, but the
  frames comparison needs a clean run.

---------------------------------------------------------------------------------------------------------------

## Update 2026-10-27: the whole-game frame trace

The proof now has a second layer: a trace of every frame of a whole run (`fullcmp_lib.lua`: FT lines with the game time, the set, the cutscene level and the
position and angles of Manny) on both engines, compared chapter by chapter (`tools/ftrace_cmp.py`, `tools/arlines.py` for the timing of the autorun steps).
Recipe in the memory note `grim-frame-match-status`. Rules that make the two runs comparable: the extra library comes first (tasks run in the order they were
started), the autorun's timers do not use beats of their own (the skip of a cutscene is timed from `set_override`, the idle/run checks run every frame).

Ported from the original this session, each with a test: the path planner (`Set::grimPlanPath`, FUN_004a9430 and the others in GHIDRA_NAMES.md), the
walk over the sectors (`Actor::grimWalkSectors`, FUN_004a8610) with the stair line (FUN_004a7520), Actor_GetYawToPoint, TurnActorTo, the clamp of
Actor_SetPositionClamped, the key of TurnActor lasting one frame, the negative turn rate after SetActorRot (the first key turns the wrong way), the chores of
CHORE.DLL (the first update takes the frame time, a chore ends at time >= length), no actor update in a frame that began in a movie, the frame time of
the first pass.

Golden tests (ScummVM against recorded output of the original): `tools/golden_sched.sh` (task scheduling), `tools/golden_setrot.sh` (SetActorRot on a ramp,
with and without the key), `tools/golden_ch01.sh` (chapter 1: every frame to the first difference, 2715 frames of 9182), all in `tools/golden_all.sh`.
Navigation tests after the port: slide 9/9 (was 6/9), known differences from the original 13 (were 94).

Open (first differences, 2026-10-27): speech lines end later in the original (a voiced line lasts the voice plus about 0.5 s: ch05); obstacle avoidance of
the planner (FUN_004917e0) and the replan after a collision push are not ported (pushes are skipped during path walks); funnel sectors; the coll tier of
the navigation tests is chaotic on the original too (its recorded ends differ from run to run).
