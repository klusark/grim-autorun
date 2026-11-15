# Playing Grim Fandango with --autorun

Year 1 plays from a new game to the first Year 2 scene (about 3 minutes at 8x). Every verb is given
the way a player gives it, nothing calls an object's own function: Manny walks (pathfinder, or the
stick when the pathfinder cannot), faces the object, the game's gaze makes it the hot object and the
real USE / PICK_UP / LOOK_AT key goes through the game's button handler. An inventory item is put in
Manny's hand with its hotkey first. An object the game does not offer is a failure, and a failure
ends the run at once (`AR_KEEP_GOING = TRUE` goes on).

    sh run_all.sh [timeout]            one run from a new game, writes the checkpoints into ./saves
    sh run_chapter.sh chNN.lua         one chapter; it loads its own save with ar_load(N) as its first line
    sh rebuild_saves.sh                rebuilds every checkpoint chapter by chapter

(MSYS2 UCRT64 shell, scummvm from ~/scummvm-autorun/build-opt (branch autorun, shared with EMI; SVM_DIR overrides), AR_WALK=TRUE in a
script to stop Manny running.) The generated scripts are in ./generated, the logs in ./logs, the
AUTORUN lines tell what happened and the last steps are shown in the top left of the screen.

| Chapter | Load | Does | Saves |
|---|---|---|---|
| ch01_work_order | new game | office, hallway, garage, Glottis gives the work order | 2, 10 |
| ch02_copal_computer | 10 | out of the building, alley rope, ledge, Copal's computer = answer 5, work order to Eva | 11 |
| ch03_reap_bruno | 11 | reap Bruno | 12 |
| ch04_tube_room | 12 | cards, punched card, balloons, chemicals, jam the switcher, bolt, wheel, card down the red tube (Meche reaped) | 13 |
| ch05_jail | 13 | Meche's conversation, the hallway walk that ends in Glottis' shop (Copal), Salvador lets Manny out to the headquarters | 14 |
| ch06_year_end | 14 | alley, ledge, Domino's office (mouthpiece, coral), balloon and bread, hook, ladder, pigeons, eggs, bondo, eggs and mouthpiece to the headquarters (end of Year 1) | 15 - 19 |
| ch07_glottis_heart | 19 | Year 2: Glottis' heart is ripped out; bone into the spiders' web, the scythe slings the heart free, the heart back into Glottis | 20 - 22 |
| ch08_to_tree | 22 | Glottis has his heart: Manny stays at the wheel and drives to the tree pump room | 23 |
| ch09_tree_pumps | 23 | lever (Glottis up the tree), wheelbarrow over the hoses: the shocks are loose, back at the signpost fork | 24 |
| ch10_signpost_nav | 24 | out of the Bone Wagon, round it, the loosened signpost, planted at the point in the navigation room: the trapdoor opens | 25 |
| ch11_lobby_key | 25 | the key from the sign of the beaver room lobby, through its other door into the beaver room | 27 |
| ch12_beavers | 27 | gate, bones, the fire extinguisher against three beavers, the key opens the padlock: end of Year 2 in the forest | 28 |
| ch13_plunge | 28 | Rubamat plunge, Celso, photo to Velasco, logbook, job | 29 |
| ch14_velasco | 29 | Rubacava: Lupe, shanghaied to Limbo, Velasco lists the goals | 30 |
| ch15_letters_book | 30 | letters from the cafe office, the Blue Casket revolutionaries give their book | 31 |
| ch16_terry | 31 | book to the dock workers' foreman, Terry arrested | 32 |
| ch17_charlie | 32 | Charlie: ticket printer and the V.I.P. pass | 33 |
| ch18_hotel_pass | 33 | liqueur, across town, the pass past Raoul into the high roller lounge | 34 |

