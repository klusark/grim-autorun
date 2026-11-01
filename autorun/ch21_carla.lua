-- Chapter 21: out of the ship and along the bridge to the harbor. (Carla, and the metal detector in the cat box, are in chapter 18 now.) Checkpoint in slot 37.

ar_load(20)
AR_NEW = TRUE
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
-- the neck to the ladder is hardly wider than Manny and Toto together (their collision spheres leave about 3 mm): along its east edge, as a
-- player pushing against the wall goes, he gets through; the planner keeps to the middle of the neck, against Toto. Whether he gets through
-- depends on how he comes at it, so when he is held up he steps back and tries again, as a player does
-- (and at a walk to the points: AR_RUN_P, a run to the points of the way from 25 cm (and less) was planned again 7 times here)
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
ar_go(xb.hb_door, hb)
ar_wait_for_control()
ar_check(sl.detector.owner == manny, "Manny has the metal detector")
ar_state("end of chapter 21")
ar_checkpoint(21)
