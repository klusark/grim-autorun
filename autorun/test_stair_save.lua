-- A save keeps the constraint of a stair (ScummVM save version 32). stairman (_system.lua) switches SetActorConstrain on only as Manny steps
-- onto a stair, so a load that lost it let him walk off the stair's line until he left the stair. Manny walks onto the stair of be with the
-- forward key, is turned 30 degrees off the line and walks on (the constraint turns him back onto it), the game is saved and loaded, and the
-- same is done again.
--   SAVES=<scratch folder> EXTRA="ar_nt_lib.lua nav_cases.lua ar_fixture.lua" sh run_chapter.sh test_stair_save.lua 300
-- Result: two lines, "STAIRSAVE before the save PASS ..." and "STAIRSAVE after the load PASS ...".
-- (not placed on the stair: the placement of the nav tests switches the constraint off after stairman has switched it on)

-- the forward key held until Manny is dist metres from where he started (3 s at most), then let go
ar_ss_walk = function(dist)
	local p0 = manny:getpos()
	ar_key_down("MOVE_FORWARD")
	ar_try_wait(function()
		local p = manny:getpos()
		local dx = p.x - %p0.x
		local dy = p.y - %p0.y
		return sqrt(dx * dx + dy * dy) >= %dist
	end, 3000)
	ar_key_up("MOVE_FORWARD")
	sleep_for(300)
end

-- AR_SS_TRACE = TRUE (in an EXTRA file): Manny's position in every frame of the checks
ar_ss_trace = function()
	local k = 0
	while TRUE do
		local p = manny:getpos()
		PrintDebug(format("SSTRACE %d %.5f %.5f %.5f %.2f", k, p.x, p.y, p.z, manny:getrot().y) .. "\n")
		k = k + 1
		break_here()
	end
end

-- Manny turned 30 degrees off the line walks on: he has to end on the line, facing along it
ar_ss_check = function(label)
	local trace = nil
	if AR_SS_TRACE then
		trace = start_script(ar_ss_trace)
	end
	local p0 = manny:getpos()
	manny:setrot(0, AR_SS_YAW + 30, 0)
	-- (the stair is 55 cm long: the walks are short, the door at its top moves Manny into the next set)
	ar_ss_walk(0.08)
	local p1 = manny:getpos()
	local dx = p1.x - p0.x
	local dy = p1.y - p0.y
	local along = dx * AR_SS_DX + dy * AR_SS_DY
	local across = dx * AR_SS_DY - dy * AR_SS_DX
	local turn = mod(manny:getrot().y - AR_SS_YAW + 900, 360) - 180
	if trace then
		stop_script(trace)
	end
	local result = "FAIL"
	if abs(across) < 0.005 and along > 0.05 and abs(turn) < 0.5 then
		result = "PASS"
	end
	-- (no %s in format: the game's Lua cut the string short)
	ar_log("STAIRSAVE " .. label .. " " .. result .. format(": %.3f along the line, %.4f off it, yaw %.2f from the line's", along, across, turn))
end

-- (the save holds AR_SS_PHASE: the script that runs again after the load goes on to the check)
if AR_SS_PHASE ~= "saved" then
	ar_wait_for_control()
	-- (on the floor below the stair, facing up it)
	ar_nt_place({ id = "stair_save", set = "be", from = { 0.00, 0.66, 0 }, yaw = 180 })
	ar_key_down("MOVE_FORWARD")
	ar_try_wait(function() return manny:find_sector_name("stair") end, 5000)
	ar_key_up("MOVE_FORWARD")
	sleep_for(300)
	local p0 = manny:getpos()
	ar_ss_walk(0.05)
	local p1 = manny:getpos()
	-- (the line, from the walk along it)
	local dx = p1.x - p0.x
	local dy = p1.y - p0.y
	local len = sqrt(dx * dx + dy * dy)
	if not manny:find_sector_name("stair") or len < 0.05 then
		ar_log(format("STAIRSAVE FAIL Manny did not walk up the stair before the save (at %.3f %.3f %.3f, %.3f)", p1.x, p1.y, p1.z, len))
		ar_finish()
	end
	AR_SS_DX = dx / len
	AR_SS_DY = dy / len
	AR_SS_YAW = manny:getrot().y
	ar_ss_check("before the save")
	local p = manny:getpos()
	ar_log(format("STAIRSAVE saving on the stair at %.3f %.3f %.3f, yaw %.2f", p.x, p.y, p.z, manny:getrot().y))
	AR_SS_PHASE = "saved"
	ar_menu_save(90)
	-- (the task the save brings back waits here until the script that runs again stops it)
	if not AR_JUST_LOADED then
		Load("grim90.gsv")
	end
	while TRUE do
		sleep_for(1000)
	end
end

ar_wait_for_control()
ar_ss_check("after the load")
