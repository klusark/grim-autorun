-- Chapter 12 (Year 2): the beaver room's gate leads to the beaver dam, where burning beavers
-- chase Manny off the first time. Fetch bones from the dam (outside the beavers' death zone),
-- go along the rock trail to the tar river and, for each beaver: throw a bone into the tar, the
-- beaver dives for it and flies up out of the tar, and the fire extinguisher, sprayed at it
-- as it flies, freezes it so that it sinks. Three beavers end the fight (puzzle states 14, 15).
-- Back in the beaver room the key opens the padlock, and with it Year 2 ends. Checkpoint in slot 28.

-- The way to the dam is two strips of floor only 2.5 cm wide: gate_box (x -6.425 to -6.4, north from y -3.325) and sect_14 after it
-- (north-west to the door). The planner's points come from its cells and lie on the edge of the strip, not on its middle line,
-- so Manny was aimed at the wall beside the opening and got in only now and then (the original too: held up twice, 2026-11-27).
-- A player lines him up: south of the opening on the middle line, the turn key tapped a step at a time until he faces along the
-- strip (the body is let come to rest after each tap), straight in; the same at the bend.
AR_BV_GATE_X = -6.4125
ar_bv_tap_face = function(x, y, z)
	local t = 0
	local taps = 0
	while t < 8000 and taps < 40 do
		local d = GetActorYawToPoint(manny.hActor, x, y, z) - manny:getrot().y
		d = d - 360 * floor(d / 360 + 0.5)
		local dir = 1
		if d < 0 then
			dir = -1
		end
		if abs(d) > 10 then
			-- (held while far off)
			TurnActor(manny.hActor, dir)
		elseif manny:is_turning() then
			-- (the body still follows the last step)
		elseif abs(d) <= 1 then
			return TRUE
		else
			TurnActor(manny.hActor, dir)
			taps = taps + 1
		end
		break_here()
		t = t + system.frameTime
	end
	return nil
end

-- straight on with the walk key until cond() or he stands still (max_ms at most)
ar_bv_walk_on = function(cond, max_ms)
	local t = 0
	local still = 0
	local last = manny:getpos()
	while not cond() and t < max_ms and still < 20 do
		manny:walk_forward()
		break_here()
		t = t + system.frameTime
		local p = manny:getpos()
		if abs(p.x - last.x) + abs(p.y - last.y) < 0.0005 then
			still = still + 1
		else
			still = 0
		end
		last = p
	end
end

ar_bv_through_gate = function()
	local z = manny:getpos().z
	AR_HOP_TOL = 0.01
	ar_walk_to(AR_BV_GATE_X, -3.55, z)
	AR_HOP_TOL = nil
	AR_NEAR_SLOW = TRUE
	manny:set_run(FALSE)
	ar_bv_tap_face(AR_BV_GATE_X, -3.2, z)
	ar_bv_walk_on(function() return manny:getpos().y > -3.13 or system.currentSet ~= bv end, 4000)
	if system.currentSet == bv then
		ar_bv_tap_face(-6.5125, -2.95, z)
		ar_bv_walk_on(function() return system.currentSet ~= bv end, 4000)
	end
	AR_NEAR_SLOW = nil
	local p = manny:getpos()
	ar_log("bv gate: " .. tostring(system.currentSet.setFile) .. " at " .. format("%.3f %.3f", p.x, p.y))
end

ar_load(11)
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
-- the gate, Glottis, the beavers chase Manny out of the dam
ar_do("use", bv.gate)
ar_wait_for(function() return bd.beavers.met and system.currentSet == bv and cutSceneLevel == 0 end, 300000)
ar_check(bd.beavers.met, "the beavers have chased Manny out once")
ar_bv_through_gate()
if system.currentSet == bv then
	ar_go(bv.bd_door, bd)
end

-- three bones from the dam, which is outside the death zone
ar_do("pickUp", bd.dam)
ar_do("pickUp", bd.dam)
ar_do("pickUp", bd.dam)
ar_check(ar_find_owned(sp.bones), "Manny has bones")

-- the rock trail to the tar river
ar_walk_to(2.76, 4.02, 0.2, function() return bd:current_setup() == bd_rckws end)
ar_wait_for_control()

ar_state("at the tar river")
AR_BEAVER = 1
AR_TRIES = 0
while not bd.all_beavers_dead and AR_TRIES < 12 do
	AR_TRIES = AR_TRIES + 1
	ar_log("beaver round " .. AR_TRIES .. ", dead: " .. (bone_beaver[1].dead and "1" or "0") .. (bone_beaver[2].dead and "1" or "0") .. (bone_beaver[3].dead and "1" or "0"))
	-- the bone into the tar
	ar_do("use", bd.tar, ar_find_owned(sp.bones))
	-- the beaver walks to the bone and dives, meanwhile the extinguisher is taken out and aimed
	if ar_hold(bd.extinguisher) then
		-- (turned toward the tar pit with the turn keys, a few seconds at most)
		AR_TURNED = 0
		while TurnActorTo(manny.hActor, 4.69902992, 2.43168998, -0.2) and AR_TURNED < 3000 do
			break_here()
			AR_TURNED = AR_TURNED + system.frameTime
		end
		ar_press("use")
		-- sprays until the beaver has flown up and stuck, or has dived back in
		AR_DEAD_BEFORE = 0
		if bone_beaver[1].dead then AR_DEAD_BEFORE = AR_DEAD_BEFORE + 1 end
		if bone_beaver[2].dead then AR_DEAD_BEFORE = AR_DEAD_BEFORE + 1 end
		if bone_beaver[3].dead then AR_DEAD_BEFORE = AR_DEAD_BEFORE + 1 end
		ar_wait_for(function() return not bd.beaver_in_the_air and (bone_beaver[1].dead and 1 or 0) + (bone_beaver[2].dead and 1 or 0) + (bone_beaver[3].dead and 1 or 0) > AR_DEAD_BEFORE end, 90000)
		-- let go of the key
		system.buttonHandler(ar_key_for("use"), nil, nil)
		ar_wait_for(function() return not bd.firing_extinguisher end, 20000)
		ar_wait_for_control()
		ar_wait_for(function() return bd.tar.touchable or bd.all_beavers_dead end, 60000)
	end
end
ar_check(bd.all_beavers_dead, "all the beavers are dead (puzzle state 15)")
ar_wait_for_control()
ar_go(bd.bv_door, bv)
ar_wait_for_control()
ar_do("use", bv.padlock)
ar_wait_for(function() return bv.padlock.unlocked end, 120000)
ar_check(bv.padlock.unlocked, "the padlock is open")
ar_wait_for_control()
ar_state("end of chapter 12")
ar_checkpoint(12)
