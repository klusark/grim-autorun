-- Chapter 10 (Year 2): the beaver room's gate leads to the beaver dam, where burning beavers
-- chase Manny off the first time. Fetch bones from the dam (outside the beavers' death zone),
-- go along the rock trail to the tar river and, for each beaver: throw a bone into the tar, the
-- beaver dives for it and flies up out of the tar, and the fire extinguisher, sprayed at it
-- as it flies, freezes it so that it sinks. Three beavers end the fight (puzzle states 14, 15).
-- Checkpoint in slot 25.

ar_load(9)
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
-- the gate, Glottis, the beavers chase Manny out of the dam
ar_do("use", bv.gate)
ar_wait_for(function() return bd.beavers.met and system.currentSet == bv and cutSceneLevel == 0 end, 300000)
ar_check(bd.beavers.met, "the beavers have chased Manny out once")
ar_go(bv.bd_door, bd)

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
ar_state("end of chapter 10")
ar_checkpoint(10)
