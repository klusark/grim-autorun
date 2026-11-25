-- A save keeps the stair Guybrush is on (ScummVM save version 32). The line of an EMI stair (a walk sector of type 0x1200) is made as he steps
-- onto it, so a load that lost it let him walk off the line until he left the stair. From the checkpoint before Act 2 chapter 4 he goes into
-- Meathook's house and walks onto its stair with the forward key, is turned 30 degrees off the line and walks on (the stair turns him back
-- onto it), the game is saved and loaded, and the same is done again.
--   SAVES=<folder with grim203.gsv> sh run_emi.sh test_stair_save.lua 300
-- Result: two lines, "STAIRSAVE before the save PASS ..." and "STAIRSAVE after the load PASS ...".

-- the forward key held until Guybrush is dist metres (on the floor) from where he started (3 s at most), then let go
ar_ss_walk = function(dist)
	local p0 = manny:getpos()
	ar_key_down("MOVE_FORWARD")
	ar_try_wait(function()
		local p = manny:getpos()
		local dx = p.x - %p0.x
		local dz = p.z - %p0.z
		return sqrt(dx * dx + dz * dz) >= %dist
	end, 3000)
	ar_key_up("MOVE_FORWARD")
	sleep_for(300)
end

-- Guybrush turned 30 degrees off the line walks on: he has to end on the line, facing along it
ar_ss_check = function(label)
	local p0 = manny:getpos()
	manny:setrot(0, AR_SS_YAW + 30, 0)
	ar_ss_walk(0.3)
	local p1 = manny:getpos()
	local dx = p1.x - p0.x
	local dz = p1.z - p0.z
	local along = dx * AR_SS_DX + dz * AR_SS_DZ
	local across = dx * AR_SS_DZ - dz * AR_SS_DX
	local turn = mod(manny:getrot().y - AR_SS_YAW + 900, 360) - 180
	local result = "FAIL"
	if abs(across) < 0.005 and along > 0.05 and abs(turn) < 0.5 then
		result = "PASS"
	end
	-- (no %s in format: the game's Lua cut the string short)
	ar_log("STAIRSAVE " .. label .. " " .. result .. format(": %.3f along the line, %.4f off it, yaw %.2f from the line's", along, across, turn))
end

ar_load(203)
-- (the save holds AR_SS_PHASE: the script that runs again after the load goes on to the check)
if AR_SS_PHASE ~= "saved" then
	ar_wait_for_control()
	ar_do("use", shi.mem_door)
	ar_wait_for_control()
	ar_do("use", mem.mhe_door)
	ar_wait_for_control()
	ar_do("use", mhe.mhi_door)
	ar_wait_for_control()
	ar_check(ar_set_name() == "Meathook's Interior", "in Meathook's house")
	-- (on the floor below the stair, facing up it)
	manny:setpos(5.65, 0, 4.0)
	manny:setrot(0, ar_want_yaw(5.65, 6.5), 0)
	sleep_for(200)
	ar_key_down("MOVE_FORWARD")
	ar_try_wait(function() return manny:getpos().y > 0.3 end, 3000)
	ar_key_up("MOVE_FORWARD")
	sleep_for(300)
	local p0 = manny:getpos()
	ar_ss_walk(0.3)
	local p1 = manny:getpos()
	-- (the line, from the walk along it, on the floor)
	local dx = p1.x - p0.x
	local dz = p1.z - p0.z
	local len = sqrt(dx * dx + dz * dz)
	if p0.y <= 0.3 or len < 0.05 then
		ar_log(format("STAIRSAVE FAIL Guybrush did not walk up the stair before the save (at %.3f %.3f %.3f, %.3f)", p1.x, p1.y, p1.z, len))
		ar_finish()
	end
	AR_SS_DX = dx / len
	AR_SS_DZ = dz / len
	AR_SS_YAW = manny:getrot().y
	ar_ss_check("before the save")
	local p = manny:getpos()
	ar_log(format("STAIRSAVE saving on the stair at %.3f %.3f %.3f, yaw %.2f", p.x, p.y, p.z, manny:getrot().y))
	AR_SS_PHASE = "saved"
	ar_menu_save(90)
	-- (the task the save brings back waits here until the script that runs again stops it)
	if not JustLoaded() then
		Load("grim90.gsv")
	end
	while TRUE do
		sleep_for(1000)
	end
end

ar_wait_for_control()
ar_ss_check("after the load")