| ch19_baster | 34 | Nick and the cigarette case, Raoul in the pantry, baster, cask, forklift: union card; Carla's bomb: the skeleton key; dishwater from the Blue Casket sink | 35 |
| ch20_lighthouse | 35 | the key opens the lighthouse, Lola, the card | 36 |
| ch21_jacket | 36 | the card to Lupe, jacket, slip of paper | 37 |
| ch29_naranja | 37 | one trip to the ship: sailor out, dog tags, the paper to Toto: photo finish, the ticket printer set to race 6 day 2 week 2 | 45 |
| ch34_blackmail | 45 | photo window, blackmail photo, Nick: the strike | 50 |
| ch35_morgue | 50 | Velasco is told everything is done | 51 |
| ch36_byeruba | 51 | the roulette panel breaks the house: end of Rubacava | 52 |
| ch37_lola_start | 52 | Year 3: down the ladder to the engine room, anchors hooked, ship torn from the pier, hydrofoil | 53 |
| ch38_chepito | 53 | the sunken Lola: stop Chepito, bait lantern, hand him to Glottis (Pearl cutscene) | 54 |
| ch39_subjacked | 54 | along the Pearl sub to the back door: the sub is jacked, exterior airlock | 55 |
Things learned: Manny's idle animation blocks scripts until a key is pressed (ar_skipper stops it);
FALSE is nil in this Lua; the game offers only touchable objects within range and in front of Manny
(vlist); once the hook is thrown the alley rope's landing is not walkable, so everything is fetched
first; the ladder needs climb_up run repeatedly (the "up" key); after Meche the hallway camera by
Eva's desk always starts Copal's cutscene and the jail; an object's dialog table only exists once
the conversation has started.

Where it stops: Year 2 after the navigation puzzle (puzzle states 1 - 13 done). Next in Year 2: the
trapdoor to the lobby for the beaver room (lb.sign gives the key), the shocks in the tree pump room
(tr, hoses and the wheelbarrow, puzzle state 17), the beaver room (bv: padlock, gate) and the beaver
dam (bd: bone in the tar, the fire extinguisher against the beavers, states 14 - 16), then the
Bone Wagon drives out of the forest. Driving is done with held keys: the game polls
get_generic_control_state, so the key state has to be faked (wrap GetControlState) and the wagon
steered in a loop. Years 3 and 4 are not started.

