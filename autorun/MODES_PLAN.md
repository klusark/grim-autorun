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

## Status (2026-11-11): speed100 passes the whole game

`MODE=speed100` plays all 65 chapters in one run (about 180 s; `logs/speed100_pass_1111d.log`). Coverage, `tools/cov100.py catalog.json <log>`:

| | speed | speed100 |
|---|---|---|
| dialog lines said | 64 / 466 | 263 / 466 |
| objects touched | 150 / 681 | 334 / 681 |
| verbs done | 154 / 1487 | 675 / 1487 |
| item combinations | 52 / 252 | 66 / 252 |
| setups seen | 157 / 363 | 162 / 363 |

How it works (ar_full.lua):

* Each set is swept before it is left by `ar_go` or the chapter ends in it (look at everything, walk into the camera sectors, then the heavy step: use, pick up,
  the carried items on every object). Not while a handler of its own has the keys (the Bone Wagon, the safe).
* The people of a set (`AR_TALKERS`, `AR_TALKER_DLGS` of ex03_talkers.lua) are talked to once a chapter, before the set is left and before a chapter's own use of one
  of them (Membrillo in the morgue is left by a cutscene). A person whose dialog has nothing new is skipped; a person whose dialog this chapter or a later one talks in
  itself (`AR_DLG_LAST`, ex04_dlg_later.lua) is left to that chapter.
