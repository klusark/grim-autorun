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

(MSYS2 UCRT64 shell, scummvm from ~/scummvm/build, TS=100 for normal speed, AR_WALK=TRUE in a
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
| ch08_signpost_nav | 22 | out of the Bone Wagon, the loosened signpost, planted at the point in the navigation room: the trapdoor opens | 23 |
| ch13_plunge | 28 | Rubamat plunge, Celso, photo to Velasco, logbook, job | 29 |
| ch14_velasco | 29 | Rubacava: Lupe, shanghaied to Limbo, Velasco lists the goals | 30 |
| ch15_letters_book | 30 | letters from the cafe office, the Blue Casket revolutionaries give their book | 31 |
| ch16_terry | 31 | book to the dock workers' foreman, Terry arrested | 32 |
| ch17_charlie | 32 | Charlie: ticket printer and the V.I.P. pass | 33 |
| ch18_hotel_pass | 33 | liqueur, across town, the pass past Raoul into the high roller lounge | 34 |

| ch19_baster | 34 | baster from the kitchen, the Blue Casket kiss cutscene, dishwater from the sink | 35 |
| ch20_naranja | 35 | the ship: fridge and crisper open, baster into the booze, sailor out, dog tags | 36 |
| ch21_carla | 36 | liqueur at the security lobby, Carla charmed, the detector into the cat box | 37 |
| ch22_cat_litter | 37 | the can opener, the scythe finds the detector in the litter | 38 |
| ch23_morgue | 38 | detector to Membrillo, dog tags on the corpse: vacancy | 39 |
| ch24_glottis_pass | 39 | the pass to Glottis (gambling) | 40 |
| ch25_to_kitchen | 40 | across town to the high roller kitchen | 41 |
| ch26_stowaway | 41 | Raoul trapped in the pantry with the scythe, opener, Manny in the cask | 42 |
| ch27_forklift_card | 42 | forklift into the elevator, jam it, lever, hidden hall: union card | 43 |
| ch28_cigcase | 43 | Nick's threats, he leaves, the cigarette case | 44 |
| ch29_bomb_key | 44 | the case is a bomb for Carla's safe: skeleton key | 45 |
| ch30_lighthouse | 45 | the key opens the lighthouse, Lola, the card | 46 |
| ch31_jacket | 46 | the card to Lupe, jacket, slip of paper | 47 |
| ch32_photofinish | 47 | the paper to Toto: photo finish | 48 |
| ch33_ticket | 48 | the ticket printer set to race 6 day 2 week 2 | 49 |
| ch34_blackmail | 49 | photo window, blackmail photo, Nick: the strike | 50 |
| ch35_velasco_done | 50 | Velasco is told everything is done | 51 |
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

| ch40-ch45 | 56-61 | Year 3 vault tools, safe | 61 |
| ch46_meche_freed | 61 | close vault door, scythe on tab opens the secret door, drag the axe to the tile in the vault interior | 62 |
| ch47_lamancha | 62 | crane scoop, chisel breaks chain, chain on conveyor, lever x3, raise crane: Lamancha | 63 |
| ch48_crusher | 63 | crane rips out the coral crusher, Exodus | 64 |
| ch49_bloodeye | 64 | scythe in the octopus eye, Year 4 begins in bs | 65 |
| ch50_mug_rocket | 65 | Year 4: mug from Bruno's casket, gate keeper's note, rag, oily rag, toaster fire sets the mug rack off | 66 |
| ch51_bonewagon | 66 | nitrogen (Toto), ship bottle (Velasco), keg, Glottis throws up gelatin, freeze, dynamite: Bone Wagon goes | 67 |
| ch52_pigeon | 67 | arm, photo, note + photo to the pigeon, Bowlsley eats it | 68 |
| ch53_sewer | 68 | Meche's plan, ladder to the sewer hub, remote | 69 |
| ch54_thunderboys | 69 | coffee on the Thunderboys, arm in the grinder, dressing room | 70 |
| ch55_charlie | 70 | casino lobby: agent, Meche's sheet, Charlie, jackpot | 71 |
| ch56_albinizod | 71 | men's room, grinder trail through the sewer to Albinizod | 72 |
| ch57_albinizod | 72 | Bone Wagon with the remote, pin Albinizod, down the ladder | 73 |
| ch58_florist | 73 | untape the bell, Bowlsley gives the gun and the Sproutella | 74 |
| ch59_keno | 74 | Brennis keno question, elevator to Hector's foyer | 75 |
| ch60_celso | 75 | Celso sells the ticket, the old job | 76 |
| ch61_neon_ledge | 76 | gargoyle with grinder + Sproutella, neon lady falls, meadow | 77 |
| ch62_greenhouse_door | 77 | greenhouse door, shot, nitrogen on the wound | 78 |
| ch63_salvador | 78 | Salvador's head says goodbye | 79 |
| ch64_ticket_gun | 79 | suitcase ticket, body, key, gun, tanks fall on Hector | 80 |
| ch65_ending | 80 | greenhouse door, the end, credits | - |

The whole game, new game to credits, is scripted (ch01 - ch65).
