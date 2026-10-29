-- Chapter 54 (Year 4): down the ladder of the sewer hub (sh) into the theater sewer (te), up the ladder into the
-- theater backstage (th). Manny pours the pot of coffee over the Thunderboys from the rafters and puts it
-- back on its burner, puts the arm into the snow machine's grinder and takes the grinder, then walks into the
-- dressing room, which makes him a Thunderboy (puzzle state 55). Checkpoint in slot 70.

AR_NEW = TRUE
ar_load(54)
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
ar_go(sh.te_door, te)
ar_wait_for_control()
ar_climb(nil, nil, 40000)
ar_wait_for_control()
ar_expect_set(te, "in the theater sewer")

-- the ladder up: walking into its foot starts the climb, then the player holds "up"
local b = te.th_ladder.base
AR_WALK = TRUE
manny:set_run(FALSE)
ar_walk_to(b.use_pnt_x, b.use_pnt_y, b.use_pnt_z, function() return manny.is_climbing end)
ar_wait_for(function() return manny.is_climbing end, 20000)
ar_check(manny.is_climbing, "Manny is on the ladder")
ar_climb(TRUE, function() return system.currentSet == th end, 60000)
AR_WALK = nil
ar_wait_for_control()
ar_expect_set(th, "in the theater backstage")

ar_do("pickUp", th.coffee_pot)
ar_wait_for_control()
ar_check(th.coffee_pot.owner == manny, "Manny has the pot of coffee")
ar_do("use", th.ladder_bot, th.coffee_pot)
ar_wait_for_control()
ar_do("use", th.thunderboys_from_above, th.coffee_pot)
ar_wait_for(function() return th.boys_gone end, 120000)
ar_wait_for_control()
ar_check(th.boys_gone, "the Thunderboys ran off")
ar_do("use", th.ladder_top, th.coffee_pot)
ar_wait_for_control()
-- (the planned way down the ladder to the burners makes the game start the dressing room scene: the walk of the game itself
-- does not)
AR_NO_NAV = TRUE
ar_do("use", th.coffee_rack, th.coffee_pot)
AR_NO_NAV = nil
ar_wait_for_control()
ar_check(not manny.is_holding, "the pot is back on its burner")
ar_do("use", th.ladder_bot)
ar_wait_for_control()
ar_do("use", th.snow_machine, nq.arm)
ar_wait_for(function() return th.grinder.has_bone end, 60000)
ar_wait_for_control()
ar_do("pickUp", th.snow_machine)
ar_wait_for_control()
ar_check(th.grinder.owner == manny and th.grinder.has_bone, "Manny has the grinder with the arm in it")
ar_do("use", th.ladder_top)
ar_wait_for_control()

-- the dressing room is a hot sector at the end of a narrow walkway
ar_walk_to(0.894, -1.075, -0.29)
AR_STICK = TRUE
ar_walk_to(1.45, -1.158, -0.29, function() return cutSceneLevel > 0 end)
AR_STICK = nil
ar_wait_for(function() return manny.thunder end, 60000)
ar_wait_for_control()
ar_check(cur_puzzle_state[55], "Manny is a Thunderboy (puzzle state 55)")
ar_state("end of chapter 54")
ar_checkpoint(55)
