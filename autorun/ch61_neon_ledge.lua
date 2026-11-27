-- Chapter 61 (Year 4): the Neon Ledge (nl). Along the ledge and up to the roof, Manny hops onto the border below the
-- neon hand, uses the grinder on the cracked gargoyle and then the Sproutella: the neon lady falls (puzzle
-- state 59). Down the sign's ladder and the El Depot movie leads to the meadow (me). Checkpoint in slot 77.

AR_NEW = TRUE
AR_CONTROL_TIMEOUT = 600000
ar_load(61)
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
-- along the ledge to the hot sector that leads up to the roof
ar_walk_to(0.1, 1.95, -0.02, function() return cutSceneLevel > 0 or manny:getpos().z > 1 end)
ar_wait_idle(200)
ar_wait_for_control()
ar_check(manny:getpos().z > 3, "Manny is on the roof")
-- (100% modes: the far end of the roof, the high angle on the neon lady, nl_neoha: only while she still stands, it is the fallen sign's view after she falls)
if AR_FULL then
	ar_walk_to(-3.0, 6.0, 3.71, function() return nl:current_setup() == nl_neoha end, 30000)
	ar_log("on the roof: setup " .. tostring(nl:current_setup()))
end
-- (the hop onto the border can come on the way there: the hot sector at the edge is along it, and a turn at the edge can take Manny
-- into it; the walk below is done then)
ar_walk_to(-7.5, 2.3, 3.71, function() return cutSceneLevel > 0 or manny:getpos().z > 4 end)
ar_wait_idle(200)
ar_wait_for_control()
-- the hot sector at the edge is where Manny hops on to the border by the neon hand
ar_walk_to(-7.5, 1.85, 3.71, function() return cutSceneLevel > 0 or manny:getpos().z > 4 end)
ar_wait_idle(200)
ar_wait_for_control()
ar_check(manny:getpos().z > 4, "Manny is on the border")
ar_do("use", nl.gargoyle, th.grinder)
ar_wait_for_control()
ar_check(nl.gargoyle.boned, "the gargoyle is ground")
ar_do("use", nl.gargoyle, fi.sproutella)
ar_wait_for(function() return cur_puzzle_state[59] end, 120000)
ar_wait_for_control()
ar_check(cur_puzzle_state[59], "the neon lady falls (puzzle state 59)")
ar_do("use", nl.sign_ladder)
ar_wait_for(function() return system.currentSet == me end, 300000)
ar_wait_for_control()
ar_expect_set(me, "in the meadow")
AR_CONTROL_TIMEOUT = nil
ar_state("end of chapter 61")
ar_checkpoint(62)
