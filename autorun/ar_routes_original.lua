-- Routes the original's own path search does not find (it needs the way to be short and straight, ScummVM's search is
-- more thorough), planned from the walk sectors with plan_drive.py / plan_route.py and played back with ar_walk_route.
-- Only used on the original: ar_route does nothing under ScummVM.
AR_ROUTES_ORIGINAL = { }

-- From the cafe exterior's door (arrival from the coat check) over the ramp and down to the elevator station
AR_ROUTES_ORIGINAL.ce_to_ev = {
	{ 0.20, -0.80, -0.60 },
	{ 2.10, -0.80, -0.60 },
	{ 3.60, -1.60, -0.60 },
	{ 5.30, -1.90, -1.26 },
	{ 7.00, -2.30, -1.98 },
	{ 5.50, -2.70, -2.48 },
	{ 3.80, -3.00, -3.40 },
	{ 2.00, -3.10, -3.40 },
	{ 0.20, -3.10, -3.40 },
	{ -1.60, -3.10, -3.40 },
	{ -3.40, -3.10, -3.40 },
}

-- Cafe interior: from the liqueur on the lower floor east to the steps and back west on the upper floor to the door
AR_ROUTES_ORIGINAL.cc_to_piano = {
	{ 0.94, 0.28, -0.18 },
	{ 2.21, 0.28, -0.83 },
	{ 3.42, 0.32, -1.40 },
	{ 2.33, 0.66, -1.40 },
	{ 1.39, 1.16, -1.40 },
}
AR_ROUTES_ORIGINAL.piano_to_cc = {
	{ 3.42, 0.32, -1.40 },
	{ 2.21, 0.28, -0.83 },
	{ 0.94, 0.28, -0.18 },
}
AR_ROUTES_ORIGINAL.ci_to_cc = {
	{ 1.39, 1.16, -1.40 },
	{ 2.33, 0.66, -1.40 },
	{ 3.42, 0.32, -1.40 },
	{ 2.21, 0.28, -0.83 },
	{ 0.94, 0.28, -0.18 },
}

-- The routes were made for the walk of the original, which does not find its way over ramps and stairs. The keys follow
-- the path through the sectors (ar_nav.lua) instead: only a route that asks for it (AR_USE_ROUTES) is walked.
ar_route = function(name)
	if AR_USE_ROUTES and AR_ROUTES_ORIGINAL[name] then
		ar_log("route " .. name)
		ar_walk_route(AR_ROUTES_ORIGINAL[name])
	end
end

-- The lounge elevator of the high roller opens when Manny steps into the sector in front of it (hl.elev_open); its
-- walk boxes only exist then, so the original's walk cannot find the way to the door before.
ar_hl_elevator = function()
	if AR_ORIGINAL or AR_NAV then
		ar_walk_to(-0.78, 2.68, 0)
		-- the sentence of the sector runs a moment later and then makes the way to the door
		ar_wait_for(function() return IsSectorActive("hl_elev") end, 5000, "the elevator way to open")
		ar_wait_for_control()
	end
end

-- The first look at the track in a cutscene ends in the track window. The door out of it only reacts when Manny
-- steps into one of its sectors (tw.tb1_box, tw.tb2_box); the original's walk does not go there when the target is
-- the (0, 0, 0) use point of the door.
ar_tw_exit = function()
	ar_wait_for(function() return tb.seen_intro and not find_script(tb.show_room) end, 120000, "the track shown")
	ar_wait_for_control()
	if system.currentSet == tw then
		if AR_ORIGINAL or AR_NAV then
			ar_walk_to(0.78, 0.68, 0)
		end
		ar_go(tw.tb_door, tb)
	end
end

-- The elevator door of the high roller hall opens, and its walk boxes come with it, when Manny steps into the sector in
-- front of it (hh.hl_door_trigger). When he is already in it and the way is not open, he steps out and in again.
ar_hh_elevator = function()
	if (AR_ORIGINAL or AR_NAV) and system.currentSet == hh and not IsSectorActive("hl_door_psg1") then
		-- (the door can be left open from an earlier visit: stepping out of the trigger closes it, stepping in opens it)
		local tries = 0
		while tries < 3 and not IsSectorActive("hl_door_psg1") do
			ar_walk_to(0.0, 0.2, 0)
			ar_walk_to(-0.03, 0.6, 0)
			ar_try_wait(function() return IsSectorActive("hl_door_psg1") end, 3000)
			tries = tries + 1
		end
	end
end

-- Along the extend-o-bridge: its walkways are joined by sectors that carry Manny on to the next one, which the stick
-- follows in ScummVM. The original walks the first leg by its own path and stops when the carrying has happened.
ar_xb_west = function()
	return manny:getpos().x < 33
end
ar_xb_carried = function()
	return manny:getpos().x > 32
end
ar_bridge_east = function()
	if AR_ORIGINAL or AR_NAV then
		ar_walk_to(30.5, -15.5, 1.0, ar_xb_carried)
		ar_wait_for_control()
	end
	AR_STICK = TRUE
	if not AR_ORIGINAL then
		ar_walk_stick(30.5, -15.5, 1.0)
		ar_walk_stick(31.2, -13.5, 1.0)
	end
	ar_walk_stick(36.0, -13.9, 1.5)
	ar_walk_stick(39.9, -13.6, 1.82)
	if AR_ORIGINAL or AR_NAV then
		-- (the walk finds the way over the ramp to the door, the stick runs against the edge of the walkway)
		AR_STICK = nil
	end
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
	ar_walk_to(x, y, z, ar_leg_stop)
end
ar_bridge_west = function()
	if AR_ORIGINAL or AR_NAV then
		ar_walk_leg(36.0, -13.9, 1.5)
		-- (the stick pushes on over the edge of the walkway into the sector that carries Manny)
		ar_walk_stick(30.5, -15.5, 1.0, ar_xb_west)
		ar_wait_for_control()
	else
		AR_STICK = TRUE
		ar_walk_stick(36.0, -13.9, 1.5)
		ar_walk_stick(30.5, -15.5, 1.0)
		AR_STICK = nil
	end
end
