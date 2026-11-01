-- Chapter 34: the winning ticket and the photo finish go through the track's photo window and come
-- back as the incriminating photo of Nick; Nick, back at his desk, is blackmailed over the dock
-- workers' foreman (the strike is on). Checkpoint in slot 50.

ar_load(29)
AR_NEW = TRUE
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
-- the neck to the ladder is hardly wider than Manny and Toto together (their collision spheres leave about 3 mm): along its east edge, as a
-- player pushing against the wall goes, he gets through; the planner keeps to the middle of the neck, against Toto. Whether he gets through
-- depends on how he comes at it, so when he is held up he steps back and tries again, as a player does
-- (and at a walk to the points: AR_RUN_P, a run to the points of the way from 25 cm (and less) was planned again 7 times here; this was in chapter 21 when the ship was
-- left after the dog tags, it is the way out of the ship now)
AR_RUN_P = 0.8
AR_KEEP_GOING = TRUE
ar_neck_tries = 0
while manny:getpos().y < -0.56 and ar_neck_tries < 6 do
	ar_walk_to(-0.06, -0.50, 0)
	if manny:getpos().y < -0.56 then
		ar_walk_to(0.05, -1.05, 0)
	end
	ar_neck_tries = ar_neck_tries + 1
end
AR_RUN_P = nil
AR_KEEP_GOING = nil
AR_FAILED = nil
ar_log("the neck to the ladder passed after " .. ar_neck_tries .. " tries")
ar_go(si.ladder, se)
ar_go(se.sd_door, xb)
ar_go(xb.tx_door, tx)
ar_go(tx.ts_door, ts)
ar_go(ts.tb_door, tb)
ar_wait_for_control()
ar_do("use", tb.photo_window, cn.ticket)
ar_wait_for(function() return tb.blackmail_photo.owner == manny end, 300000)
ar_wait_for_control()
ar_check(tb.blackmail_photo.owner == manny, "Manny has the incriminating photo")
ar_state("with the photo")
ar_go(tb.hh_door, hh, -0.3, 0.0, 0)
ar_wait_for_control()
ar_hh_elevator()
ar_go(hh.hl_door, hl)
ar_wait_for_control()
ar_describe()
ar_do("use", hl.virago_obj, tb.blackmail_photo)
ar_wait_for(function() return dd.strike_on end, 600000)
ar_wait_for_control()
ar_check(dd.strike_on, "the strike is on")
ar_state("end of chapter 34")
ar_checkpoint(34)
