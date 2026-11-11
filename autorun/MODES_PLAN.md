# Plan: four run modes

State on 2026-10-30. The autorun plays the whole game in one way: text only, every cutscene skipped by its override 500 ms after it starts, lines
left to run for as long as their text says (`SetTextSpeed(7)`, `talkspeed=179`), the minimum of the story. `REAL=1` turns the skipping off and the
voices on. The four modes asked for:

| mode | name        | cutscenes | lines                       | voices | what is done            |
|------|-------------|-----------|-----------------------------|--------|-------------------------|
| 1    | `speed`     | skipped   | skipped with the skip key   | off    | the minimum             |
| 2    | `full`      | played    | played to the end           | on     | the minimum             |
| 3    | `speed100`  | skipped   | skipped with the skip key   | off    | everything there is     |
| 4    | `full100`   | played    | played to the end           | on     | everything there is     |

Mode 2 is today's `REAL=1`. Mode 1 is today's default plus the skip key on every line. Modes 3 and 4 are new work: a catalogue of everything the
game has, extra steps in the chapters, and a report of what a run covered.

What the catalogue has to cover (counted in `~/grim_lua_src`, the game's scripts):

| what                              | count                                                            | the speedrun today        |
|-----------------------------------|------------------------------------------------------------------|---------------------------|
| dialogs / lines                   | 35 dialogs, 493 lines (431 in `dlg_*.lua`, 62 inline)            | 12 dialogs, 63 picks      |
| objects                           | 1266 `Object:create`                                             |                           |
| verbs with code                   | lookAt 517, use 364, pickUp 222, walkOut/climbOut 307            | 193 `do:` steps           |
| item combinations with code       | 226 `use_<item>` handlers, 60 item names (`use_scythe` 35 ...)   | a handful                 |
| sets                              | 120 in `AR_SETS` (some are inventory rooms and cutscene sets)    | 74 reached by `ar_go`     |
| setups                            | per set file, `section: setups` (cf has 4, two with camera boxes)| not counted               |

---------------------------------------------------------------------------------------------------------------

## 1. The switch and modes 1 and 2

1. **`MODE=`** in `run_all.sh`, `run_chapter.sh`, `build_original.sh` (and `rebuilt_test.sh`): `speed` (default), `full`, `speed100`, `full100`.
   The generated script gets `AR_MODE = "<mode>"`; `ar_lib.lua` derives `AR_REAL` (full, full100: what the code tests today) and `AR_FULL`
   (speed100, full100) from it. `REAL=1` stays as a synonym of `MODE=full` so nothing else changes. The config side stays with the shell scripts:
   `speech_mute`, `talkspeed`, the window and `RENDEREVERY` (a real run draws every frame, as now).
2. **Logs and saves per mode.** `LOG` defaults to the mode's name (`logs/speed.log`), `SAVES` to `saves_<mode>` when the mode is a 100% one (the
   checkpoints of a 100% run hold a different game: more items used, more lines off). The comparison of two runs stays the normalised log
   (`[0-9A-F]{16}`, `task: N`, FPS lines); each mode gets its own baseline, kept under `logs/base_<mode>.log`.
3. **Mode 1, the skip key on every line.** A task that runs every frame (like `ar_override_clock`, not on a 100 ms timer, so the frame of the press
   is the same on both engines): when `IsMessageGoing()` it presses `EXPIRE_TEXT` (`shut_up_everybody()` + `ExpireText()` in `_controls.lua:497`,
   what the period key does for a player). Off in `full*` modes, off while `AR_FRAMES` is set (the frame marks 700 ms after a pick want the text
   on the screen) and off during `ar_say_mark`. One press a frame is enough: the next line of a response starts in a later frame.
   Expected: the run gets shorter (the 1 s gaps of a run are set loads, movies and lines; `tools/gaps.py`), and a new class of bugs can show,
   since scripts that pace themselves with `wait_for_message()` now run at once. Those are findings about the engine, not about the run, and go
   to ScummVM fixes as the collision and turning ones did.
   Validation: the whole game passes twice with the same normalised log; `UPTO=6` first.
4. **Mode 2.** `REAL=1` passed the whole game on 2026-10-25 (508 s of wall time; the voices and movies go by the real clock, the game's clock by
   the simulated one). Run it again on the current build (the 60 fps cap, the no-save default, the shaders text fix are newer), fix what the
   weeks have broken, and record its time. Its log is not the same line for line from run to run (a voice ends in whichever frame the real clock
   says), so its check is the PASS/FAIL lines and the chapter times, not the whole log: `tools/arlines.py` already picks those.

## 2. The catalogue and the coverage report (for modes 3 and 4)

