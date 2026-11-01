-- Helpers of chapters that the walk (ar_nav.lua) needs a hand with. The same code on both engines.

-- The lounge elevator of the high roller opens when Manny steps into the sector in front of it (hl.elev_open); its
-- walk boxes only exist then.
ar_hl_elevator = function()
	local tries = 0
	local open = nil
	while not open and tries < 2 do
		ar_walk_to(-0.78, 2.68, 0)
		-- the sentence of the sector runs a moment later and then makes the way to the door
		open = ar_try_wait(function() return ar_sector_on("hl_elev") end, 3000)
		if not open then
			-- (Manny came in at the spot, already in the sector, so that walking in did nothing: out to the place where Nick stands, and in again)
			ar_walk_to(hl.virago_obj.use_pnt_x, hl.virago_obj.use_pnt_y, hl.virago_obj.use_pnt_z)
		end
		tries = tries + 1
	end
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
