-- Probe (PROBE lines): the angle that is seen after SetActorRot on a tilted sector (the case slide_wall_right of the navigation tests), frame by frame, with and
-- without the turn key, to be run on both engines (EXTRA="nav_cases.lua ar_fixture.lua ar_nt_lib.lua nav_known.lua nav_coll_expect.lua nav_slide_expect.lua
-- rules_expect.lua rules_known.lua" sh run_chapter.sh tests/probe_setrot.lua 300). The original gives 161.5 in the first frame of the case with the key held.
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
AR_KEEP_GOING = TRUE
probe_case = { id = "probe", set = "bs", from = { -6.80, 26.40, 11.85 }, yaw = 160, key = -1, frames = 40 }
probe_run = function(key, frames)
	ar_nt_place(probe_case)
	AR_WALK = TRUE
	manny:set_run(FALSE)
	sleep_for(2500)
	manny:setpos(probe_case.from[1], probe_case.from[2], probe_case.from[3])
	manny:setrot(0, probe_case.yaw, 0)
	local r = manny:getrot()
	PrintDebug("PROBE key " .. key .. " right after setrot: " .. format("%.4f %.4f %.4f", r.x, r.y, r.z) .. "\n")
	break_here()
	r = manny:getrot()
	PrintDebug("PROBE key " .. key .. " 1 frame after: " .. format("%.4f", r.y) .. "\n")
	break_here()
	r = manny:getrot()
	PrintDebug("PROBE key " .. key .. " 2 frames after: " .. format("%.4f", r.y) .. "\n")
	local k = 0
	while k < frames do
		if key ~= 0 then
			TurnActor(manny.hActor, key)
		end
		manny:walk_forward()
		break_here()
		k = k + 1
		local p = manny:getpos()
		r = manny:getrot()
		PrintDebug("PROBE key " .. key .. " step " .. k .. format(" %.6f %.6f %.4f yaw %.4f", p.x, p.y, p.z, r.y) .. "\n")
	end
	AR_WALK = nil
end
probe_run(0, 4)
probe_run(-1, 4)
AR_KEEP_GOING = nil
ar_finish()