5. **`dump_catalog.lua`** (a dev tool like `dump_sets.lua`, run once per engine build of the game data): for every set global that has a `setFile`:
   its setups (`readfrom` on the set file, `section: setups`, and which of them have a camera sector of the same name); its objects (every table
   field with a `name` and a `string_name`) with the verbs that have code (`lookAt`, `use`, `pickUp`, `walkOut`, `climbOut`) and the `use_<item>`
   fields; the inventory items of `sp` with their `use_<item>` fields (item on item). For every dialog table (`Dialog:create` results, found as
   globals with `exit_lines`): its line numbers, texts and `off` state at the start. Output: `CATALOG` lines in the log, `tools/catalog.py`
   turns them into `catalog.json`. The dialogs that are only created when their set is entered (`dofile("dlg_glottis.lua")` from `ga.lua`) are
   taken from the script source instead (`~/grim_lua_src`, `tools/catalog.py` reads `dlg_*.lua` for the lines).
6. **Coverage in the run.** `ar_lib.lua` logs `COV` lines in every mode, from the places it already goes through: `ar_send_verb`/`ar_press`
   (verb, object, item), `ar_choose_line` (dialog, line), `ar_go`/`ar_target_reached` (set), and a hook on the setup: `camChangeHandler` is the
   game's own callback, wrapped the way `set_override` is, logging set and setup number on every change (this also catches the setups that
   cutscenes switch to). The game's own `Sentence` and `Dialog.execute_line` are not wrapped: what a cutscene says by itself is not something a
   player did.
7. **`tools/cov100.py <catalog.json> <log>...`**: per set, the objects and verbs never done, the item combinations never tried, the setups never
   seen; per dialog, the lines never said; totals at the top, and a `coverage100/index.html` like the gcov report. Run it first on the speedrun
   log: that is the starting point and the to-do list for step 9.

## 3. Modes 3 and 4

8. **Helpers that exhaust a thing** (in a new `ar_full.lua`, loaded with the library):
   * `ar_talk_all(dlg)`: while the dialog offers a line that is not an exit line and has not been said in this visit, say it (`ar_choose_line`);
     then the exit line. The game's own `off` fields decide what is offered, so lines that a choice closes for good are reported by the coverage,
     not chased. A line that ends the dialog (hands over an item, starts a cutscene) ends the loop like `ar_dialog_ready` does today.
   * `ar_look_all(set)`: `lookAt` every object of the set that is touchable and has `lookAt` code, nearest first (`ar_approach` walks there).
   * `ar_use_all(set)`: `use` and `pickUp` on every object with code for it, except the ones a list names (doors, the things that move the story:
     `AR_FULL_SKIP[set][name]`).
   * `ar_items_on(obj)`: every inventory item for which `obj` has a `use_<item>` field (`trim_header(item.string_name)`), with the item taken in
     hand as `ar_do` does today; and `ar_items_on_items()` in the inventory for the item-on-item fields of `sp`.
   * `ar_visit_setups(set)`: walk into one point of each camera sector (`nav_setfile.lua` already reads the sectors; it only keeps `walk` and
     `hot` today, so it keeps `camera` too) and wait for the setup to change; setups without a camera sector are the cutscenes' and are only
     counted. The point is a vertex-weighted centre of the sector that is on the floor (`ar_nav_floor_z`).
9. **Extras per chapter, by hooks.** The chapter scripts stay the minimum: `ar_extra("ch01 garage")` at the points where a 100% run has more to
   do (before the line that moves the story on, since lines and objects go away with the puzzle state). `ex01_work_order.lua` ... define
   `AR_EXTRAS["ch01 garage"] = function() ar_talk_all(gl1) ar_look_all(ga) ar_items_on(ga.fountain) ... end`; `run_all.sh` concatenates the
   `ex` file after its chapter in the 100% modes, and `ar_extra` is a no-op otherwise, so modes 1 and 2 do not change by a frame.
   Written act by act, Year 1 first (ch01-06, `UPTO=6`), each act against `cov100.py` until what is left is explained (unreachable in one
   playthrough, or deliberately skipped because it ends the game or softlocks). The coverage report is the definition of done, not a feeling.
10. **Mode 4** is mode 3 with `AR_REAL`. Its wall time is the sum of the voices and movies: the speedrun has 50 picks and takes 508 s in real mode,
    the 100% run says 493 dialog lines and some 1100 verb responses, so expect 2 to 4 hours. That needs: `STALL` left at 90 s (a voice is never
    that long), the `AR_REAL` ten-fold timeouts as now, `SAVE=1` checkpoints into `saves_full100` so a failed chapter is replayed alone with
    `MODE=full100 sh run_chapter.sh`, and the run in the background with `logs/<name>_times.txt` watched.
11. **The original.** `build_original.sh` takes `MODE=` too, so a difference found in a 100% run on ScummVM has its reference run on the original
    with the same script (the `orl.sh` remote Lua and `tools/framecap.py` are there for the frames). Not every chapter passes on the original
    today; that is not made worse by the modes.

## 4. Order of work and what each step proves

