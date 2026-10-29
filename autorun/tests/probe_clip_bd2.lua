-- Probe (frames through DumpFrame, DUMPDIR=<dir>; the original through tools/framecap.py): the places of bd (setup bd_rckws) where the clip planes of bd.clip_planes
-- cut the spray of the extinguisher in ScummVM (tests/probe_clip_bd.lua), with the script of the planes running ("on") and not started ("off"), on either engine
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
secs = { 1, 6, 7, 8, 9 }
si = 1
while secs[si] do
	sk = secs[si]
	yi = 1
	while yi <= 2 do
		if yi == 1 then
			yaw = 135
		else
			yaw = 45
		end
		pass = 1
		while pass <= 2 do
			bd:current_setup(bd_rckws)
			probe_wait(10)
			x, y = ar_nav_centre(nav, sk)
			z = nav.p[sk][3]
			manny:setpos(x, y, z)
			manny:setrot(0, yaw, 0)
			bd.firing_extinguisher = TRUE
			if pass == 1 then
				start_script(bd.clip_planes)
			end
			manny:play_chore(2, "ma_use_extin.cos")
			probe_wait(8)
			if pass == 1 then
				tag = "on"
			else
				tag = "off"
			end
			ar_frame("b" .. format("%02d", sk) .. "_" .. yaw .. "_" .. tag)
			probe_wait(40)
			bd.firing_extinguisher = FALSE
			probe_wait(10)
			pass = pass + 1
		end
		yi = yi + 1
	end
	si = si + 1
end
AR_KEEP_GOING = nil
ar_finish()
