-- Probe (frames through DumpFrame, DUMPDIR=<dir>): Manny in the office clipped by horizontal planes at several heights above his feet (what is above the plane is kept)
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
ar_nt_place({ id = "mo", set = "mo" })
probe_wait(30)
p = manny:getpos()
PrintDebug("PROBE pos " .. format("%.4f %.4f %.4f", p.x, p.y, p.z) .. "\n")
ar_frame("h_none")
SetActorClipActive(manny.hActor, TRUE)
hs = { 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9 }
i = 1
while hs[i] do
	SetActorClipPlane(manny.hActor, 0, 0, 1, p.x, p.y, p.z + hs[i])
	probe_wait(3)
	ar_frame("h_" .. format("%03d", hs[i] * 100))
	i = i + 1
end
SetActorClipPlane(manny.hActor, 0, 0, -1, p.x, p.y, p.z + 0.4)
probe_wait(3)
ar_frame("h_below_040")
AR_KEEP_GOING = nil
ar_finish()
