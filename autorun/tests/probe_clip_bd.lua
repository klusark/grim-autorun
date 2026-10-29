-- Probe (frames through DumpFrame, DUMPDIR=<dir>): bd in the setup bd_rckws, Manny spraying the extinguisher (ma_use_extin.cos, chore 2) with the clip planes of
-- bd.clip_planes running, at the centre of every walk sector and with two headings (the plane depends on yaw >= 90); the same run with the rule clip_plane off
-- (GRIMOFF) shows the sectors where the plane takes anything off the picture
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
	yi = 1
	while yi <= 2 do
		if yi == 1 then
			yaw = 135
		else
			yaw = 45
		end
		x, y = ar_nav_centre(nav, sk)
		z = nav.p[sk][3]
		manny:setpos(x, y, z)
		manny:setrot(0, yaw, 0)
		bd.firing_extinguisher = TRUE
		start_script(bd.clip_planes)
		manny:play_chore(2, "ma_use_extin.cos")
		probe_wait(8)
		ar_log("PROBE sector " .. sk .. " yaw " .. yaw .. format(" %.4f %.4f %.4f", x, y, z))
		ar_frame("b" .. format("%02d", sk) .. "_" .. yaw)
		probe_wait(3)
		bd.firing_extinguisher = FALSE
		probe_wait(4)
		yi = yi + 1
	end
	sk = sk + 1
end
AR_KEEP_GOING = nil
ar_finish()
