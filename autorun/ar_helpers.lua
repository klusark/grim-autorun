-- Helpers of chapters that the walk (ar_nav.lua) needs a hand with. The same code on both engines.

-- The lounge elevator of the high roller opens when Manny steps into the sector in front of it (hl.elev_open); its
-- walk boxes only exist then.
ar_hl_elevator = function()
	ar_walk_to(-0.78, 2.68, 0)
	-- the sentence of the sector runs a moment later and then makes the way to the door
	ar_wait_for(function() return ar_sector_on("hl_elev") end, 5000, "the elevator way to open")
	ar_wait_for_control()
end

-- The first look at the track in a cutscene ends in the track window. The door out of it only reacts when Manny
-- steps into one of its sectors (tw.tb1_box, tw.tb2_box).
ar_tw_exit = function()
	ar_wait_for(function() return tb.seen_intro and not find_script(tb.show_room) end, 120000, "the track shown")
	ar_wait_for_control()
	if system.currentSet == tw then
		ar_walk_to(0.78, 0.68, 0)
		ar_go(tw.tb_door, tb)
	end
end

-- The elevator door of the high roller hall opens, and its walk boxes come with it, when Manny steps into the sector in
-- front of it (hh.hl_door_trigger). When he is already in it and the way is not open, he steps out and in again.
ar_hh_elevator = function()
	if system.currentSet == hh and not ar_sector_on("hl_door_psg1") then
		-- (the door can be left open from an earlier visit: stepping out of the trigger closes it, stepping in opens it)
		local tries = 0
		while tries < 3 and not ar_sector_on("hl_door_psg1") do
			ar_walk_to(0.0, 0.2, 0)
			ar_walk_to(-0.03, 0.6, 0)
			ar_try_wait(function() return ar_sector_on("hl_door_psg1") end, 3000)
			tries = tries + 1
		end
	end
end

-- Along the extend-o-bridge: its walkways are joined by sectors that carry Manny on to the next one, which the stick
-- follows. The first leg is walked by the planner and stops when the carrying has happened.
ar_xb_west = function()
	return manny:getpos().x < 33
end
ar_xb_carried = function()
	return manny:getpos().x > 32
end
ar_bridge_east = function()
	ar_walk_to(30.5, -15.5, 1.0, ar_xb_carried)
	ar_wait_for_control()
	AR_STICK = TRUE
	ar_walk_stick(30.5, -15.5, 1.0)
	ar_walk_stick(31.2, -13.5, 1.0)
	ar_walk_stick(36.0, -13.9, 1.5)
	ar_walk_stick(39.9, -13.6, 1.82)
	-- (the walk finds the way over the ramp to the door, the stick runs against the edge of the walkway)
	AR_STICK = nil
	ar_go(xb.se_door, se)
	AR_STICK = nil
end

-- A walk that ends when the target is farther away than at the start: Manny has been carried on.
ar_leg_stop = function()
	return point_proximity(AR_LEG_X, AR_LEG_Y, AR_LEG_Z) > AR_LEG_PROX0 + 1.0
end
ar_walk_leg = function(x, y, z)
	AR_LEG_X = x
	AR_LEG_Y = y
	AR_LEG_Z = z
	AR_LEG_PROX0 = point_proximity(x, y, z)
	-- (as far as the floor goes: the sectors of the bridge carry Manny on from there)
	AR_ALLOW_PARTIAL = TRUE
	ar_walk_to(x, y, z, ar_leg_stop)
	AR_ALLOW_PARTIAL = nil
end
ar_bridge_west = function()
	ar_walk_leg(36.0, -13.9, 1.5)
	-- (the stick pushes on over the edge of the walkway into the sector that carries Manny)
	ar_walk_stick(30.5, -15.5, 1.0, ar_xb_west)
	ar_wait_for_control()
end
