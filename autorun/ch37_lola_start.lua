-- Chapter 37 (Year 3): the ship Lola. Down the hatch and the ladder, the hit squad's ambush ends in
-- the engine room with Glottis. The anchors: the ship is steered to the ocean side (lever, right),
-- the starboard anchor is raised and lowered again so that it hooks the port anchor under the
-- ship, raised again and hooked to the porthole with the scythe; the port button pulls: the ship
-- rips from the pier. Reverse: the hydrofoil. Checkpoint in slot 53.

ar_load(36)
AR_NEW = TRUE
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
ar_go(lz.il_door, il)
sleep_for(3000)
ar_wait_for_control()
-- down the ladder at the end of the deck, then across the lower deck, where the hit squad's trigger springs the ambush
-- that ends in the engine room
ar_walk_to(il.ladder.use_pnt_x, il.ladder.use_pnt_y, il.ladder.use_pnt_z, function() return manny:getpos().z < 0.9 or system.currentSet ~= il end)
ar_wait_for_control()
if system.currentSet == il then
	ar_walk_to(0.0, -2.0, 0, function() return cutSceneLevel > 0 or system.currentSet ~= il end)
end
ar_wait_for(function() return system.currentSet == ei end, 120000)
ar_wait_for_control()
ar_state("in the engine room")

local drive = function(control)
	ar_key_down(control)
	sleep_for(150)
	ar_key_up(control)
	ar_wait_for_control()
	sleep_for(500)
	ar_wait_for_control()
end

-- take the levers and steer to the ocean side
ar_do("use", ei.left_control)
ar_wait_for(function() return system.buttonHandler == engineButtonHandler end, 60000)
ar_check(system.buttonHandler == engineButtonHandler, "Manny has the controls")
drive("TURN_RIGHT")
ar_check(ei.boat_state == "ocean", "the ship is on the ocean side")
ar_press("use")
ar_wait_for(function() return system.buttonHandler == SampleButtonHandler end, 60000)
ar_wait_for_control()

-- the starboard anchor up, down (hooks the port one), up again
local press = function(button)
	ar_do("use", button)
	ar_wait_for_control()
	sleep_for(500)
	ar_wait_for_control()
end
press(ei.dp_button)
ar_check(ei.sa.state == "up", "the starboard anchor is up")
press(ei.dp_button)
ar_check(ei.anchors_hooked, "the anchors are hooked together")
press(ei.dp_button)
ar_check(ei.sa.state == "up", "the starboard anchor is up again")

-- the anchor shows at the dock porthole: the scythe hooks it to the ship's side
ar_go(ei.dp_door, dp)
ar_wait_for_control()
ar_do("use", dp.anchor, mo.scythe)
ar_wait_for(function() return ei.pa.state == "portholed" end, 120000)
ar_wait_for_control()
ar_check(ei.pa.state == "portholed", "the anchor is hooked to the porthole")
ar_go(dp.ei_door, ei)
ar_wait_for_control()
-- the port button pulls: the ship tears loose from the pier
press(ei.op_button)
ar_wait_for(function() return ei.ship_ripped end, 300000)
ar_wait_for_control()
ar_check(ei.ship_ripped, "the ship has torn loose")
-- reverse, out to sea
ar_do("use", ei.left_control)
ar_wait_for(function() return system.buttonHandler == engineButtonHandler end, 60000)
drive("MOVE_BACKWARD")
-- (the escape cutscene can be over by the time the controls answer again: its first step sets the puzzle state)
ar_wait_for(function() return find_script(cut_scene.hydrfoil) or cur_puzzle_state[33] end, 60000)
ar_wait_for(function() return not find_script(cut_scene.hydrfoil) and cutSceneLevel == 0 end, 900000)
ar_wait_for_control()
ar_state("end of chapter 37")
ar_checkpoint(37)