| step | work                                       | proof                                                              | size       |
|------|--------------------------------------------|--------------------------------------------------------------------|------------|
| 1-2  | `MODE=`, logs and saves per mode           | `MODE=speed` is today's run line for line; `MODE=full` = `REAL=1`  | small      |
| 3    | line skipping                              | whole game twice, same log; time recorded in TESTS.md              | medium     |
| 4    | mode 2 on the current build                | whole game passes; PASS lines the same as the speedrun's           | small-med  |
| 5-7  | catalogue, COV lines, report               | report of the speedrun log with the numbers above                  | medium     |
| 8    | exhaust helpers                            | ch01 extras: all of gl1 said, all of ga looked at, setups seen     | medium     |
| 9    | extras, act by act                         | `cov100.py` per act; whole game in `speed100`                      | large      |
| 10   | `full100`                                  | whole game passes in the background                                | small+time |

Decisions taken here, to be overruled if wrong: "every setup" means the camera-sector setups reached by walking, the cutscene ones counted only;
"every item combination" means the ones with code (`use_<item>` fields), with the default "not now" responses sampled, not exhausted (there are
60 items times 1266 objects of them); "every dialog line" within one playthrough: a static read of the scripts finds only 3 either/or pairs (two phrasings of one question
in the Celso, Charlie and Salvador dialogs, the same response for both), 8 lines that go when a sibling is chosen first (an order to keep),
and 40 lines in 14 dialogs that the intro switches off by the puzzle state (the hook has to come before the story step), so the target is 488
of 491 lines, and the report lists the three left out. Today's default run (text on, lines not skipped) is what the engine comparisons
(`FRAMES`, `saymark`) were built on; it stays reachable as `MODE=text`, which is `speed` without the line skipper, so those tools keep working.

---------------------------------------------------------------------------------------------------------------

## Status (2026-10-30)

Done and checked:

* `MODE=speed|text|full|speed100|full100` (`mode.sh`, in `run_all.sh`, `run_chapter.sh`, `build_original.sh`). Logs go to `logs/<mode>.log`; the real and 100% modes
  keep their saves in `saves_<mode>`; the real modes save their checkpoints by default (mode `full` fails in chapter 64 without the save: Manny is held up in the
  meadow, the menu mode of the save changes how much game time passes between chapters; not investigated further).
* Mode `speed`: every line is ended with the skip key (a task that presses it in every frame in which a message is going; only the key, never a direct call).
  The whole game passes, twice, with the same log (54,456 lines), in 113 s (text mode: 128 s). Chapter 38 needed the skipper off for the lines Chepito says while
  held: they are the player's time to give him to Glottis (`AR_SAYING = TRUE`). More such places can show in other runs of the speed mode; they are findings.
* Mode `text` is the old default; act 1 matches the baseline line for line.
* Mode `full` (= `REAL=1`): the whole game passes with the saves (274 s). 2026-11-10 on the `autorun` engine: passes (ch01-53 in 228 s, then ch54-65 from
  the ch53 checkpoint in 44 s, after another session's EMI restart killed the engine). One line was cut: the "line that does not end" check of `ar_skipper`
  counted the whole of byeruba.snm (217 s), because the subtitles of a fullscreen movie are lines of actors that the engine does not update in a movie's frames,
  so `IsMessageGoing()` stays true until the movie ends; it pressed the expire key on the last subtitle (brbsv28c). That check now waits while a fullscreen
  movie plays (a stuck movie has its own check). A full-mode run must have no `skipping a line that does not end` and no `a movie that does not end` line.
* Coverage: `COV` lines in every mode (`ar_cov`), `tools/catalog.py` (writes `catalog.json`), `tools/cov100.py catalog.json <log>...` (also reads the `camera:` notes
  for sets and setups). The catalogue counts differ from the first estimate above (466 dialog lines, 798 objects with a static name, 1487 verbs, 252 item combos,
  363 setups): this one is read from the script source; the estimate counted every `:create(` and the inline lines.
* `ar_full.lua`: `ar_extra`, `ar_talk_all`, `ar_set_objects`, `ar_look_all`, `ar_use_all`, `ar_items_on`, `ar_visit_setups`, `ar_arrived`. `nav_setfile.lua` keeps the
  camera sectors in 100% modes. `ex01_work_order.lua` is the first extras file; the whole game passes in `speed100` with it.

Coverage of the whole game, speed and speed100 (only chapter 1 has extras): dialog lines 64 and 69 of 466, objects 145 and 152 of 681, sets entered 97 of 120, setups 157
and 159 of 363, item combinations 52 of 252.

Not done:

* Extras for chapters 2-65 (step 9). A generic sweep of every set the first time the run is in it (`AR_SWEEP["set name"] = TRUE`) is there but off for every set: in the
  garage and the hallway it strands Manny or takes him out through a door (he arrives on floor that only the sectors that are off give a way over; the elevators change
  the floor when looked at). A sweep has to be tried set by set, from a point where Manny stands on the floor. Doors are left out of the look sweep.
* Mode `full100` has not been run (it is `full` plus the same extras).
* `ar_use_all` and `ar_items_on` have not been tried in a run. The 8 order-dependent dialog lines and the three either/or pairs are not handled yet.
* The original (`build_original.sh MODE=`) was not run with the modes.
