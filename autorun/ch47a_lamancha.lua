-- Chapter 47 (Year 3): raising the Lamancha. The crane is run from the crane crusher (cu): lowered at the
-- crusher it lands the scoop on the upper beach, the chisel breaks its chain, then the crane is run along
-- to the conveyor end and lowered, the loose chain falls on the conveyor belt. The lever in the conveyor
-- room moves the chain along the belt, bunched, then wrapped around the Lamancha, and raising the crane
-- brings the ship up (Poseidon cutscene). The belt and the lever are in ch47b_lamancha_belt.lua (checkpoint in slot 90 between them); the chapter ends with checkpoint 63.

AR_NEW = TRUE
ar_load(46)
ar_log("start in " .. ar_set_name())
ar_wait_for_control()

-- 1. the crane lands the scoop on the beach
ar_go(bl.bu_door, bu)
ar_go(bu.cu_door1, cu)
ar_do("use", cu.crane)
ar_wait_for(function() return system.currentSet == ew end, 20000)
ar_wait_for_control()
ar_press_key(ar_real_key("MOVE_BACKWARD"))
ar_wait_for(function() return bu.scoop_here end, 60000)
ar_wait_for(function() return system.currentSet == cu end, 60000)
ar_wait_for_control()
ar_check(bu.scoop_here, "the scoop is on the beach")

-- 2. the chisel breaks its chain
ar_go(cu.bu_door1, bu)
ar_do("use", bu.scoop, mn.chisel)
ar_wait_for(function() return ew.crane_broken end, 60000)
ar_wait_for_control()
ar_check(ew.crane_broken, "the crane chain is broken")

-- 3. the crane is run to the conveyor and lowered
ar_go(bu.cu_door1, cu)
ar_do("use", cu.crane)
ar_wait_for(function() return system.currentSet == ew end, 20000)
ar_wait_for_control()
ar_key_down("TURN_RIGHT")
ar_wait_for(function() return ew.crane_actor.cur_point == 0 end, 120000)
ar_keys_up()
sleep_for(1500)
ar_press_key(ar_real_key("MOVE_BACKWARD"))
ar_wait_for(function() return ew.crane_down and system.currentSet == ew and cutSceneLevel <= 0 end, 120000)
ar_check(cv.chain_bunched, "the chain lies bunched on the conveyor")
ar_press_key(ar_real_key("USE"))
ar_wait_for(function() return system.currentSet == cv end, 30000)
ar_wait_for_control()
ar_state("end of the first half of chapter 47")
ar_checkpoint(47)
