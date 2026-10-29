-- Probe (frames through DumpFrame, DUMPDIR=<dir>): Manny at the middle of each walk sector of os, with the side test of his shadow off (SetActorShadowValid 0) and on
-- (1 and -1), to find the places where the shadow is drawn on one side of its plane only; tools/pngdiff.py names the frames that differ
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
shadow_case = { id = "os", set = "os" }
ar_nt_place(shadow_case)
probe_wait(20)
nav = ar_nav_of(os)
sk = 1
while sk <= 5 do
	x, y = ar_nav_centre(nav, sk)
	z = nav.p[sk][3]
	manny:setpos(x, y, z)
	probe_wait(3)
	PrintDebug("PROBE sector " .. sk .. format(" %.4f %.4f %.4f", x, y, z) .. "\n")
	SetActorShadowValid(manny.hActor, 0)
	probe_wait(2)
	ar_frame("s" .. format("%02d", sk) .. "_v0")
	SetActorShadowValid(manny.hActor, 1)
	probe_wait(2)
	ar_frame("s" .. format("%02d", sk) .. "_v1")
	SetActorShadowValid(manny.hActor, -1)
	probe_wait(2)
	ar_frame("s" .. format("%02d", sk) .. "_vm1")
	sk = sk + 1
end
AR_KEEP_GOING = nil
ar_finish()
