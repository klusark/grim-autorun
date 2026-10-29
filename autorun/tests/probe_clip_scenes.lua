-- Probe (frames through DumpFrame, DUMPDIR=<dir>): the script clip planes of the real scenes dp, op (set by their enter scripts) and bd (the planes of bd.clip_planes)
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
probe_scene = function(case)
	ar_nt_place(case)
	probe_wait(40)
	local p = manny:getpos()
	PrintDebug("PROBE " .. case.id .. " pos " .. format("%.4f %.4f %.4f", p.x, p.y, p.z) .. "\n")
	ar_frame(case.id .. "_a")
	probe_wait(40)
end
probe_scene({ id = "dp", set = "dp" })
probe_scene({ id = "op", set = "op" })
probe_scene({ id = "bd", set = "bd" })
bd:current_setup(bd_rckws)
probe_wait(5)
SetActorClipActive(manny.hActor, TRUE)
SetActorClipPlane(manny.hActor, 1, 1, 0, 3.22333002, 2.62015009, -0.100000001)
manny:setpos(3.22, 2.62, 0)
probe_wait(5)
ar_frame("bd_p1")
probe_wait(40)
	probe_wait(40)
SetActorClipPlane(manny.hActor, 10, 1, 0, 3.38604999, 3.5179801, -0.100000001)
manny:setpos(3.38, 3.52, 0)
probe_wait(5)
ar_frame("bd_p2")
probe_wait(40)
	probe_wait(40)
AR_KEEP_GOING = nil
ar_finish()
