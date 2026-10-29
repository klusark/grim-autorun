-- Probe (frames through DumpFrame, DUMPDIR=<dir>; the original through tools/framecap.py): Manny in dp at the place where dp.anchor.use_scythe has him lift the
-- anchor (the left hand on the object, the scythe held), frames while the chore plays, with the clip plane of dp.enter on ("on_") and off again ("off_")
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
probe_run = function(tag, active)
	manny:setpos(-0.104396001, 0.220246002, 0)
	manny:setrot(0, -208.561996, 0)
	probe_wait(10)
	SetActorClipPlane(manny.hActor, 0, 1, 0.02, -0.03, 0.0106953997, 0)
	if active then
		SetActorClipActive(manny.hActor, TRUE)
	else
		SetActorClipActive(manny.hActor, FALSE)
	end
	manny:play_chore_looping(mn2_hold_scythe, "mn2.cos")
	probe_wait(20)
	ar_frame(tag .. "_hold")
	probe_wait(40)
	manny:play_chore(mn2_lft_on_obj, "mn2.cos")
	local k = 0
	while k < 8 do
		probe_wait(6)
		ar_frame(tag .. "_lft" .. k)
		probe_wait(40)
		k = k + 1
	end
	manny:play_chore(mn2_lft_off, "mn2.cos")
	probe_wait(60)
	ar_frame(tag .. "_off_chore")
	probe_wait(40)
end
ar_nt_place({ id = "dp", set = "dp" })
probe_wait(150)
probe_run("on", TRUE)
probe_run("off", FALSE)
AR_KEEP_GOING = nil
ar_finish()
