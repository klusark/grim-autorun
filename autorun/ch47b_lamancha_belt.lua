-- Chapter 47, second half (Year 3): the crane chain lies on the conveyor belt. Manny runs down the belt to the strip
-- where he jumps off, the lever in the conveyor room moves the chain along the belt, bunched, then wrapped around the
-- Lamancha, and raising the crane brings the ship up (Poseidon cutscene). Checkpoint in slot 63.

AR_NEW = TRUE
ar_load(47)
ar_log("start in " .. ar_set_name())
ar_wait_for_control()

-- 4. the lever: the chain goes to the anchor room, is bunched, then wrapped around the ship. Manny
-- runs down the belt to the edge of it and jumps off by the lever (a cutscene, so the walk stops there)
ar_go(cv.cy_door, cy)
ar_wait_for_control()
-- (the way onto the belt passes the sector that makes the chain drift to the belt, another cutscene: on from there)
ar_log("belt: crane_broken " .. tostring(ew.crane_broken) .. " crane_down " .. tostring(ew.crane_down) .. " crane_pos " .. tostring(ew.crane_pos) .. " at_conveyor " .. tostring(ew.at_conveyor) .. " drifting " .. tostring(cy.drifting))
AR_BELT_TRIES = 0
while (manny:getpos().z >= 0 or cy.drifting) and AR_BELT_TRIES < 6 do
	ar_state("belt loop " .. tostring(AR_BELT_TRIES) .. " drifting " .. tostring(cy.drifting))
	if cy.drifting then
		-- the sector over the chain made Manny take hold of it (as the game means it to, with the crane down): down the
		-- chain with the key. At the bottom the belt carries him back up to the chain in half a second, so the walk to
		-- the strip where he jumps off starts in the very frame he lets go of it, with nothing in between.
		ar_key_down("MOVE_BACKWARD")
		AR_BELT_T = 0
		while (cy.drifting or find_script(cy.end_drift_gracefully)) and AR_BELT_T < 30000 do
			break_here()
			AR_BELT_T = AR_BELT_T + system.frameTime
		end
		ar_state("let go of the chain")
		-- Manny faces north when he lets go of the chain and turns too slowly to run for the strip before the belt carries him
		-- up again: backing away (the key is still down) while he turns left takes him down and across the belt
		ar_key_down("TURN_LEFT")
		AR_PROBE = 0
		AR_PROBE_T = 0
		AR_FACING = nil
		while AR_PROBE_T < 5000 and cutSceneLevel == 0 and not AR_FACING do
			break_here()
			AR_PROBE = AR_PROBE + 1
			AR_PROBE_T = AR_PROBE_T + system.frameTime
			-- (until he faces the strip, near enough for the walk to turn the rest on its way)
			AR_PD = GetActorYawToPoint(manny.hActor, -0.205, 3.7, manny:getpos().z) - manny:getrot().y
			while AR_PD > 180 do
				AR_PD = AR_PD - 360
			end
			while AR_PD < -180 do
				AR_PD = AR_PD + 360
			end
			if abs(AR_PD) < 100 then
				-- (backing away is for the first part of the turn: later it would take him up the belt again)
				ar_key_up("MOVE_BACKWARD")
			end
			if abs(AR_PD) < 12 then
				AR_FACING = TRUE
			end
			if AR_PROBE - floor(AR_PROBE / 6) * 6 == 0 then
				ar_log("probe " .. format("%.2f %.2f rot %.0f moving %s turning %s", manny:getpos().x, manny:getpos().y, manny:getrot().y, tostring(manny:is_moving()), tostring(manny:is_turning())))
			end
		end
		ar_keys_up()
		ar_state("after the walk off the chain, cut " .. tostring(cutSceneLevel))
		ar_wait_for_control()
	end
	-- (straight for the strip at a run, with nothing planned: the belt carries him up to the chain in a second or two)
	AR_NO_SLOW = TRUE
	ar_walk_stick(-0.205, 3.7, 0.2, function() return cutSceneLevel > 0 or cy.drifting end, 8000)
	AR_NO_SLOW = nil
	ar_wait_for_control()
	AR_BELT_TRIES = AR_BELT_TRIES + 1
end
ar_log("after the belt: drifting " .. tostring(cy.drifting) .. " handler sample " .. tostring(system.buttonHandler == SampleButtonHandler) .. " tries " .. tostring(AR_BELT_TRIES))
ar_wait_for_control()
-- (off the belt for good: not hanging on the chain, which keeps the keys of the verbs off)
ar_check(manny:getpos().z < 0 and not cy.drifting, "Manny jumped off the belt")
ar_do("use", cy.lever)
ar_wait_for(function() return ac.chain_state == "here" end, 90000)
ar_wait_for_control()
ar_check(ac.chain_state == "here", "the chain is in the anchor room")
ar_do("use", cy.lever)
ar_wait_for(function() return ac.chain_state == "bunched" end, 90000)
ar_wait_for_control()
ar_check(ac.chain_state == "bunched", "the chain is bunched up")
ar_do("use", cy.lever)
ar_wait_for(function() return ac.chain_state == "wrapped" end, 90000)
ar_wait_for_control()
ar_check(cur_puzzle_state[43], "the chain is wrapped around the Lamancha (puzzle state 43)")

-- 5. back up the chain to the crane, raising it brings the ship up
ar_do("use", cy.belt)
ar_wait_for_control()
ar_walk_to(-0.12, 4.45, 0.15, function() return cy.drifting end)
ar_walk_to(-0.05, 4.54, 0.15, function() return cy.drifting or cutSceneLevel > 0 end)
ar_wait_for(function() return cy.drifting end, 10000)
ar_wait_for_control()
ar_check(cy.drifting, "Manny hangs on the chain")
ar_key_down("MOVE_FORWARD")
ar_wait_for(function() return system.currentSet == cv end, 60000)
ar_keys_up()
ar_wait_for_control()
ar_do("use", cv.crane)
ar_wait_for(function() return system.currentSet == ew end, 30000)
ar_wait_for_control()
ar_press_key(ar_real_key("MOVE_FORWARD"))
ar_wait_for(function() return raised_lamancha end, 60000)
ar_wait_for(function() return system.currentSet == bl end, 120000)
ar_wait_for_control()
ar_check(raised_lamancha and cur_puzzle_state[42] and cur_puzzle_state[44], "the Lamancha is raised (puzzle states 42, 44)")
ar_state("end of chapter 47")
ar_checkpoint(48)
