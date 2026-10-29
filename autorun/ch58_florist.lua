-- Chapter 58 (Year 4): the florist's shop (fp, fi). Bowlsley is raving mad because of the bell taped to the door; the
-- scythe cuts the tape (puzzle state 50), Manny leaves and comes back, and Bowlsley, happy now, gives Manny the gun and
-- the can of Sproutella (puzzle state 54). Checkpoint in slot 74.

AR_NEW = TRUE
AR_CONTROL_TIMEOUT = 300000
ar_load(58)
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
-- the florist's hatch is a hot sector on the ground in front of the ladder
ar_walk_to(-0.15, -0.85, 0, function() return cutSceneLevel > 0 end)
ar_wait_for(function() return system.currentSet == fp end, 30000)
ar_wait_for_control()
-- (he arrives on the ladder and climbs up it to the street)
ar_climb(TRUE, function() return not manny.is_climbing end, 40000)
ar_wait_for_control()
ar_expect_set(fp, "outside the florist shop")
ar_go(fp.fi_door, fi)
ar_wait_for_control()
ar_describe()
ar_do("use", fi.bell, mo.scythe)
ar_wait_for(function() return cur_puzzle_state[50] end, 120000)
ar_wait_for_control()
ar_check(cur_puzzle_state[50], "the bell is free of its tape (puzzle state 50)")
ar_expect_set(fp, "outside the shop")
-- (the game takes Manny through the shop and on into the sewer while he is going in: the shop was reached)
AR_SEEN_STICKY = TRUE
ar_go(fp.fi_door, fi)
AR_SEEN_STICKY = nil
ar_wait_for(function() return cur_puzzle_state[54] end, 300000)
ar_wait_for_control()
ar_check(cur_puzzle_state[54], "Bowlsley gave Manny the gun and the Sproutella (puzzle state 54)")
ar_check(fi.gun.owner == manny and fi.sproutella.owner == manny, "Manny has the gun and the Sproutella")
AR_CONTROL_TIMEOUT = nil
ar_state("end of chapter 58")
ar_checkpoint(59)
