-- Chapter 7 (Year 2): out of the stump into the forest. On the first trail to Glottis' camp
-- Glottis has his heart ripped out. Free it from the spiders' web (a bone thrown into the web,
-- then the scythe hooks the web and slings the heart over to the camp), pick it up and put it
-- back in Glottis. Checkpoint in slot 20.

ar_load(6)
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
ar_go(sm.sg_door, sg)
-- Glottis' cutscene, Manny ends up by him with the heart in the web
ar_wait_for_control()
ar_state("Glottis has lost his heart")

ar_go(sg.sp_door, sp)
ar_wait_for_control()
ar_do("pickUp", sp.bone_pile)
ar_check(ar_find_owned(sp.bones), "Manny has a bone")
ar_do("use", sp.web, ar_find_owned(sp.bones))
ar_check(sp.web.has_bone, "the bone is in the web")
ar_do("use", sp.web, mo.scythe)
ar_wait_for(function() return sp.freed_heart end, 60000)
ar_check(sp.freed_heart, "the heart is free")

-- the ledge of the web is left through the sector at its end (sp_cheat_box1), which puts Manny on the path
ar_sp_across = function()
	return manny:getpos().x < -3
end
ar_sp_there = function()
	return system.currentSet == sg
end
ar_go(sp.sg_door, sg)
ar_do("pickUp", sg.heart)
ar_check(ar_has(sg.heart), "Manny has the heart")
ar_do("use", sg.glottis_obj, sg.heart)
ar_wait_for(function() return cur_puzzle_state[11] end, 60000)
ar_check(cur_puzzle_state[11], "Glottis has his heart back (puzzle state 11)")
ar_wait_for_control()
ar_state("end of chapter 7")
ar_checkpoint(7)
