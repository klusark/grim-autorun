-- Chapter 20: the sailor Naranja in the ship's interior. Checkpoint in slot 36.

ar_load(19)
AR_NEW = TRUE
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
ar_log("holding: " .. tostring(manny.is_holding and manny.is_holding.name))
ar_go(bk.bi_door, bi)
ar_log("holding after: " .. tostring(manny.is_holding and manny.is_holding.name))
ar_go(bi.be_door, be)
ar_go(be.bw_door, bw)
ar_go(bw.hb_door, hb)
ar_go(hb.xb_door, xb)
-- the walkways of the bridge are joined by camera boxes that move Manny along, the stick follows
ar_bridge_east()
ar_wait_for_control()
ar_describe()
ar_go(se.si_door, si)
ar_wait_for_control()
ar_state("in the ship")
-- the open fridge (and its crisper) distracts the two while the dishwater goes into the booze
-- (the way to the fridge is blocked by the two at the table for a while: up to 40 seconds, not the usual 10)
AR_WALK_MAX = 40000
-- (the two at the table stand in the way at times, as they walk about: back to the fridge, as a player does)
ar_do_retry("use", si.fridge, nil, 5)
AR_WALK_MAX = nil
ar_wait_for(function() return si.fridge:is_open() end, 30000)
ar_wait_for_control()
ar_do("use", si.lettuce_crisper)
ar_wait_for(function() return si.lettuce_crisper:is_open() end, 30000)
ar_wait_for_control()
-- (the booze is only offered between the sailor's gulps)
local tries = 0
-- (stand ready at the booze, facing it, so that the moment it is offered is not spent walking or looking round)
ar_walk_to(si.booze.use_pnt_x, si.booze.use_pnt_y, si.booze.use_pnt_z)
if si.booze.use_rot_y then
	ar_face_yaw(si.booze.use_rot_y)
end
while not si.booze.dosed and tries < 20 do
	ar_wait_for(function() return si.booze.touchable end, 30000)
	AR_KEEP_GOING = TRUE
	ar_do("use", si.booze, hk.turkey_baster)
	AR_KEEP_GOING = nil
	AR_FAILED = nil
	tries = tries + 1
end
ar_wait_for(function() return si.booze.dosed end, 60000)
ar_check(si.booze.dosed, "the booze is dosed")
ar_wait_for(function() return si.naranja_out end, 300000)
ar_check(si.naranja_out, "Naranja passes out")
ar_wait_for(function() return cut_scene and not find_script(cut_scene.passout) and cutSceneLevel == 0 end, 300000)
ar_wait_for_control()
ar_state("Naranja is out")
-- the sailor's dog tags from his cot
ar_do("use", si.cot)
ar_wait_for(function() return si.dog_tags.owner == manny end, 60000)
ar_wait_for_control()
ar_check(si.dog_tags.owner == manny, "Manny has the dog tags")
ar_state("end of chapter 20")
ar_checkpoint(20)
