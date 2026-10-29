-- Probe (frames through DumpFrame, DUMPDIR=<dir>; the original through tools/framecap.py): bd in the setup bd_rckws, Manny spraying the extinguisher at the beavers as
-- the game aims it (the point bd.test_angle uses), from the centre of every walk sector (AIM_SECS: only those), with the planes of bd.clip_planes running ("on") and not ("off")
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
ar_nt_place({ id = "bd", set = "bd" })
probe_wait(30)
bd:current_setup(bd_rckws)
probe_wait(10)
nav = ar_nav_of(bd)
manny:push_costume("ma_use_extin.cos")
manny:play_chore(1, "ma_use_extin.cos")
probe_wait(60)
sk = 1
while nav.p[sk] do
	aim_on = TRUE
	if AIM_SECS then
		aim_on = nil
		ai = 1
		while AIM_SECS[ai] do
			if AIM_SECS[ai] == sk then
				aim_on = TRUE
			end
			ai = ai + 1
		end
	end
	if aim_on then
		pass = 1
		while pass <= 2 do
			bd:current_setup(bd_rckws)
			probe_wait(10)
			x, y = ar_nav_centre(nav, sk)
			z = nav.p[sk][3]
			manny:setpos(x, y, z)
			manny:setrot(0, GetActorYawToPoint(manny.hActor, 4.69902992, 2.43168998, z), 0)
			bd.firing_extinguisher = TRUE
			if pass == 1 then
				start_script(bd.clip_planes)
				tag = "on"
			else
				tag = "off"
			end
			manny:play_chore(2, "ma_use_extin.cos")
			probe_wait(8)
			ar_frame("a" .. format("%02d", sk) .. "_" .. tag)
			probe_wait(40)
			bd.firing_extinguisher = FALSE
			probe_wait(10)
			pass = pass + 1
		end
	end
	sk = sk + 1
end
AR_KEEP_GOING = nil
ar_finish()
