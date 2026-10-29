-- Chapter 48 (Year 3): the coral crusher. The crane is run from the crane crusher, lowered (the chain
-- spills on the crusher) and raised, which rips the crusher out. Glottis calls it good, the whole crew sails
-- (Exodus cutscene), which ends aboard the Lamancha's sub (the Bloodeye cutscene is chapter 49). Checkpoint in slot 64.

AR_NEW = TRUE
ar_load(48)
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
-- Glottis stands on the straight way to the stairs: round his south side
ar_walk_to(3.9, -27.5, 0)
ar_walk_to(2.4, -28.2, 0)
ar_go(bl.bu_door, bu)
ar_go(bu.cu_door1, cu)
ar_do("use", cu.crane)
ar_wait_for(function() return system.currentSet == ew end, 20000)
ar_wait_for_control()
ar_press_key(ar_real_key("MOVE_BACKWARD"))
ar_wait_for(function() return ew.crane_down and system.currentSet == ew and cutSceneLevel <= 0 end, 120000)
ar_check(ew.crane_down, "the crane is down at the crusher")
ar_press_key(ar_real_key("MOVE_FORWARD"))
ar_wait_for(function() return crusher_free end, 120000)
ar_check(crusher_free, "the crusher is free")
ar_wait_for(function() return cur_puzzle_state[45] end, 300000)
ar_check(cur_puzzle_state[45], "the Exodus cutscene runs (puzzle state 45)")
-- the cutscene ends aboard the Lamancha's sub, where the next chapter fights Domino
ar_wait_for(function() return system.currentSet == lu end, 300000)
ar_wait_for_control()
ar_state("end of chapter 48")
ar_checkpoint(49)