| ch40-ch45 | 56-61 | Year 3: hammer (foreman's office), stockings (ashtray room) on the way back, both to Chepito in one trip (chisel, gun), the gun to Meche, the safe | 61 |
| ch46_meche_freed | 61 | close vault door, scythe on tab opens the secret door, drag the axe to the tile in the vault interior | 62 |
| ch47_lamancha | 62 | crane scoop, chisel breaks chain, chain on conveyor, lever x3, raise crane: Lamancha | 63 |
| ch48_crusher | 63 | crane rips out the coral crusher, Exodus | 64 |
| ch49_bloodeye | 64 | scythe in the octopus eye, Year 4 begins in bs | 65 |
| ch50_mug_rocket | 65 | Year 4: mug from Bruno's casket, gate keeper's note, rag, oily rag, toaster fire sets the mug rack off | 66 |
| ch51_bonewagon | 66 | nitrogen (Toto), ship bottle (Velasco), keg, Glottis throws up gelatin, freeze, dynamite: Bone Wagon goes | 67 |
| ch52_pigeon | 67 | arm, photo, note + photo to the pigeon, Bowlsley eats it | 68 |
| ch53_sewer | 68 | Meche's plan, ladder to the sewer hub, remote | 69 |
| ch54_thunderboys | 69 | coffee on the Thunderboys, arm in the grinder, dressing room | 70 |
| ch55_albinizod_trail | 70 | a Thunderboy now: backstage, theater sewer, sewer hub, grinder trail through the sewer maze to Albinizod | 71 |
| ch56_albinizod | 71 | Bone Wagon with the remote, pin Albinizod, down the ladder | 72 |
| ch57_florist | 72 | untape the bell, Bowlsley gives the gun and the Sproutella | 73 |
| ch58_charlie | 73 | sewer hub, theater sewer, casino lobby: agent, Meche's sheet, Charlie, jackpot | 74 |
| ch59_keno | 74 | men's room (dressed up), Brennis keno question, elevator to Hector's foyer | 75 |
| ch60_celso | 75 | Celso sells the ticket, the old job | 76 |
| ch61_neon_ledge | 76 | gargoyle with grinder + Sproutella, neon lady falls, meadow | 77 |
| ch62_greenhouse_door | 77 | greenhouse door, shot, nitrogen on the wound | 78 |
| ch63_salvador | 78 | Salvador's head says goodbye | 79 |
| ch64_ticket_gun | 79 | suitcase ticket, body, key, gun, tanks fall on Hector | 80 |
| ch65_ending | 80 | greenhouse door, the end, credits | - |

The whole game, new game to credits, is scripted (ch01 - ch65).

## One engine for Grim and EMI (2026-11-10)
- The Grim and EMI autoruns run the same engine: worktree `~/scummvm-autorun`, branch `autorun` (was emi-autorun-latest: grim-actor-fixes, then
  cleanroom, now rebased on the latest master), build-opt from `build_scummvm_autorun.sh`. `SVM_DIR` points a run at another build. The old
  `~/scummvm/build-opt` had become a master build without `--autorun`.
- ch45 hung for ever on the safe ("safe: tumbler 4 at 340 goes -1", then STALL; the same on grim-actor-fixes, so not the branch: the random
  numbers of the run changed and drew a tumbler at 340). Tumbler.make_noise (vd.lua) starts tumbler sounds in a loop with no break_here until
  one gets a track (wait_for_sound returns at once when ImStartSound found no spare track, -6). In the original the clock runs on and the
  sounds holding the tracks end; with --sim-fps iMuse only moved on between frames, so the loop never ended. Engine fix (commit "GRIM: Give a
  script that loops without yielding the time of the sound in a simulated run"): every sim_busy_calls (default 1000000, BUSYCALLS= in
  run_all.sh/run_chapter.sh) C calls in one frame the sound clock moves on by a frame (Grim only). At 100000 the planner of the autorun
  tripped it in 20 chapters; at 1000000 only ch45 does (155 times). Full run from a new game: RESULT PASSED.

## Shorter speed run, the route of the speed run guides (2026-11-15)
- Compared with the Any% route guide of the remaster (speedrun.com): three reorders where the guide carries items further and walks less.
  - Year 2, the forest: the tree pumps right after the heart (Manny is at the wheel), then the signpost, the navigation room and the key, and the lobby of
    the beaver room has a door into the beaver room: no walk back from the lobby to the wagon, no drive along the bumpy road (about 800 frames).
  - Year 3: the stockings on the way back from the hammer, both to Chepito in one trip (one walk to the miners and back less, 1,361 frames).
  - Year 4: the Albinizod trail and the florist before the casino lobby; Charlie, the men's room and Brennis in one visit (about 1,000 frames).
- Waits: the Year 2 movie (yr2intro.snm) is skipped (ch13 had AR_NO_SKIP since the first commit; 3,696 frames), a cutscene is skipped in its first frame
  (SKIPMS, default 17 ms in the speed modes, was 500: 4,550 frames), the sleeps before a wait for the control are 200 ms (were 0.5 to 6 s), the Copal
  computer waits for each press to be taken.
- The end: the last verb no longer waits for the control (AR_DO_NO_CONTROL): the last cutscene's movie went straight on from the explosion and the
  stall watch killed the run.
- Speed run: about 275,000 -> 261,526 frames (76:23 -> 72:38 at 60 a second), passes. The checkpoint saves of chapters 8 to 11, 41 to 43 and 55 to 58 are
  rebuilt (SAVE=1 run_all.sh; the old ones are in saves_before_reorder). MODE=speed100 passes too (493,745 frames, 281 dialog lines, the same failures
  of its extras as before); its own saves (saves_speed100) are still of the old order.


## Walking: turns with the run key held, fewer forced walks (2026-11-15)
- The game's run sets Manny's turn rate to 140 degrees a second, the walk to 85 (manny.set_run): every turn on the spot (ar_steer, ar_face_precise) now holds the run
  key, as a player does (ar_turn_run; AR_NO_RUN_TURN = TRUE for the old turn). The follower still steps at the walk when the heading is more than 45 degrees off:
  a run from far off swings him wide (and stepping off at once from any heading was slower still: he hardly moves until he is within about 87 degrees).
- ch54: a run to 60 cm short of the theater sewer ladder's foot, the walk only from there (was 6 m at the walk's rate, 910 frames). ch55: the hops of the grinder
  trail are run, the last 20 cm walked (about 30 hops of 75 frames).
