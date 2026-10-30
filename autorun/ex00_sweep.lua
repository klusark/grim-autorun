-- Where the look at everything of a 100% run (ar_sweep in ar_full.lua) breaks the story, found by running it. Each line says what happened.

AR_NO_SWEEP["Hallway"] = "the elevators change the walk floor when they are looked at"
AR_NO_LOOK["file cabinet"] = "looking at it in the office closes the hallway elevator to the garage (the game sends the walk back)"
AR_NO_SWEEP["signpost fork"] = "the chapter walk after it is planned again 7 times and held up (chapter 7)"
AR_NO_SWEEP["cafe interior"] = "a chapter failed after the sweep: use /cctx049/Lupe is not offered to the player: touchable=1 range=0.8 proximity=0.792336 seen[/cctx078/distrac"
AR_NO_SWEEP["cafe office"] = "a chapter failed after the sweep: use /cctx049/Lupe is not offered to the player: touchable=1 range=0.8 proximity=0.79258 seen[/cctx078/distract"
AR_NO_SWEEP["Blue Casket interior"] = "a chapter failed after the sweep: timed out after 1000 ms waiting for the set Blue Casket Exterior"
AR_NO_SWEEP["Kitty Hallway"] = "a chapter failed after the sweep: timed out after 1000 ms waiting for the set kitty stable"
AR_NO_SWEEP["vault door"] = "a chapter failed after the sweep: nav: no way from -3.45 0.51 to 0.48 2.09 in temp factory hub for 18 seconds"
AR_NO_SWEEP["anchor room"] = "a chapter failed after the sweep: the keys of the verbs are off (Manny hangs on the chain, floats): use lit pathway"
AR_NO_SWEEP["miners"] = "a chapter failed after the sweep: nav: no way from 3.10 -3.83 to 0.99 -0.17 in anchor room for 18 seconds"
AR_NO_SWEEP["sewer hub"] = "chapter 54 failed after the sweep in the whole game (nav: no way from 0.78 -0.36), though it passes from its save"
AR_NO_SWEEP["Neon Ledge"] = "the sweep strands Manny on the ledge (nav: no way) and chapter 61 starts from there"