* The dialog walker (`ar_talk_before`, before each line a chapter picks and before the exit line): every offered line except the ones a chapter picks now or later
  (`AR_DLG_PICKS`, with the lines that share their response), the sub-menus it can come back from (`AR_DLG_MOVE`, `AR_DLG_EXIT` of ex02_dialogs.lua, also through the
  dialog's own functions a response calls), a sub-menu that ends the talk and a line that only ends it when the talk is to end anyway (`AR_DLG_END`), and the talk opened
  again for what is left. Test: `LUA=luajit sh synth/all.sh` (synth/test_talk.lua, a dialog of our own).
* What an extra must not change is checked after it: an item that went (`an item was taken by`), the set left (`the set was left by`), the item in hand (taken in hand
  again). An extra gives up after 2 failures; the stall watch kills a chapter of more than 120 s (`CHSTALL`), a run that logs nothing for 30 s.
* `tools/sweep_fix.sh` plays the whole game until it passes and blocks what broke a chapter in ex00_sweep.lua (`tools/sweep_blame.py` names it: the object that took
  the item the failure names, an object or extra that left the set in this chapter or the one before, else the last extra). Blocks: by set (`AR_NO_SWEEP`,
  `AR_NO_HEAVY`), by object (`AR_NO_USE["bv.bone_wagon"]`), by dialog (`AR_NO_TALK`), by person, also in one chapter only (`AR_NO_TALKER["<set> <person>@<chapter>"]`).

Left out, with the reason in ex00_sweep.lua: the dialogs of Celso in Rubamat (`ce1`), Nick Virago (`vi1`) and Charlie (`ch1`), whose chapters depend on the order in
which their menus offer lines; the heavy step of the meadow, the theater backstage and the albinizod tunnel; the sweep of some sets where it strands Manny.

Not done:

* Mode `full100` has not been run (it is `full` plus the same extras).
* The dialogs never opened: Domino's first (`do1`, Year 1, his office), Maximino (`mx1`), Carla's first (`ca1`), Aitor (`ai1`): their people are in sets the run
  leaves without a door or a use of them.
* The original (`build_original.sh MODE=`) was not run with the modes.

## Status (2026-11-15): speed100 on the new route

The reordered speed route (PROGRESS.md, 2026-11-15) broke speed100 in chapter 37: the sweep of the engine room walked Manny out through the instruments to
the ocean porthole, and the way back carried him into the engine room, where the anchor was used. That sweep is blocked (ex00_sweep.lua, by tools/sweep_fix.sh).
Then three more people to talk to:

* Brennis in the Year 1 tube room (br1, 7 of 9 lines): his dialog is opened with dofile and `br1:init()`, not `Dialog:run`, which tools/gen_talkers.py now
  also reads (the clown's cl1 too, which chapter 2 keeps for itself).
* Carla's first talk (ca1, 9 of 13 lines): only there before the metal detector scene of chapter 18, which scorns her; the people of the security hall are
  now talked to as Manny comes down the stairs (100% modes only). Her line 120 ends the talk with a walk across the detector, whose scene then never gave
  control back: tools/gen_dlg_skip.py no longer counts a response that walks Manny as one that only ends the talk.

Whole game: passes, 427,048 frames (446,011 with SAVE=1), dialog lines 293 of 466 (was 277). The speed run is unchanged (245,693).

Then the two people never met, both in chapter 19 (100% modes only):

* Maximino (mx1, 13 of 14 lines): a side trip from the high roller lounge through the door at its back, which is not in the gaze but lets Manny in until Nick
  has gone. Maximino greets him as he steps in and the game opens the talk itself: ar_look_all and the side trip now talk through a dialog the game opened
  (ar_talk_opened). The approach push of ar_do and the step out of a door sector stop when a dialog has the keys (they stepped Manny under it, a failure).
* Aitor (ai1, 11 of 13 lines): a side trip from the kitchen through the elevator door. The first time in the kitchen he brings up the new cask and stays
  downstairs (hk.put_up_new_cask); he is back in the elevator once Manny comes into the kitchen again from the lounge, so the trip goes out to the lounge and
  back first.

Whole game: passes, 432,496 frames (452,471 with SAVE=1), dialog lines 317 of 466, sets entered 99 of 120. The speed run is unchanged (245,693).
Every dialog is opened now.

## Status (2026-11-16): sets entered, door trips

* The coverage report counts a set as entered from the engine's own note too ("Switching to set: <name>."), and the 100% run logs `COV set` the first
  time it is in a set (ar_set_watch): eight sets the story only passes through in a cutscene or a script's move (the anchor room, the florist, the end
  of the world, ...) had no camera notes and counted as never entered. 99 -> 107 of 120 with that alone.
* Door trips (ar_door_trips, ar_full.lua): when a set is swept (and each time it would be swept again, and before a side trip from it), a side trip through
  each of its doors to a set of AR_TRIP_TO (ex05_trips.lua, the sets the story never enters) not entered yet, when that set has a door back: the ramp,
  the cafe ledge, the blimp bridge, the police interior and the bridge on its side, the ocean porthole, the Mayan train station, the high roller pantry.
  AR_NO_TRIP["<set global>.<door field>"] blocks one (tools/sweep_fix.sh: kind trip).
* tools/sweep_blame.py: the notes "the side trip did not get to", "the game opened the dialog" and "no trip through" are not extras (they were counted as
  ones, and a failure after them as inside one).

Whole game: passes, 443,694 frames (463,906 with SAVE=1), sets entered 117 of 120. The speed run is unchanged (245,693).
Then the two sets of chapter 47 (100% modes only):

* The crane track: a set with no objects, the game shows it only for the movie of the chain dropped into the trough (ew.chain_in_trough), when the broken
  crane is lowered at a stop between the crusher and the conveyor. Chapter 47a lets the turn key go at stop 2 (the move goes on to the next stop in the
  frame it reaches one), lowers the crane at stop 1 and raises it again, then turns on to the conveyor.
* Glottis hanging on the Lamancha: chapter 47b, before the lever, walks into the more belt of the conveyor room (the stick pushed toward it: the moving belt
  makes the planner plan again every few frames), which floats Manny to the anchor room; there the back key crawls him along the belt to the anchor
  (ac.gh_door, the Lamancha cutscene, only before the ship is raised), and back down the ladder and the forward key crawl him back to the conveyor room. The
  doors are taken with AR_GO_OLD: the sweep of ar_go would have pulled the lever in the heavy step.

Whole game: passes, 446,245 frames (466,474 with SAVE=1), sets entered 119 of 120. The speed run is unchanged (245,693).
Left: the photofinish (the photo looked at in hand, Ctrl and the look key, chapter 29: ScummVM re-creates its window for the set and the
engine stops answering, so it is not done).


## Status (2026-11-16): camera setups

* Every new setup of a set is a `COV setup` line (ar_set_watch), whatever showed it; Meche's intro is held until the computer view (mo_comin) shows.
* The camera walk (ar_visit_setups): a camera sector whose middle is off the walk floor is walked into at a point of the floor inside it, the nearest to
  its middle on a 12 by 12 grid (ar_camera_floor_point), when its setup has not been seen yet.
* The look views: the plaque under Sanspoof on the way back from the cat stables (chapter 18, kh_sansp: the Kitty Hallway is not swept), the loose
  signpost before it is picked up (chapter 10, sg_mancu), and the far end of the Neon Ledge roof while the neon lady still stands (chapter 61, nl_neoha).

Whole game: passes, 449,988 frames, setups seen 236 of 363. Of the 127 unseen, 105 are the overhead debug views and most of the rest close-ups of
cutscenes (skipped). Not reachable in play: tu_swiha (inside the tube switcher with its door closed: the door only opens, and the box floor is off
while it is closed), ci_glotk (box_off at every entry), hp_intha (the pantry closed when Manny comes in: he walks in only through it open), and the
setups no script and no camera sector names (tu_swicu, Hallway 1, 4 and 5, co_dskrv, lm_velws, bd_beacu, na_intws).

## Status (2026-11-16): people talked to in every chapter

* The people step talks to a person whose dialog a chapter talks in (this one or a later one) too, and the talk of an extra says the lines of such a
  dialog (they were skipped, AR_DLG_LAST); the lines a chapter picks itself are still left to it (ar_picked_later).
* A block holds where it broke only: AR_NO_TALKER "<set> <field>@<chapter>" (Charlie in chapter 17, Nick in chapter 34; the blocks of Celso, Charlie and
  Nick in every chapter are gone), AR_NO_TALK_UNTIL[name] = "<chapter>" (ce1, ch1 and vi1 are blocked up to the chapter whose own picks they broke), and
  AR_NO_EXTRA_TALK[name] = "<chapter>" (lu1 up to chapter 14, ce2 up to chapter 60: only the extras' talks, the chapter's own talk says the lines).

Whole game: passes, 474,548 frames (SAVE=1), dialog lines 320 of 466. The speed run is unchanged (245,693).
Of the 146 lines left: 45 move to another node of the talk, 32 end it or start a cutscene (AR_NO_AUTO), 19 are the exit lines of nodes, 4 cannot be
offered, and 46 come on only after a line of another node or later in the story.

Then the talk itself (ar_talk_before):

* Nodes at any depth: every line that moves to a node the talk comes back home from (ar_talk_dist: the steps home by the lines that move and the exit
  lines), each line once, and a node entered again on the same visit only by a line not said yet; back home one step at a time. Before, one level of
  sub-menus, each entered once a visit (Salvador's 110, 130, 140 and 150 all go to fold_node).
* The dialog on screen first (ar_dialog_ready) before the talk before a chapter's pick: chapter 5 picks as soon as Salvador's talk starts, and the talk
  found no lines yet, so his first menu was never talked in (the same for every chapter that picks at once).
* ca2 (Carla's second talk, chapter 18) is blocked: a line said before the chapter's picks ended the run inside the talk.

Whole game: passes, 474,861 frames (SAVE=1), dialog lines 324 of 466. The speed run is unchanged (245,693).

Then talks held again while there are lines left:

* ar_talk_one talks to a person again (up to 8 visits) while the dialog has a line the talk would say (not one a chapter picks later, nor one it never
  says on its own) in a node it can still get to, off too in its start node (a later visit's intro turns lines on), and the last visit said something
  new. A visit for a line it cannot say (Carla's 120, chapter 18) only said goodbye and the chapter hung.
* When a visit is to end anyway, it goes into a node with no way home, at any depth, and ends there by a line that only ends the talk (AR_DLG_END), or
  by the node's exit line (ar_talk_dead_end); a node with no exit line is ended the same way by ar_pick_exit.
* A line that moves to the node it is in is a plain line (Salvador's 160). AR_DLG_KEEP (tools/gen_dlg_skip.py): a move that stays on when said may be
  said by an extra though a chapter picks it later (Salvador's 220 into angry_node); a response that is a function of the dialog is read too (his 170).
* Chapter 5: Salvador is talked to at the door before the chapter's own talk, five visits, each ended in the shop: 15 of his lines left -> 5, which the
  game never offers (130 needs 120 marked said, which nothing does; 140 is only ever turned off; one of 300 to 330 per game, 155 turns itself off).

Whole game: passes, 486,808 frames (SAVE=1), dialog lines 336 of 466. The speed run is unchanged (245,693).

Then lines with several nodes, aborts, and the lines the game says itself:

* tools/gen_dlg_skip.py: AR_DLG_MOVES[dialog][line] = { nodes }, a line whose response only moves to one of several nodes as the state of the dialog has
  it (Eva's 12 and 14, ev1:explain_choice(): explain_node, or first_eva_node once she has explained it all; Virago's 240). The talk takes it by its worst
  node (a node with no way home makes it a one-way move) and follows the node the game goes to.
* AR_DLG_ABORT[dialog][node] = node: the game runs the abort of a node by itself when only its exit line is left (_dialog.lua, min_line), so a node
  talked through comes back there (Eva's explain2_node, Charlie's slot_machines, Domino's question and tell nodes). A way home for ar_talk_dist.
* Of the moves on offer, the one into the node farthest from home first (Eva's explain_node: the way through page_node turns 105 on).
* Dialog.execute_line logs a COV say line for every line the game says, also one a script says by itself (chapter 2 hands Eva the work order: her 2).
* Chapter 2: Eva talked to before she gets the work order, her 4 is on only between Copal's office and Bruno reaped. (Her 14 is no window line:
  met_glottis is never set, it is on in any talk after the garage.)

Whole game: passes, 487,899 frames (SAVE=1), dialog lines 355 of 466. The speed run is unchanged (245,693). Eva's first talk: 16 lines left -> 5
(5, 70, 75, 95: one way through explain_node a game; 130: its node is spelled expain2_node, never offered).

Then more of the talks, chapter by chapter:

* gen_dlg_skip.py: a response that calls another line's, "vi1[190]:response()", does what that one does (Nick's 180 moves to best_node, and was
  taken for a plain line: said before chapter 19's pick, it moved the talk on); an exit line set from another table ("me2.exit_lines.n3 =
  me2.delayed_n3_exit", Meche's n3; "ev1.exit_lines.explain2_node = ev1.exit_lines.first_eva_node"); a line that only ends the talk may set fields of
  its own dialog table (Nick's 210, vi1.joke_time).
* The talk goes into a node with no way home only where it can end there (a line that ends the talk, an exit line, or a node further on where it
  can: ar_talk_endable), and, in a node with an abort, only where the node shows two lines or more: with one the game runs the abort by itself, and
  Nick's aborts say that line, the one chapter 19 picks. A line with several nodes, every one it may go to. Only lines said for the first time count
  for talking to a person again (AR_TALK_NEW).
* ex00_sweep.lua starts its tables empty: a chapter played from a save had the Lua state of the run that made it, blocks this file no longer has
  included (Nick's).
* Chapter 19: Nick is talked through after his first line (100), each talk ended in one of his nodes with no way back, back into trouble_node by
  240, the chapter's own lines kept for it; his threats node once more before the kiss (290). Where a node is left with one line, the game says it
  by itself (150, 280), and the chapter does not pick it again. 16 lines left -> 3 (110 needs Terry arrested; 160 and 230 one more way into good_node).
* Chapter 13: Celso's talk is blocked until his 120 is picked, then the lines before 135 (which leaves him talked out): 7 left -> 3 (160 is in a
  node named "first", never shown, and 170 comes after it; 130 is 120's other way).
* Chapter 17: Charlie's talk is blocked until his 100 is picked, then the rest before the chapter's picks: 10 left -> 1 (110 is 100's other way).

Whole game: passes, 491,407 frames (SAVE=1), dialog lines 381 of 466. The speed run is unchanged (245,693).

## Status (2026-11-16): the Lua coverage of the game's scripts

A ScummVM with cleanroom/scummvm/lua-coverage.patch (a worktree of the autorun branch, ~/scummvm-luacov, built as build-opt is) and GRIM_LUA_COVERAGE
set measures which functions of the game's scripts a run calls: SVM_DIR=/home/Joel/scummvm-luacov/build-opt GRIM_LUA_COVERAGE=<folder> MODE=speed100
run_all.sh, then tools/luacov.py <folder> --json report.json. tools/luamiss.py report.json <run log> gives each object handler that never ran
(<set>.<object>.<lookAt|use|pickUp|use_item|walkOut>) the reason: set never entered, set not swept, heavy step off, tried and refused, never tried.

* The sweep looks a set over again each time it would be swept, for what it has not looked at yet (AR_LOOKED; an object that was not there to touch
  the first time), and uses, picks up and tries the items again for what is new (AR_USED, AR_ITEM_TRIED: each verb once a game, each item on each object
  once): extras "relook <set>" and "reheavy <set>", blocked by AR_NO_RELOOK / AR_NO_REHEAVY (sweep_fix.sh kinds relook, reheavy).
* Doors are looked at from their use point (out of the door's sector), turned to, and only where the game offers them there (ar_look_doors).
* A door the chapter uses to leave a set (ar_do on a walkOut object) sweeps the set first, as ar_go does: Copal's office was never swept.
* A step of the sweep that took Manny out of the set comes back through the door that leads there (ar_sweep_back): the walk to Copal's message board
  climbed out of the window.
* ex00_sweep.lua: the blocks of sets that sweep_fix.sh had added were all tried again; the ones still needed came back, several as one object instead of
  the whole set (the rope of the alley, the cocoon, the cranes, the eye).

Whole game: passes, 565,405 frames (SAVE=1). The speed run is unchanged (245,693). Functions of the game's scripts run: 3,718 -> 3,871 of 5,437;
verbs done 710 -> 825 of 1,487, objects touched 354 -> 389, item combos 70 -> 84.

Then the doors (2026-11-16): the run walked through 207 doors and never through 96 walkOuts; 52 of those are trigger boxes, not doors (the drift of
the Lola, the rail of the cafe, the retreat of the Neon Ledge), left alone. tools/gen_door_trips.py writes the other 44 into ex06_doors.lua
(AR_TRIP_DOOR), from a coverage report, and the door trips (ar_door_trips) take each once from a set swept that has it or its door back: through and
back, both ways. 18 of the 44 are walked through now (bu.bl_door, cy.ea_door, dd.hb_door, ea.cy_door, ev.pc_door, fh.fo_door, fi.fp_door, fp.at_door,
hb.dd_door, hl.hh_door, lw.nq_door, mg.pc_door, my.bs_door, rp.st_door, sg.sm_door, sh.lw_door, st.rp_door, zw.sh_door). Of the rest: 6 trips broke a
chapter and are blocked (AR_NO_TRIP), 6 went and did not get through (the alley's trap door is not offered, Copal's door, the Lola Zapata door), 12 are
in sets never swept or where no trip began.

Whole game: passes, 620,775 frames (SAVE=1). The speed run is unchanged (245,693). Functions of the game's scripts run: 3,871 -> 3,920 of 5,437;
verbs done 825 -> 852, objects touched 389 -> 396, item combos 84 -> 87, dialog lines 382 -> 384.