- Tried and left: AR_RUN_OFF = 75 (495 frames, but runs closer to the walls). Speed run: 261,526 -> 256,610 frames (72:38 -> 71:17), passes.

## Waits on the game's state, not on the clock (2026-11-15)
- ar_try_wait, ar_wait_active, ar_wait_turn, ar_dialog_ready, ar_wait_line_done, ar_wait_normal and ar_do's wait for the code of a verb look at their condition every
  frame (they slept 100 ms between looks: 736 waits ended up to five frames late).
- ar_do: no 300 ms after a verb that ar_send_verb has seen start; an item used on its own waits for its sentence or code to begin and the sentence to end.
- ar_wait_offered: the game makes its list of what Manny can use every frame (TrackManny), so a wait for an object to be offered ends when he has stood still
  6 frames without it (the 1 and 1.2 s waits ran out 41 times). A dialog line waits until the dialog has taken it (ar_line_taken; was 300 ms), the gaze key until
  the gaze moved.
- The step on a door's trigger waits for the game to take over (ar_door_trigger_wait, was 1.5 s; 7 of 8 times it does); the 200 ms and 1 s sleeps before a wait for
  the control are ar_wait_idle (until no cutscene, sentence, line or movement, or a cutscene begins); the forklift, crane and keno waits of chapters 19, 47a and 59
  look at the forklift, the crane and the dialog's line.
- A line every 5 s while a cutscene's movie plays: the pearl sub's movie of chapter 38 (14 s, no override) left the stall watch (15 s) a margin of 0.75 s.
- Speed run: 256,610 -> 248,920 frames (71:17 -> 69:09), passes, the same frame count twice.

## Follower: goals far off (2026-11-15)
- A frame by frame trace of the follower (AR_TRACE) in a speed run: of 75,504 frames 51,098 ran, 10,101 walked and 14,305 stood. A goal (kind g) was only walked to
  within 15 degrees of it however far off it was, so he stood and turned on the spot from metres away (5,265 frames standing at goals); a goal more than 50 cm off
  (AR_FAR_GOAL) now takes the 45 degrees of the other steps: 248,920 -> 248,197 frames.
