-- Chapter 57 (Year 4): Manny drives the Bone Wagon with its remote control in the Albinizod tunnel. The wagon is
-- raised (remote) and driven forward until it stops, Manny steps out on the catwalk, climbs down the ladder,
-- which wakes Albinizod, climbs back up, and lowers the wagon on the gator (puzzle state 53). Then down
-- the ladder and out to the florist. Checkpoint in slot 73.

AR_NEW = TRUE
AR_CONTROL_TIMEOUT = 300000
ar_load(57)
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
ar_check(system.buttonHandler == at_bw_handler, "Manny rides in the Bone Wagon")

-- the remote: the inventory key takes it out, "use" raises (or lowers) the wagon, the same key puts it away
ar_press_key(ar_real_key("INVENTORY"))
sleep_for(1000)
ar_wait_for_control()
ar_check(manny.is_holding == sh.remote, "Manny holds the remote")
ar_press_key(ar_real_key("USE"))
sleep_for(1000)
ar_wait_for_control()
ar_check(glottis.bonewagon_up, "the Bone Wagon is raised")
ar_key_down("MOVE_FORWARD")
ar_wait_for(function() return glottis:find_sector_name("close_enough") end, 60000)
sleep_for(500)
ar_keys_up()
ar_press_key(ar_real_key("INVENTORY"))
sleep_for(1500)
ar_wait_for_control()
-- with the hands empty "use" is the jump on to the catwalk
ar_press_key(ar_real_key("USE"))
sleep_for(1000)
ar_wait_for_control()
ar_check(system.buttonHandler == SampleButtonHandler, "Manny is on the catwalk")
ar_hold(sh.remote)
ar_walk_to(0.62, 0.5, 1.3)
ar_walk_to(at.ladder_top.use_pnt_x, at.ladder_top.use_pnt_y, at.ladder_top.use_pnt_z, function() return manny.is_climbing or cutSceneLevel > 0 end)
sleep_for(2500)
ar_wait_for_control()
ar_check(manny.is_climbing, "Manny climbs down the ladder, Albinizod wakes up")
ar_check(zod_set_to_pin, "Albinizod is ready to be pinned")
-- back up again, before he runs at Manny, and the wagon comes down on him
ar_climb(TRUE, function() return not manny.is_climbing end, 30000)
sleep_for(2500)
ar_wait_for_control()
ar_hold(sh.remote)
ar_press("use")
ar_wait_for(function() return albinizod_pinned end, 30000)
ar_wait_for_control()
ar_check(cur_puzzle_state[53], "the Bone Wagon pins Albinizod (puzzle state 53)")

-- now down the ladder for good and to the florist's hatch
ar_walk_to(at.ladder_top.use_pnt_x, at.ladder_top.use_pnt_y, at.ladder_top.use_pnt_z, function() return manny.is_climbing or cutSceneLevel > 0 end)
sleep_for(2500)
ar_wait_for_control()
ar_climb(nil, function() return not manny.is_climbing end, 60000)
sleep_for(1500)
ar_wait_for_control()
AR_CONTROL_TIMEOUT = nil
ar_state("end of chapter 57")
ar_checkpoint(58)
