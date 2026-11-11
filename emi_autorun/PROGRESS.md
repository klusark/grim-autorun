# Escape from Monkey Island with --autorun

Built on the libraries of ../autorun (not changed): `emi_prelude.lua` (manny = guybrush, 30 s idle limits), `emi_lib.lua` (what EMI does
differently, same names as the Grim functions where the meaning is the same: ar_walk_to, ar_face, ar_steer, ar_approach, ar_do, ar_hold,
ar_checkpoint, ar_skipper ...; EMI-only: ar_talk, ar_say, ar_exhaust, ar_survey, ar_map, ar_sectors, ar_look_item, ar_dlg_done).

    ./run_all_emi.sh [timeout]   all chapters from a new game, checkpoints into ./saves (grimNN.gsv)
    ./run_one.sh chNN            one chapter from the checkpoint of the one before it
    ./run_ch.sh chNN             chapters 1..NN replayed from a new game (no saves)
    NOLOG=30 (seconds without a log line stops a run), SIMFPS=60, worktree ~/scummvm-emi/build-opt

| Chapter | Does | Checkpoint |
|---|---|---|
| ch01_wed | Act 1: wedding ship (brazier, hot coal, cannon) | - |
| ch02_scu | Melee town, SCUMM Bar: darts pop the balloon, the drunk falls, the pretzel bowl | - |
| ch03_navigator | insult arm wrestling: Mr. Cheese is the navigator | - |
| ch04_innertube | harbor: the inner tube | - |
| ch05_catapult | tube on the cactus, pretzels for Tony, the controls: the catapult breaks | - |
| ch06_elaine | mansion: the Gubernatorial Symbol, the cushy contract signed | - |
| ch07_crew | Carla and Otis: the crew | - |
| ch08_ship | the symbol to the Harbor Mistress: the ship, sail to Lucre Island | 8 |
| ch09_lucre | Lucre Island: dock to the law offices (level hop through the west stair), the letter | 9 |
| ch10_lawyers | Marley's letter read, the lawyers asked everything (flags: read letter, deed, bank) | 10 |
| ch11_bank | Lucre: law offices to the bank | 11 |
| ch12_bankpoke | the poker robs the bank (the symbol on Brittany: bank_robbed, rock_first) | 12 |
| ch13_vault | the vault: music box, grog, sword in the hinge then the crack, three sponges, grog on them: the door bulges open, Hall o' Justice | 13 |
| ch14_hoj | the Hall o' Justice explored by the poker (chicken grease; Otis, Canard talked to) | 14 |
| ch15_out | out of the Hall o' Justice into Lucre town (upper level) | 15 |
| ch16_spritzer | spritzer, water into it | 16 |
| ch17_bait_wood | bait and wood shavings into the spritzer | 17 |
| ch18_flower_swamp | flower into the spritzer | 18 |
| ch19_swamp | swamp water into the spritzer (Mysts o' Tyme puddle) | 19 |
| ch20_files | Deadeye names the smell (Edgar E. Dangerous), file dials, directions | 20 |
| ch21_dials | the three rollers set by key presses | 21 |
| ch22_bridge_myst | BRIDGE: the raft through Mysts o' Tyme is not played; the game's own jump 160 "solvedmyst" | 22 |
| ch23_pph | Pegnose's hideout: grease on the mat, the duck at the window: Pegnose caught | 23 |
| ch24_lagoon | lagoon, hidden passage, the button (BRIDGE flag found_lagoon: the Ozzie chase is not played) | 24 |
| ch25_booty | more bait into the ScupperWare | 25 |
| ch26_booty | dive, glowing fishy, cavern, the loot (AR_NO_SKIP: the skip loses recovered_loot) | 26 |
| ch27_skin | manhole cover sweethearts, Deadeye's story gives the prosthetic skin | 27 |
| ch28_nose | skin over the manhole, bounce into the bank, chain, light, Pegnose's nose | 28 |
| ch29_hoj | the tiny screw, Canard, end of Act 1, Elaine's plan (el15) | 29 |

Things learned: movies play at their own length without running any script in a simulated run (RunFullscreenMovie is replaced);
overrides of doors must not be skipped (they kill the script that switches the set); TrackGuybrush dies of a game error in some sets and
is restarted by the skipper; keys walk cannot cross a step between two sectors (the game's trigger strip does, ar_mel_patio_down);
`forced_hotlist` offers map places; item keys are glob.item_bindings.

Later notes: checkpoints work (the engine fix in lua_v2.cpp, postRestoreHandle, clears the dim regions the boot leaves behind);
`emi_poke.lua` is the room explorer (EXTRA="emi_poke.lua"; ar_poke_room(passes)); stuck checker: NOLOG=15 s without an AUTORUN progress line;
Lucre's levels are joined by cheat boxes (HOT sectors named ...cheatbox) that hop Guybrush on contact: AR_HOPS in emi_lib.lua names the
strips (Lucre west stair done; the others as they are needed).

Where it stands (end of this session): chapters 1-15 are scripted and replay from checkpoints 8-15; Lucre town after the robbery is next
(the Myst puzzle at Mysts o' Tyme, the House o' Sticks and Pegnose Pete's hideout, the nose screw and the evidence for Canard, Ozzie).
What blocks faster progress: (1) walking in Lucre (levels joined by cheat boxes; the planner only knows the west stair from the dock, AR_HOPS
needs the others, or a learned hop table); (2) the poker is slow in big hubs (each try walks across the town); (3) a run ended at once in the
middle of the banker's conversation ("got gesture", no error: an engine crash or exit, not looked into). Acts 2-4 are not started; the game's
own milestone jumps (_jumpscripts.lua, jump_script("200") ...) are a way to start each act from the right state.

## Act 4 (Monkey Island, the last act and the ending) - own chapters act4_NN_*.lua, checkpoints 400+NN, saves in saves_act4/

    ./run_act4.sh act4_NN_name [timeout]   one chapter alone (it loads the checkpoint of the one before: 400+NN-1; chapter 01 starts a new game)
    ./run_act4_all.sh [timeout]            all chapters in order, each its own run from the checkpoint of the one before (a chain)
    ./run_act4_one.sh [timeout]            ALL chapters in ONE run (AR_CONTINUE: the ar_load lines are no-ops, the checkpoints are still saved), NOLOG=60
    helpers: act4_lib.lua (loaded by run_act4.sh via EXTRA); logs logs/act4_*.log; act4_old/ = the first attempt (jump 390 + a symbol added)

Result: jump "300" (the beach, empty pockets) -> every puzzle of Monkey Island -> the final Monkey Kombat -> the credits, 27 chapters. The chain
(run_act4_all.sh) passes every chapter; run_act4_one.sh plays all of it in ONE run (jump to credits, about 2 minutes of real time; AR_TIMEOUT is raised in act4_lib.lua: the library's watchdog stops a run after 30 minutes of game time). The retail game does not
load _jumpscripts.lua (test_build is nil): ar_a4_jump does dofile("_jumpscripts.lua") and starts jump_script. Jump "350" (northmonkey) =
chapters 02-15 done; jump "390" = chapters 02-19 done, but not Herman's memory (390 has no Gubernatorial Symbol: the second Seal comes from
Herman Toothrot/Marley when his memory is back, chapter 22). So the state that the last act expects: bronze hat, accordion, coconut, milk bottle,
picker, bananas in the pockets (cymbals given to the monkey), herman_talk_status 0, lava_filled, rock_lava, met_priest, the tree knocked.

| NN | Chapter | Does |
|---|---|---|
| 01 | jump300 | new game, jump "300" |
| 02 | picker | beach -> map -> canyon (can_door_left): the banana picker |
| 03 | bananas | back to the beach: the picker three times on the bunch of bananas |
| 04 | timmy | Timmy fed a banana (he follows through the next door only; in every set he waits until fed again), the canyon |
| 05 | goldmine | Timmy fed again, into the mine: vent opened, banana tossed in (Timmy jumps in), vent closed, banana held at the portal: the latch is pulled, the door opens |
| 06 | whipper | tube to the machine room: the weed whipper with the picker |
| 07 | coconut | out, over the canyon to the Toothrot camp: the coconut |
| 08 | vista_point | map -> sco_door: Pachinko Rock |
| 09 | rocks | 4 rocks (slot 3, slot 2, slot 1, slot 1) with waits 2300/11750/6200 ms of FRAME time between a pick-up and the next throw (ar_a4_wait_ms; sleep_for is not frame time in a simulated run): the slot-2 rock is bumped by the slot-1 rock at junction j1 to the long way round, the slot-3 rock bumps it at j2 on to j3, the last slot-1 rock meets it there: sink B2 = the lava field (rock_lava) |
| 10 | lava | down from the vista point (keys west into the exit strip), map -> lava field (west gate, the floor) |
| 11 | church | map col_door -> church path; the game's walk to the door; the ghost priest's dialog; the shields (cymbals) with the picker (the planner cannot walk the narrow stair of the nave: NAV teleport) |
| 12 | flume | priest dialog (50, 200, 55, 56, 57): the lava plunge; the flume solver takes the boat to the milk bottle's node (9 for puzzle 1, 12 for puzzle 2), picker on the bottle, on to the node "lavfield": the ledge by the weeds |
| 13 | weeds | weed whipper on the weeds: the lava drains (lava_filled) |
| 14 | tree | the lone palm tree kicked from the hill (the hill is reached from the ledge by steps the planner does not see: NAV teleport) |
| 15 | east_gate | out by the east gate (across the fallen tree, the ledge and the bridge) |
| 16 | jojo | Monkey Town, Jojo Jr.'s dialog (80, 310, 500, 510): Monkey Kombat taught (disc_kombat) |
| 17 | accordion | look at the shields (they become cymbals), use them on the musical monkey: he drops the accordion, taken |
| 18 | training | wild monkeys on the island map (chased until the jungle encounter), Monkey Kombat solver until the kombat level is 4 |
| 19 | jojo_fight | challenge Jojo (120) and beat him (level 5): the bronze hat |
| 20 | to_camp | town -> east gate -> lava field: bridge, ledge, fallen tree, hill, ramp (waypoints) -> west gate -> camp |
| 21 | herman | first meeting (the camera cut starts it), coconut, milk bottle thrown at Herman in that order |
| 22 | seal | accordion: his memory is back; ht0 dialog (70, 180): the Seal |
| 23 | to_head | camp -> lava field west floor -> ramp up -> hill, tree, ledge, bridge -> east gate -> Monkey Head |
| 24 | head | bronze hat thrown on the head, banana picker in the nose: the mouth opens, the head absorbs them |
| 25 | robot | up the tongue (keys, then the game's own walk over the step), into the head, the Seal in the slot: the robot wakes, Ozzie's tower |
| 26 | tower | plank to the short tower, up it, jump on the plank (bounce) |
| 27 | fight | the big switch (forced_hotlist), the final Monkey Kombat, the epilogue dialog, the credits |

Things learned (also in act4_lib.lua):
- The Lua globals of a run are part of a checkpoint: flags set by a chapter (AR_A4_GAMEWALK ...) are still set in the next one (ar_a4_begin resets them; it also leaves a jungle encounter).
- Set tables (mom, lav ...) are rebuilt when a set is entered again: anything patched into them is lost; a script (ar_a4_patcher) switches the
  collision handler of the wild monkeys of the map off every 50 ms (a monkey touching Guybrush throws him into a jungle encounter); only the chase of chapter 18 turns it on.
- ar_a4_in_set waits for the set name, then ar_settled + 0.5 s: the name changes before Guybrush is put at the new door (a walk planned then is from a wrong place).
- The map of Monkey Island is in pieces (town + Monkey Head path + lava field east gate / the beach, camp, canyon / the lava field west + church): the pieces are joined by the lava field
  and the canyon; the planner (grid on GetPointSector) does not see ramps and steps whose sectors are thin: ar_a4_ramp_up/down and AR_A4_LEDGE_PATH are waypoint walks found by steering.
- Map doors: the planner reaches the nearest floor; ar_a4_enter then uses the game's walk (narrow floor) and goes straight into the strip (other doors' strips are avoided: AR_A4_AVOID_HOT).
- Huge sets (the tower): AR_A4_GAMEWALK = TRUE (the game's manny:walkto instead of the grid planner), and no stand points of objects with a huge range.
- A verb whose script does not give the control back (the switch -> fight -> credits, a dialog) is started with ar_a4_start (like ar_talk); a held item is put away first.
  ar_a4_verb_dialog repeats it when the dialog does not come up.
- Monkey Kombat (monkey_kombat2.lua): stances 1-5; a stance is changed by saying 3 words (keys forward/right/back/left = 1..4) glob.mk_phrase_table[from][to];
  the same word three times holds the stance. Normal fights: move to a stance that beats the monkey's (mk.what_beats_me). Last fight (mk.level 6): the monkey
  cannot be hurt below half, the fight ends after 3 draws on Guybrush's own turns, so the solver moves to the monkey's own stance (3 rounds).
- The lava flume (lava_flume2.lua): a graph of nodes, steering = holding LEFT/RIGHT while the boat is on a node. Empty boats sit on nodes and go home after a bump.
  glob.flume_puzzle (random, once) 1: bottle at node 9, 2: bottle at node 12; subvariants by the boats' nodes. The solver tries three ways in turn (lap after lap): past node 11
  (a bump of the boat on 12 throws Guybrush back over node 8 on to 9: backbounce), the shortest, past node 4 instead of node 1 (the boats of 8 and 9 bump each other away). All 8 variants tested.
- Pachinko: see chapter 09 (the timings are frame-time ms; the rock graph is in pac.lua).
- NAV teleports left (the library's last resort, logged as "NAV teleport"): the shields in the church (narrow stair), the tree (steps on the hill). Everything else is walked.
- The credits (credits_menu) run to their end in about 25 s of real time.

## The whole game (run_everything.sh)
Four runs one after the other: Act 1 `run_act1_seq.sh`, Act 2 `run_all_act2.sh`, Act 3 `run_all_act3.sh`, Act 4 `run_act4_one.sh` (jump 300 to the end of the credits). Each act was run to its end on its own; the four have not been run back to back in one go (about 1.5 hours). Act 4's chapters 02..19 overlap the Monkey Island content of Act 3 (both solved it from a jump); the Act 4 run starts from jump 300.

## Act 1 now without bridges (changes after the first full pass)
The two bridges are gone; the chapters after ch11 are renumbered. New order: ch12 bank robbery (teller dialog, the ScupperWare picked up in the bank), ch13 vault, ch14 Hall o' Justice (poker), ch15 out, **ch16 Ozzie's stick** (music box on for Deadeye, limb basket view, the wooden hand, the termites of the bait shop's circus on the hand, the hand on the stick: Ozzie takes the gnawed stick = the sawdust trail; it has to be done before anything in the House o' Sticks is looked at or picked up, Guybrush is framed by then), ch17 spritzer .. ch21 files, ch22 dials, **ch23 chess clock** (Santiago dropping his piece "Where?" at status 1, the crush, "Hi, Brittany!" at status 3, the clock; and the duck), **ch24 the raft** (Mysts o' Tyme: the clock on the raft, steered through the eight screens of Pegnose's map, the future Guybrush's key and gifts and the number, the gate), ch25 Pegnose's hideout (listen at the door, grease, duck), **ch26 the chase** (Ozzie's mansion: the bluff about the booty showcase, Ozzie leaves, the trail through garden and forest to the lagoon, passage, button), ch27 bait, ch28 dive and loot, ch29 skin, ch30 nose, ch31 screw and Canard, end of Act 1.
Small shortcuts left in Act 1: ch16 puts the wood shavings on the floor with the lines of the ordinary stick scene; ch23 stands Guybrush at the clock; ch26 runs the skip of Ozzie's exit scene when the engine hangs it ("Ozzie is not inside a walkbox"); the cavern entrance (ch28, ch31) is skipped when it hangs. `emi_myst.lua` has the raft helpers (EXTRA of run_act1_seq.sh).

## The whole game in one go (run_whole.sh / run_single.sh)
`./run_whole.sh` (= `./run_everything.sh`) plays EMI from a new game to the end of the credits with one command. `run_single.sh` is the one process: ch01..ch31 (Act 1), then act2_02..25, act3_02..14 (no milestone jumps: the acts follow each other as the game does), the tower and the fight (act4_26, 27), the credits. Each act's library is put into the run just before the act on top of a fresh emi_lib/poke/myst (the act libraries replace the walking code in their own ways and break each other's chapters otherwise). `run_whole.sh` restarts `run_single.sh` from the checkpoint before a failed chapter (`RESUME="<slot> <first file>"`: the save restores the game and Lua state; the libraries of that act are put in again), up to 5 times for one chapter. Last pass: attempt 1 from a new game to act3_04 (the lava ride, random), attempt 2 to act3_08 (Monkey Kombat), attempt 3 to the credits: about 9 minutes of real time. Logs logs/whole_N.log, summary logs/whole.txt, saves in saves_single/.
Remaining chances for a chapter to fail on its own (each is caught by the restart): the lava flume puzzle variants (Act 3 ch4), Monkey Kombat (Act 3 ch8/9), the parrot search of Act 2 (fixed to cover the first row), the kitchen door of the Lua Bar (Act 2 ch6, retried).

## The wood shavings (found 2026-10-26, not yet applied to ch16)
Where they come from (disassembled scripts in `luadis/`, tested in the engine): `hos.sawdust_inv` always exists in the House o' Sticks but is untouchable until
`props.sawdust.state` is set by `hos:ozzie_takes_stick` (sub #203 of hos.lua: Freddie's "brand new cane" scene). The scene is started by the shop door (use the door
while `glob.guybrush_framed`, `not glob.saw_ozzie_take_stick` and the cane INITIAL), by looking at / picking up the cane, or by the hot sector at the door.
- Player route that works (tested from checkpoint 15): in the shop use the door (the scene runs: shavings state 2, saw_ozzie_take_stick, cane 4 = Ozzie has it), come back in, `pickUp` the wood shavings: they are in the inventory.
- The gnawed cane scene (`ozzie_is_back`, sub #206, started by `use_prosthetic_hand`) does not place the shavings; after it nothing in the shop gives them (tried: other sticks, Freddie, leaving and re-entering). That is why ch16 still puts them down by script.
- The two routes exclude each other in one visit: once Ozzie has the ordinary cane (state 4) the cane object is gone and the hand cannot be used on it. The game's own debug jump state before the gnaw has saw_ozzie_take_stick TRUE, cane INITIAL, shavings FINAL (used for the cologne): the cane is put back to INITIAL by a scene in Ozzie's mansion (ozi.lua sub #110: `ozzie_gone_to_hos`, cane INITIAL). Open: how the player reaches that scene, and the right chapter order (shavings and cologne, mansion scene, then the gnaw).
- The hotlist does not offer the cane from where the planner stands (`not offered after walking up to it`), so ch16 also starts `use_prosthetic_hand` by script: a second shortcut to remove.
Follow-up (2026-10-26, mansion): the mansion door is reachable from the island map (`lum.oze_door`, then `oze.ozi_door`), and the conversation `ozi1` runs there with the
ordinary cane too (tested from the checkpoint before ch26 with the cane set to the ordinary state, and from ch15 with the shavings in hand: it needs the swamp knowledge for the
option "you're the jerk who hired Pegnose" at main_node; before that main_node offers no option the autorun knows how to pick). Its ending sets `chasing_ozzie` whatever the cane,
not `ozzie_gone_to_hos`. The scene that sets `ozzie_gone_to_hos` and puts the cane back to INITIAL (ozi.lua line ~4282 in the disassembly, and sub #110) is started from somewhere
I have not found. So the order shavings -> cane back in the shop -> gnaw is still open; the two other places that put the cane back to INITIAL are the bank scenes (ban.lua
`ozziebitch`: Ozzie breaks his cane, and its skip handler), which run in ch12.

## Direct script calls replaced by player actions (2026-10-26)
- ch27: the bait and the ScupperWare are combined through the inventory (`ar_combine` in emi_myst.lua: the inventory keys, as a2_combine of act2_lib).
- ch28/ch31: the fishy is caught with "use the ScupperWare on the bioluminescent fishies" (ch31 catches it again: the cave mouth is "???" until the fishy lights it), the cavern is entered by swimming into its door sector (`ar_walk_into_door`, emi_myst.lua: HOT sector of the door, no "use" verb), the screw is given with "use the screw on Inspector Canard" (only sent: it starts the end of Act 1).
- ch26: the hidden passage's look-at fires by walking into its sector (`ar_walk_into_door("uch_door")`).
- ch24: the raft is now steered with the held keys (`ar_raft_walk` in emi_myst.lua: turn towards the point, forward, a grid path over the floatable cells round the banks; the raft's button handler reads forward/backward/turns held). Still direct: `start_script(mot.guybrush2_obj.use_skeleton_key)` (sent as a verb after `ar_inv_hold(mot.key)` the game takes another branch: the puzzle's question is reset), and the wrapper `start_script(ar_raft_exit, "gate_trigger")` is our own helper. `ar_inv_hold` (inventory, for the 0 key that the raft handler does not pass on) is in emi_myst.lua.
- ch28/ch31: the fishies swim round the lagoon, so the ScupperWare is held first and `ar_wait_offered` waits for the school to come into reach.
- Also still direct: the cavern-entrance recovery (skip + setpos) in ch28/ch31 (not hit in the last runs), ch23's setpos at the clock, the library's teleports.

## Section A (no input a player could not give): status 2026-10-26

Done
- ch24 skeleton key (pole, inventory hold, verb) and ch23 clock without setpos.
- Engine: Actor::walkForward (EMI) goes on into a walk sector within 10 cm when the exit point of the old one finds none (the 3 cm gap
  in front of Meathook's front door stopped the key walk 5 units short). Set::findClosestSector takes an `exclude` sector.
- Library: AR_NO_TELEPORT is the default; ar_walk_direct steps aside when a walk makes no headway for 1.5 s (Jambalaya town: the
  tourist does not move; opt-in elsewhere with AR_AVOID); AR_NO_CHEAT (planner ignores cheat boxes; ch16 school town, where they
  belong to the puppet show; the chapter resets AR_CELL_SET because the cell cache is per set); AR_FINE_Y (finer height probes for
  the sloped strips of Knuttin's town, on from act2_lib.lua on, off in Act 1 where it broke ch02).
- Raft (Mysts o' Tyme): the exit cell is the nearest one at least 4 units clear of the other exit triggers (a touch of another
  one is a "random move"), path with a margin from the other triggers when one exists, forward only within 25 degrees; ch24 follows the
  map to the end with up to 5 exit tries.
- A whole run gets through Act 1 and all of Act 2 with no teleport. Act 3 ch05 now passes with keys only (see below); first stop is Act 3 ch06.

- Engine: the gap jump in Actor::walkForward is once per call (twice sent the walk back and forth between two thin sectors for ever:
  the lava field froze the game; that was the "hang" of act3_05).
- Act 3 ribbon floors (lava field, canyon; act3_lib.lua, end of file): a3_ribbon_walk plans on a tenth-of-a-unit grid with a fine
  height scan about the neighbour's, jumps small gaps at dead ends, feels out of dead ends with the keys, and walks the plan leg by
  leg (a3r_plan, a3r_feel_out). Lua 3.1 numbers are floats: cell keys must stay below 2^24 (they did not at first).

Open
- Act 3 ch06: Guybrush reaches the end of the ribbon at 21.2 -19.4 (3.86 from the lone palm tree, which is offered within 3.5) and the
  floor ends there; the game's own walkto also finds no path to the tree's use point (24.7 -16.1). The lava field's script (lav
  sub #48) sets Guybrush and a monkey about itself when the tree is knocked: look at what makes the tree usable/near before spending
  more on the planner. Then ch10/12/13 sites.
- Still to do from the list: cavern-entrance recovery (ch28/ch31 skip + setpos), EscapeMovie/call_override fallbacks, ar_hold writing
  glob.item_bindings, ar_walk_to defaulting to manny:walkto, Act 2-4 helper audit (boat ctl:walkto, dive walk_forward, act4 manny:walkto).
- Flaky: ch11 (exit 127 once), ch28 fish offered check, act2_06 kitchen door.

## Engine audit 2026-10-27 (Ghidra, original Monkey4.exe)
- SetActorFOV(actor, deg) at 0x412ff0: stores cos(deg * (pi/180) * 0.5) in the actor's extra record (+0x8c). Guybrush's script sets 120.
- GetVisibleThings(actor) at 0x415c80: the actors of the observer's set (not the observer) for which FUN_00428070 holds: same set, and
  FUN_00427eb0: with the extra record present, the horizontal (xz) unit vector from the observer to the target dotted with the
  observer's facing is >= the stored cos; WITHOUT the extra record nothing is seen at all. The port used "yaw to the target < 90".
- EnableActorPuck(actor, bool) at 0x413240: creates (or destroys, false) a 0x150-byte object named after the actor, at the actor's
  position, kept in the actor's extra record at +0x23c. A collision/ground proxy ("puck") for props that actors bump into (the raft,
  the flume boats, the sushi boats, the manatee, the puppets). Still a stub in the port.
- Sector::isPointInSector: single-precision cross product against -1e-6 rejected points that lie on a long edge (the closest point
  of a sector, which is where a walk to a place off the floor ends). Now double precision with a distance margin of 1e-5 + 3e-7 * |coordinates|.
  Neighbour lookup in Actor::walkForward excludes the sector being left (the margin would otherwise keep the walk in it).

## Engine work 2026-10-27 (after the audit above)
Engine (all in ~/scummvm-emi, uncommitted):
- Sector::isPointInSector in double precision with a distance margin (1e-5 + 3e-7 * |coordinates|). The tourist's and the waitress's
  "No path found" are gone (a destination on a long edge was rejected by the single precision test).
- Actor::walkForward (EMI): the neighbour sector is looked up without the sector being left (the margin would keep the walk in it);
  then, when there is none, the sector over/under the place within a step of 0.6 (Set::findStepSector, Sector::containsXZ): stairs,
  ramps and the platform of the Lua Bar can be walked with the keys (the lookup in 3D wants the point on the plane of the sector,
  which it never is at the foot of a step). The sector under an actor at the start of each walk step is looked up the same way (the
  closest sector in space put an actor that had stepped off a platform back on its edge). The gap jump (<= 10 cm) is once per call.
- SetActorFOV is real (cos(fov/2), default 120 degrees as the player's actor has it, not saved); GetVisibleThings uses it
  (Actor::canSeeEmi) instead of "yaw < 90".
- New opcode GetFloorHeights(x, z [, margin]) (not in the original, at the end of the opcode table because saved games refer to the
  opcodes by place; registered again after a load for games saved before it): the heights of the planes of the walk sectors over/under
  x, z. The route planner (ar_cell_y) and the ribbon walker of Act 3 use it instead of probing GetPointSector at guessed heights.
- Not done: EnableActorPuck (a collision proxy object, see above).
Autorun:
- ar_cell_y asks GetFloorHeights (margin 0.12), ar_line_ok samples every 0.15, ch02 copes with the walk entering the door box,
  raft exit cells are interior cells of the trigger, ch24 retries the exit.
- Act 3 ribbons: a3_to_map from the lava field takes the door whose box the ribbon leads to (mom_door_path at the end of the hill),
  ch05 passes without the game's walk.
Open:
- act2_06 (Lua Bar kitchen): with the walks of the NPCs working the chef really comes back and the kitchen has a time limit
  (kit.timelimit = what is left of the chef's time at the mechanism, 4.9 s when the door is reached 40 s after the jam); the way
  from the stool to the kitchen door has to be quick (the waitress and the chef block it); the sous chef's conversation (chef1) ends
  with Guybrush thrown out. The old runs got through because the chef's sequence stalled.
- act3_06: the lone palm tree is offered within 3.5 and the ledge ends 3.86 from it (hidden tree sectors become visible when it falls).

## Puck (2026-10-27)
- Original (Ghidra): the puck is the body an actor is walked and turned with (position + heading node, 0x150 bytes, named after the actor).
  EnableActorPuck(a, true) makes it, false destroys it; WalkActorTo (0x410e30 -> 0x42ac80) does nothing for an actor without one, the
  per-frame step (0x42a730, WalkActorForward / turning) needs one, TurnActorTo (0x41a960) makes one if missing. Not a collision proxy.
- Port: Actor::_puck (default true, saved from save minor version 35), EnableActorPuck sets it, TurnActorTo (EMI) sets it, and an EMI actor
  without it is not walked (Actor::walkTo / walkForward). ActorPuckOrient's "not implemented" warning removed (it is done in calculateOrientation).
- Whole-game batch after this: fails EARLY (ch02 dart players' dialog: the cutscene level is up before ar_do's control wait; made ch02 send the
  verb and follow the dialog; then ch03 arm wrestling picks a comeback that is "not shown yet", the dialog ends). The ch02 failure is the same
  with the puck gate compiled out, so it is not the puck. Old checkpoints in saves_single do not load any more (opcode table order of an older
  build): a new run regenerates them. Open: find what made the early Act 1 chapters (timing / random sequence dependent) fail since the last good batch.

## Fallbacks removed (2026-10-27): every input is one a player could give
Section A is done for all four acts. What changed since the puck:
- Dialogs: ar_choose_line scrolls in scroll dialogs (insult arm wrestling), else says the first not-yet-said shown line until the wanted
  one shows (a dialog shows 3 lines + exit, a line further down appears when earlier ones are used up). ch03 waits for the settle.
- Inventory: items are not bound to number keys by the game; ar_hold binds with shift+key in the inventory (ar_inv_bind). ar_inv_open
  presses the inventory key again while the game is busy (Herman's camp arrival swallowed it once).
- Doors / skips: AR_IN_DOOR keeps the skipper from stopping a door walk (only in the room the door is in); the skipper has no EscapeMovie
  or call_override; no NAV/hub teleports; TrackGuybrush is not restarted, only logged.
- Planner (emi_lib): ar_cell_y (GetFloorHeights), ar_grid_path (BFS), ar_grid_path_big (A*), fine retry; on a MAP (case-insensitively:
  "Monkey Island Map" was never matched before) AR_AVOID_HOT keeps out of other places' door strips, AR_HOT_OK / AR_HOT_START name the
  goal's and the start's strip, a far goal is planned on a 0.5 grid and again on a 0.2 grid when the coarse search stays > 3 units away
  (half-unit strips leave no cell with a margin). AR_WALKER = another actor to walk (the Act 2 boats).
- Ribbons (lava field, canyon): emi_ribbon.lua (moved out of act3_lib), A3R_AVOID_DOORS. a3_hot_door only avoids triggers named *door*
  (the Monkey Head mouth strips and the palm tree ends are floor).
- Act 2: ch06 jam sent when the flame is A2_JAM_LEAD = 3.3 units before the painting, can of grog and brush bound to keys, no forced_hotlist writes.
- Act 3 order is now: 02 03 04 05 10 11 12 06 07 08 09 13 14. Why (found with the decompiled Lua in ~/emi_extract/src):
  * The island map (mom) is two pieces of floor: east (beach, camp, canyon doors, vista point, church door, lava field south door) and
    west (village, Monkey Head, the lava field's east door). The only link is the lava field: the hill (from the south door) and the
    ledge/platform/east door are different islands there; the fallen palm tree is the link, and it can only be kicked from the platform
    (use point 24.7 4.9 -16.1; the ramp tip is 3.9 away, the tree is offered within 3.5).
  * The platform is reached by the second flume ride: once rock_lava is set (ch11, the four pachinko rocks) the flume has a branch
    "lavfield" that puts Guybrush out of the boat on the ledge by the weeds (lav.stop_boat). So: mine (ch10: weed whipper) -> pachinko
    (ch11) -> church ride to "lavfield" (a3_ride_bot with A3_RIDE_TARGET) -> weeds whipped, tree kicked (ch12) -> east door -> town.
  * a3_goto crosses the lava field when the target is on the other piece (a3_map_side, a3_cross_lava); a3_go first walks the planned way
    to the place's use point (the game's own walk to a place goes straight through other places' trigger strips) and then gives the verb;
    a wild monkey that catches Guybrush (jungle) is left by the jungle door and the walk repeated.
  * The canyon's plateau (right door, y 7.7) is a dead-end pocket of the map's right canyon door, not a way anywhere.
- ch11 pachinko: the rock releases are timed from the verb to the rock being made (deterministic per frame: 2290 / 1620 / 1630 ms for rocks 2-4).
- ch10 a3_feed_timmy waits for Timmy to be in the set before looking where he is (his position is that of the set before for a moment).
- Harness conveniences that are not game input and stay (documented): manny.stop_idle = TRUE stands for "a key stops the idle animation";
  RunFullscreenMovie is not started in a simulated run (AR_REAL plays it); the jump_script starts of act2_01 / act3_01 are only for
  standalone starts, the whole run does not use them.
- Engine: the temporary SECTORDBG block in GetFloorHeights is gone.

## Whole-game batch status (2026-10-27, end of day)
- Passed in separate runs: Act 3 ch10 -> end of Act 4 (from checkpoint 305/307/312/313), Act 2 ch06-25, Act 1 ch28 onwards (ch28 now sends the use verb the moment the
  fish school is offered; ch28 may need 2-3 tries, they are in the loop).
- Act 1 ch24 (raft of Mysts o' Tyme) is the open one. The map is random per run. Fixed: raft step not gated on the puck (the script destroys the raft's
  puck at the shore and the raft still moves), actors put into a set get a puck, SetSelectedActor enables it, ar_raft_walk tries margin 0.5 (the strict
  sector edge test now makes the raft start of screen 3 touch the left trigger). STILL OPEN: when the meeting with the other Guybrush happens (map_step 3,
  bring_other_guybrush: raft2:runto(401.4, 1.6) + wait_for_actor) and the player's raft arrives at the gate screen from the east (403.8 -2.3), the two rafts
  collide ("other actual raft has run into actual raft") and the cutscene never ends (cutSceneLevel 1 for ever). Check the actor collision response
  (Actor::handleCollisions / collision mode of the rafts) against the original, or whether raft2 needs a puck-less run.
- Map walking: on "Monkey Island Map" the planner now seeds from the nearest floor cell when Guybrush stands a hair off the floor (ar_grid_path_big),
  retries on the fine grid and then without a margin; the walk to a place's use point comes before the verb (a3_go).

## Engine switch (2026-11-10)
- run_emi.sh runs `SVM_DIR` (default `~/scummvm-emi-latest/build-opt`): worktree `~/scummvm-emi-latest`, branch `emi-autorun-latest` = `grim-actor-fixes`
  (the newest branch with the autorun harness: --autorun, --sim-fps, GetFloorHeights, the puck, the EMI sector fixes) with master (Nov 10) merged in,
  merge not committed (one conflict, the GfxTinyGL constructor, resolved). Build: `../build_scummvm_emi_latest.sh` from a UCRT64 login shell.
  The old engine is `SVM_DIR=/home/Joel/scummvm-emi/build-opt` (Oct 27; ~/scummvm-emi itself has been moved to master since, only the build is left).
- Fixed: the Grim library's Actor.walk_forward wrapper (autorun/ar_lib.lua, Nov 5) passed on only the actor, so EMI's walk_forward(actor, TRUE)
  made one step: the raft boarding of ch24 looped for ever (on both engines). Checkpoints keep that wrapper: saves made before the fix must be regenerated.
- Raft planner (emi_myst.lua): the clearance from the banks was measured inside ONE walk sector (GetFloorHeights(x, z, 0.8)); the water of
  Mysts o' Tyme is cut into big triangles, so a dead strip ran along every shared edge and the planner found no way on most screens ("RAFT no
  path ... straight", 12 of 13 drives on Oct 27). The old engine let the raft slide along a bank, the new one stops it there, and the raft
  backed into another exit (a random move). Now: floor at the place and at 8 points round it; the trigger margins are tried with
  clearance 0.8, 0.5, 0.3; then half-unit cells (AR_RAFT_STEP 0.5) with clearance 0.3 and 0 (screen 2's arrival is a channel about a unit
  wide between the left and right exit triggers, its neck narrower than 0.6); a way gets as many tries as it has points (+40).
  `python raft_floor_check.py` checks screens 4 and 2 offline on setx/mot.setb.
- ch23: the duck waddles on while Guybrush walks to where it was (he ended 3.3-4.2 away, range 3): he follows it until it is within 2.4.
- act2_08: the door leaves Guybrush 2.03 from the cup (range 2, 3D) and next to the old walk point, so that walk never started: the walk now
  goes towards a point past it (3 s, the counter stops him in reach).
- Result: `run_whole.sh` from a new game to the end of the credits on the new engine: attempt 1 to act2_22, attempt 2 from checkpoint 221 to the
  end (289 + 173 s of real time, no teleport). Logs logs/whole_1.log, whole_2.log.
- Seen once each, not looked into: ch23 exit status 127 after the duck (the checkpoint save?); act2_22 waited 120 s for control while Marco's
  dialog, which the skipped arrival cutscene starts, was up (the retry passed).
- 2026-11-10 later: `cleanroom` merged into emi-autorun-latest too. A new game drew a map where the raft arrives on screen 4 on the edge
  of the left exit's trigger (it covers the left half of the water) and the way to the bottom exit went through it: near the raft the
  planner now checks the cell itself against the other triggers (it skipped them within 4 cells). ch24 fails after 8 exits past the gate
  instead of looping until the watchdog (three wrong exits send the raft to the start of the map). Whole game on the merge: attempt 1 to
  act3_08 (exit status 127 during Monkey Kombat, the second 127 today), attempt 2 from 307 to the credits (435 + 43 s).
- emi-autorun-latest is now linear on master (109 commits: grim-actor-fixes, then cleanroom; the commits master took in were dropped; the old
  merged branch is backup/emi-autorun-latest-merged-2026-11-10). ch16: pop.wait_for_move ends the close-up of the limb basket the moment
  Guybrush moves or turns, and in some states he is still turning when the short cutscene ends (the hand keeps range 0): the basket is
  looked at again once he stands still. Whole game on the linear branch: one attempt, 466 s.
- Exit status 127 (three times on 2026-11-10: ch11, ch23, act3_08) comes while a set loads, after "missing texture" warnings (default.tga):
  probably a crash in EMI texture loading. The restart covers it; not looked into.
- 2026-11-10 night: the branch is now `autorun` in the worktree `~/scummvm-autorun` (renamed from emi-autorun-latest, rebased on the latest master),
  the one engine of the Grim and EMI autoruns; `build_scummvm_autorun.sh` builds it, run_emi.sh defaults to it. Whole game on it: one attempt, 446 s
  (an earlier build of it: attempt 1 failed in act2_06, "the flame stopped at the painting", not seen before; attempt 2 to the credits).
- 2026-11-10 late: Guybrush standing still. emi_lib's clock task prints `CLOCK <ms> <x> <z> <cutSceneLevel> <set>` every game second (not an
  AUTORUN line); `python game_time.py logs/whole_1.log [s]` gives the game time per chapter and the stretches he stood still. Fixed:
  the ribbon approach walked every point of a way 3 s each with Guybrush not moving (a3r_follow gives up a way after a leg that gets
  nowhere: Timmy at the canyon's mine shaft 12 min, the diving judges 14 min); the ribbon planner tries 5x the cells when it runs out;
  a walk carried off by a trigger (the plank diving's stairs) is planned again instead of following the old legs (75 rounds up and
  down); ar_wait_line_done (EMI) also ends when the dialog stops running (on the raft, a stool, a ship it waited the full 300 s: ten
  times a game, the gate of Mysts o' Tyme 3x, the Lua Bar's stool, Planet Threepwood, Casaba); ar_say / ar_say_exit / a2_pick_any
  give up a line after 3 s of the dialog not running; every line is skipped after AR_LINE_MS (1.5 s) with EXPIRE_TEXT (AR_KEEP_LINES /
  AR_REAL keep them); act2 chapters' fixed sleeps in conversations are a2_ready(name, ms); the rock field's in-set doors end their
  wait when the cell changes (AR_DOOR_STAYS); the school's quiz loop ends with the dunce cap; the lagoon's fishies are swum after
  (ar_chase_offered); ar_approach walks up again to someone who has moved off; ch24 puts the pole down when the raft is at rest;
  ar_raft_exit goes on when the new screen can be steered. act2_06: the flame goes on 2.95 or 3.28 units after the jam, so the lead
  is 3.12 (3.3 failed every time once the stool wait was gone). act2_22: Marco's conversation started by the skipped arrival is
  followed (it failed the run twice today; the fix is not yet through a run that hit it).
  Game time of the whole game: 16843 s before (19931 s this morning), 9399 s after (one run: attempt 1 to act2_22, attempt 2 from 221).
- 2026-11-10 night: the plank diving arrival (Marco's conversation started by the skipped cutscene) stopped every run after the idle
  fixes: during a door's ar_do (AR_DLG_CONTROL) a conversation waiting for a choice counts as the control back (only there: everywhere,
  the poker and act 3 went on in the middle of conversations), and act2_22 follows the conversation. Whole game from a new game in ONE
  attempt: 271 s real, 9983 s of game time. (Careful: a `( run_whole.sh ) &` inside a background command keeps running after it
  returns; two runs at once write the same logs and saves.)
- 2026-11-10 night: movies start (RunFullscreenMovie is the game's own; its loop runs every frame and ends the movie when OVERRIDE is held,
  the skipper holds Escape; AR_NO_MOVIES: the old way). The movies change the game's random numbers, so a new game draws another map
  of Mysts o' Tyme: one whose step after the gate is screen 6's bottom exit (a channel 0.4 wide south of the gate, driven point by
  point: ar_raft_gate_south) and whose last screen is 2 out by the bottom (water only at the end of a narrow channel: ar_raft_cells
  looks through the trigger in quarter units). run_single.sh's resume in Act 1 loads emi_lib/poke/myst again after ar_load (a
  checkpoint carries the old functions). run_emi.sh GDB=1 runs scummvm under gdb (a stack for the rare crash: integer division by zero
  in Audio::Timestamp::msecs, a Timestamp with frame rate 0, EMI sound; seen 4 times on Nov 10, not yet caught). Whole game with the
  movies, one attempt: 9592 s of game time.
  Only stop scummvm.exe whose command line has \emi_autorun\generated\ (a Grim autorun runs the same build at the same time).
- 2026-11-11: walking with the keys: ar_step/ar_steer hold MOVE_FORWARD, TURN_LEFT/RIGHT and RUN through the game's button handler
  (SampleButtonHandler starts the game's move_actor, which walks while the key reads as held; GetControlState is wrapped for the held
  keys). CommonButtonHandler sets stop_idle on any key, so the direct idle stop and set_run are gone (AR_DIRECT_WALK: the old way).
  The wedding ship has its own handler (wed.buttonHandler) in which the walk keys do nothing (the original too). A walk ends when the
  game puts in another handler. act2_19: the walk into the rock field stops at kab.current_loc (walking on, the keys took him out).
- ScummVM bug fixed (autorun 2b5676cf919): EMI GetActorYawToPoint is the turn from the actor's heading (-180..180), as Monkey4.exe
  gives it; ScummVM gave the heading. ar_want_yaw = yaw + the turn (ar_yaw_turn), the raft the same.
- The original exe: run_orig.sh <script> builds the script as run_emi.sh does, wrapped as ScummVM's --autorun wraps it, into
  orig/patch.m4b (hard links to the GOG files in orig/, patch.m4b rebuilt with grimpatch.bin; the original reads Lua only from its
  archives) and runs it with F11 (grimlaunch's f11 patch, postkey.exe). The original runs no script during a movie, so the runner
  presses Escape from outside while a movie plays. The original has no GetFloorHeights (emi_floors.lua from gen_floors.py and
  emi_floors_fn.lua: the same results as the engine's on 8237 lookups) and no LockFont (stubbed in emi_prelude.lua); it prints no
  traceback for a Lua error (STAGE lines mark the libraries). The original runs at about half of real time (simtime 17 ms a frame).
- ScummVM bug fixed (autorun 619de96ff4c): EMI GetSectorOppositeEdge ran Grim's code (nothing without Grim's heading frame), so the
  cheat boxes (bait_hall_cheatbox, west_stair_cheatbox ...) never moved Guybrush in the port: he walked through them. Now as
  Monkey4.exe (0x444780) on the x-z floor; the same landing place as the original within 0.1 (scratch/oe_body.lua, both engines).
  The harness: way points inside a cheat box are skipped (ar_in_cheatbox); stepping aside (now everywhere but the maps) never goes
  into a hot box (ar_hot_near); ar_line_ok samples every 5 cm.
- The original: one function per library/chapter (orig_parts.py: the original cannot parse the whole run as one function); the
  planners let a frame pass every 200 steps there (the original kills a script that runs long without break_here); a resume presses
  F11 twice (the save brings back the task that made it; the first press loads, the second runs the new script, which stops that
  task) and on the original a checkpoint waits 20 s of game time after saving; the run folder's own Monkey4.exe is stopped before
  patch.m4b is written (it holds the archive open). Original: ch01..ch22 pass; ch23 stops at the chess player, as ScummVM does now
  (the walk to him through west_stair_cheatbox).
- 2026-11-11: movies. The original runs Lua during movies (the frame function 0x40be30 calls lua_updatetasks in movie mode; the Bink
  step 0x4226c0 does not block). switch_to_set calls pause_scripts at its start and unpause_scripts at its end, and a set's enter
  can play a movie inside it (Melee dock's mdo.run_opening, the wedding ship's intro_a): every other script is paused then, the
  skipper too. The movie is skipped where the game reads the key: GetControlState of an Escape key reads held while a movie plays
  (emi_lib, AR_NO_SKIP/AR_REAL: they play). ch01 passes on the original in 8 s with no key from outside. (On the original a movie
  plays in real time, in a simulated ScummVM run on the game's clock.) run_emi.sh: GDBCMDS=<file> gives gdb a commands file.