- What is left, and was tried: the turns of more than 75 degrees at the start of a walk (about 3,000 frames) are already at the run's turn rate, and AR_TURN_LIM = 88
  (the walk's turn is faster once he moves) gained nothing; the walking with a good heading far from the point is mostly the slopes of the meadow, where a run
  covers less of the map; about 1,600 frames stand pressed against walls (the "held up" of the follower) and 1,400 walk the last 12 cm to exact points.

## Tricks: TRICKS=blam (2026-11-15)
- Tricks of the speed runners are settings, off unless named: `TRICKS=blam sh run_all.sh` (mode.sh; ar_tricks.lua is only loaded then, a run without it is not
  changed by a frame). The log says "tricks: blam".
- blam: the easter egg of the game (stopKeyDown, est_test in _system.lua): typing b, l, a, m pushes est.cos on Manny and pops the costume on top of his stack 3 s
  later. Typed a few frames before the game pushes a costume of its own (a climb, a search, a pick-up), that costume is the one popped: the chore the game waits
  for goes with it and the scene goes on; the game's own pop takes est.cos off. The runners of the original (54:23 on ScummVM) type it many times a minute.
- Where: anchors (a verb sent, a change of set, the start of a cutscene) keyed by chapter, kind and count; a learning run (BLAMLEARN=1) logs every costume pushed
  onto Manny with its anchor and the frames since it, and every pop; `python tools/blam_spots.py logs/<learn>.log ar_blam_spots.lua` keeps the pushes that start
  and end inside a cutscene and are held 240 frames or more, one per anchor. The trick types the word 3 frames before each (AR_BLAM_LEAD), only to the game's own
  button handler, and only in a cutscene or with nothing held or looked at (the a is the second pick-up key), up to the frame before the push, never after.
- 56 spots, 46 typed; the other 10 (the red tube, the window and ropes of the ledge, the bondo, the beavers' extinguisher, the jacket, the jump off the wagon) push
  their costume in the frame their cutscene starts, with an item in Manny's hand or an object in front of him: not typed. The forum's way for the jacket (typed
  during the search) works by another mechanism, not tried yet.
- Speed run with TRICKS=blam: 240,150 frames (66:43), passes twice; without it 248,197 as before.
- After a chapter changes, the spots of that chapter are learned again: `BLAMLEARN=1 LOG=blam_learn sh run_all.sh`, then blam_spots.py.
- Later the same day: the word is typed as early as the spot allows (lead in ar_blam_spots.lua: up to 175 frames before the push, not before the anchor nor
  before Manny's last costume event), so that its pop comes just after the game's push instead of 3 s after it; the jacket's search 864 -> 40 frames, the
  window of the ledge 380 -> 154. ar_blam_skip.txt: spots left alone, the beavers' extinguisher (cut short, the beaver is not frozen and the fight never ends).
  ar_blam_after.lua: the rope to the ledge and the bondo, typed 10 frames after the push (the game pushes the costume a second time). 50 spots typed:
  240,150 -> 239,119 frames (66:25), passes twice.

## Rubacava against the record (2026-11-15)
- The record of the original (54:23, ScummVM 2.7, its video) laid against ours room by room: most of its lead in Rubacava is the ticket printer warp (a glitch:
  it reaches the lighthouse without Carla's skeleton key, so no cigarette case and no second visit to Carla); not done here.
- Without tricks: Velasco need not be told the vacancy, the union card and the strike. Bogen is back in the casino once the three are done
  (cn.bogens_in_the_house_again, cf.lua and cn.lua), which is what the roulette panel of chapter 36 waits for. Chapter 35 (now ch35_morgue) ends at the elevator
  station after the morgue; the walk to Limbo Dock and Velasco's talk are only in the 100% modes. 2,569 frames less in chapters 35 and 36.
- The vault door: the tumblers' noise (Tumbler.make_noise) spins without yielding when every sound track is taken; the engine's sim_busy_calls rule gets
  it through in 29 frames of game time but in a minute of the wall clock, and the stall watch (15 s) killed the run once the random numbers fell that way
  (chapter 45 with blam, chapter 46 with two runs at once). In the vault door's set a wait for a sound that did not start yields a frame (ar_lib.lua,
  AR_NO_VD_SOUND_YIELD for the old spin).
- Speed run: 248,197 -> 245,520 frames (68:12), TRICKS=blam 239,119 -> 235,531 (65:25), each passes twice with the same count.

## Tricks: TRICKS=menu, Years 3 and 4 against the record (2026-11-15)
- The record (54:23) opens the game menu during movies that have no override. cutscene_menu.view_cutscene starts the cutscene picked in View Cutscenes
  with StopMovie(), which stops the game's own movie, and the scene that waited for it goes on. TRICKS=menu (ar_tricks.lua): a movie of a cutscene with no
  override, after AR_MENU_AFTER (6) frames: the menu key (F1), the menu's hot key c (View &Cutscenes, handed to the menu's characterHandler as the engine hands it
  a typed letter), Home (PAGE_HOME) and Enter for the first cutscene, the override key for it, the override key back to the game. The menu pauses every task
  but the one that pressed its key; that one drives it and counts its frames into the run's (AR_MENU_FRAMES, 2-3 a time, in the last line of the run).
  AR_MENU_SKIP["chapter|set"] leaves a movie alone. 54 movies, 4,104 frames less: the Lola torn from the pier 2,142, Chepito 815, the neon ledge 455, the
  beavers 350, the Pearl sub 293; most of the others are overlays the scene goes on beside.
- Chapter 59: the keno board draws a number every 15 s and clears after its tenth; Brennis's dialog stops the draws, not the clock, so a question asked on
  the tenth number lost its number under the answer (the run failed when the random numbers fell that way). On the tenth the clear is waited for, and the
  list is moved to the number the board shows at each tap.
- Years 3 and 4 against the record: the same order; the gaps were the Lola and the Pearl sub (the menu now), Albinizod and the florist (+32 s), the casino
  (+39 s) and the end (+32 s).
- Speed run 245,693 frames (68:15), TRICKS=blam 235,627, TRICKS=menu 241,589, TRICKS=blam,menu 231,371 (64:16); each passes.

