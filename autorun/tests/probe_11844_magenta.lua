-- Bug #11844 probe (frames through DumpFrame, DUMPDIR=<dir>): Manny standing in the elevator of ha (setup ha_elvos), facing the camera,
-- with his shadow on and off; the shadow must not show over his feet
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
AR_KEEP_GOING = TRUE
probe_wait = function(n)
	local k = 0
	while k < n do
		k = k + 1
		break_here()
	end
end
ar_nt_place({ id = "ha", set = "ha", enter = TRUE })
probe_wait(20)
ha:current_setup(ha_elvos)
stop_script(ha.elevator_door_timer)
ha.lo_door.opened = FALSE
ha.lo_door:unlock()
ha.lo_door:open()
ha.lo_door.interest_actor:complete_chore(ha_elvos_elev_door_door_open)
ar_log("ia " .. tostring(ha.lo_door.interest_actor) .. " cos " .. tostring(ha.lo_door.interest_actor:get_costume()))
ar_log("door open " .. tostring(ha.lo_door:is_open()) .. " setup " .. ha:current_setup())
probe_wait(120)
local pts = { { 7.10, 3.20 }, { 7.10, 3.25 }, { 7.10, 3.30 }, { 7.10, 3.35 }, { 7.10, 3.40 } }
SetShadowColor(255, 0, 255)
local rots = { 180, 210 }
local i = 1
while pts[i] do
	local r = 1
	while rots[r] do
		manny:setpos(pts[i][1], pts[i][2], 0)
		manny:setrot(0, rots[r], 0)
		probe_wait(10)
		local q = manny:getpos()
		ar_log("PROBE p" .. i .. "r" .. rots[r] .. " at " .. format("%.3f %.3f %.3f", q.x, q.y, q.z))
		ActivateActorShadow(manny.hActor, 0, TRUE)
		probe_wait(3)
		ar_frame("p" .. i .. "r" .. rots[r] .. "_on")
		ActivateActorShadow(manny.hActor, 0, FALSE)
		probe_wait(3)
		ar_frame("p" .. i .. "r" .. rots[r] .. "_off")
		manny:set_visibility(FALSE)
		probe_wait(3)
		ar_frame("p" .. i .. "r" .. rots[r] .. "_bg")
		manny:set_visibility(TRUE)
		ActivateActorShadow(manny.hActor, 0, TRUE)
		r = r + 1
	end
	i = i + 1
end
AR_KEEP_GOING = nil
ar_finish()
