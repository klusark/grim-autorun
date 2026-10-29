-- Chapter 27: the wine cellar forklift. It is driven (held keys) into the elevator car and parked
-- facing the grating; the button sends the car up, Manny jumps back on the forklift and holds the
-- drive key so it slides into the stuck trigger: the car jams between floors. The lever raises the
-- blades and the grating opens on the hidden hall, where the suitcase holds the union card.
-- Checkpoint in slot 43.

ar_load(26)
AR_NEW = TRUE
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
-- round the north side of the forklift: the walk sectors run straight through it
ar_walk_to(0.8, -1.2, 0)
ar_walk_to(1.7, -1.9, 0)
ar_walk_to(1.42, -2.3, 0)
ar_do("use", wc.forklift)
ar_check(manny.is_driving, "Manny drives the forklift")
ar_drive_to(1.4, -0.3, 0, 0.3, 40000, function() return system.currentSet == de end, de.forklift_actor)
ar_drive_to(1.45, 0.95, 0, 0.3, 40000, function() return system.currentSet == de end, de.forklift_actor)
ar_wait_for_control()
ar_check(system.currentSet == de, "the forklift is in the elevator")
-- parked by the north wall, facing the heading the jam needs, close enough to get out
ar_drive_to(-0.5, -0.05, 0, 0.1, 30000, nil, de.forklift_actor)
ar_turn_vehicle(de.forklift_actor, 90, 2, 20000)
ar_press("use")
ar_wait_for(function() return not manny.is_driving end, 30000)
ar_wait_for_control()
ar_check(not manny.is_driving, "Manny got off the forklift")
-- the car goes up, Manny jumps on and drives into the trigger
ar_do("use", de.button)
-- (the car is on its way up: no time for the walk and the waits of ar_do, the forklift is a step away from the button)
ar_face(de.forklift)
ar_press("use")
ar_wait_for(function() return manny.is_driving end, 20000)
ar_check(manny.is_driving, "Manny is on the forklift again")
AR_TV = ar_turn_vehicle(de.forklift_actor, 90, 2, 10000)
AR_FP = de.forklift_actor:getpos()
ar_log("FORK turned " .. tostring(AR_TV) .. ": " .. AR_FP.x .. " " .. AR_FP.y .. " rot " .. de.forklift_actor:getrot().y .. " shaft z " .. de.shaft:getpos().z .. " floor " .. tostring(de.shaft.floor))
ar_key_down("MOVE_FORWARD")
sleep_for(3000)
AR_FP = de.forklift_actor:getpos()
ar_log("FORK after 3 s: " .. AR_FP.x .. " " .. AR_FP.y .. " rot " .. de.forklift_actor:getrot().y .. " shaft z " .. de.shaft:getpos().z .. " floor " .. tostring(de.shaft.floor))
AR_N = 0
while AR_N < 15 and not de.shaft.stuck do
	ar_try_wait(function() return de.shaft.stuck end, 4000)
	AR_FP = de.forklift_actor:getpos()
	ar_log("FORK at " .. AR_FP.x .. " " .. AR_FP.y .. " rot " .. de.forklift_actor:getrot().y .. " shaft z " .. de.shaft:getpos().z .. " floor " .. tostring(de.shaft.floor) .. " fb4 " .. tostring(ar_sector_on("fork_box4")) .. " st " .. tostring(ar_sector_on("fork_stuck_trig")) .. " in " .. tostring(de.forklift_actor:find_sector_name("fork_stuck_trig")))
	AR_N = AR_N + 1
end
ar_keys_up()
ar_check(de.shaft.stuck, "the elevator is jammed")
ar_press("use")
ar_wait_for(function() return not manny.is_driving end, 30000)
ar_wait_for_control()
-- the forklift stands between Manny and the lever: go round its tail
ar_walk_to(0.7, 0.2, 0)
ar_walk_to(0.7, -0.9, 0)
ar_walk_to(-0.5, -0.9, 0)
AR_FP = de.forklift_actor:getpos()
ar_log("PRE forklift " .. AR_FP.x .. " " .. AR_FP.y .. " rot " .. de.forklift_actor:getrot().y .. " lever " .. de.lever.obj_x .. " " .. de.lever.obj_y .. " use " .. de.lever.use_pnt_x .. " " .. de.lever.use_pnt_y)
ar_do("use", de.lever)
ar_wait_for(function() return de.shaft.floor == "secret_hallway" end, 60000)
ar_wait_for_control()
ar_check(de.shaft.floor == "secret_hallway", "the grating is open on the hidden hall")
-- the forklift slides back off the blades by itself (a cutscene) and shoves what is in its way: a player waits for it
sleep_for(1500)
ar_wait_for(function() return not find_script(de.forklift_actor.slide_out) end, 30000)
ar_wait_for_control()
-- Manny stands at the lever inside the forklift's collision box: his first step throws him along its side to the far end,
-- by the open grating. From there it is south and then east, into the grating
AR_N = 0
while AR_N < 120 and system.currentSet == de do
	if not ar_steer(-0.95, -0.9, 0, 4) then
		manny:walk_forward()
	end
	break_here()
	AR_N = AR_N + 1
end
if system.currentSet == de then
	-- (the forklift boxes Manny in at the corner: he tries the eight ways in turn, east first, until one takes him into the grating)
	AR_H = 90
	while AR_H < 90 + 720 and system.currentSet == de do
		AR_P1 = manny:getpos()
		AR_N = 0
		while system.currentSet == de and ar_steer(AR_P1.x + 0.5 * cos(AR_H + 90), AR_P1.y + 0.5 * cos(AR_H), 0, 3) and AR_N < 200 do
			break_here()
			AR_N = AR_N + 1
		end
		AR_N = 0
		while AR_N < 6 and system.currentSet == de do
			manny:walk_forward()
			break_here()
			AR_N = AR_N + 1
		end
		AR_P2 = manny:getpos()
		AR_H = AR_H + 45
	end
end
ar_expect_set(dh, "Manny walks out through the grating")
ar_wait_for_control()
ar_do("use", dh.suitcase)
ar_wait_for(function() return hh.union_card.owner == manny end, 600000)
ar_wait_for_control()
ar_check(hh.union_card.owner == manny, "Manny has the union card")
ar_state("end of chapter 27")
ar_checkpoint(27)
