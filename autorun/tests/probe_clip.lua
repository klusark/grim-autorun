-- Probe (frames through DumpFrame, DUMPDIR=<dir>): the script clip plane of an actor (SetActorClipPlane/SetActorClipActive) in the office, and the side test of
-- the shadow of an actor (SetActorShadowValid) in os; to be run on ScummVM before and after the opcodes were implemented
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
probe_clip = function(case)
	ar_nt_place(case)
	probe_wait(30)
	local p = manny:getpos()
	local r = manny:getrot()
	PrintDebug("PROBE " .. case.id .. " pos " .. format("%.4f %.4f %.4f yaw %.4f", p.x, p.y, p.z, r.y) .. "\n")
	ar_frame(case.id .. "_noclip")
	SetActorClipPlane(manny.hActor, 1, 0, 0, p.x, p.y, p.z + 0.3)
	SetActorClipActive(manny.hActor, TRUE)
	probe_wait(3)
	ar_frame(case.id .. "_clipA")
	SetActorClipPlane(manny.hActor, 0, 0, 1, p.x, p.y, p.z + 0.3)
	probe_wait(3)
	ar_frame(case.id .. "_clipB")
	SetActorClipActive(manny.hActor, FALSE)
	probe_wait(3)
	ar_frame(case.id .. "_off")
end
probe_clip({ id = "mo", set = "mo" })
probe_shadow = function(case, v)
	ar_nt_place(case)
	probe_wait(30)
	local p = manny:getpos()
	PrintDebug("PROBE " .. case.id .. " pos " .. format("%.4f %.4f %.4f", p.x, p.y, p.z) .. "\n")
	ar_frame(case.id .. "_default")
	SetActorShadowValid(manny.hActor, 0)
	probe_wait(3)
	ar_frame(case.id .. "_valid0")
	SetActorShadowValid(manny.hActor, 1)
	probe_wait(3)
	ar_frame(case.id .. "_valid1")
	SetActorShadowValid(manny.hActor, -1)
	probe_wait(3)
	ar_frame(case.id .. "_validm1")
end
probe_shadow({ id = "os", set = "os" })
AR_KEEP_GOING = nil
ar_finish()
