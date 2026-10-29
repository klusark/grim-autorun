-- Chapter 14 (Year 3 in the real game, Rubacava): the cafe balcony. Manny walks through the cafe
-- to the street, is shanghaied by Velasco into Limbo and hears what the job needs: a vacancy, a
-- union card and the strike. Checkpoint in slot 30.

ar_load(13)
AR_NEW = nil
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
ar_go(cb.cf_door, cf)
ar_go(cf.cc_door, cc)
-- (the game sends Manny back out of the coat check the first time: in again by the door of the cafe)
if system.currentSet ~= cc then
	ar_go(ci.cc_door, cc)
end
-- Lupe at the coat check grabs everyone who wants to leave, so talk to her first
ar_wait_for_control()
ar_do("use", cc.lupe_obj)
ar_wait_for(function() return lu1 and system.buttonHandler == lu1 end, 60000)
ar_pick_exit(lu1)
ar_wait_for_control()
ar_go(cc.ce_door, ce)
ar_wait_for_control()
-- on the way to the elevator station a raven trigger shanghais Manny
ar_walk_to(ce.ev_door.out_pnt_x, ce.ev_door.out_pnt_y, ce.ev_door.out_pnt_z, function() return meche.shanghaid end)
ar_wait_for(function() return system.currentSet == lm end, 200000)
ar_wait_for_control()
ar_check(system.currentSet == lm, "Manny is in Limbo")

-- Velasco: all the questions, to learn about the vacancy, the union card and the strike
-- (his own conversation on arriving may still be going)
ar_wait_for(ar_handler_normal, 60000, "the keys back to normal")
ar_do("use", lm.velasco_obj)
ar_wait_for(function() return ve2 and system.buttonHandler == ve2 end, 60000)
ar_pick_if(ve2, 100)
ar_pick_if(ve2, 110)
ar_pick_if(ve2, 120)
ar_pick_if(ve2, 130)
ar_pick_if(ve2, 150)
ar_pick_if(ve2, 160)
ar_pick_if(ve2, 165)
ar_pick_if(ve2, 170)
ar_pick_if(ve2, 140)
ar_check(lm.talked_union and lm.talked_naranja and lm.talked_tools, "Velasco told what the job needs")
ar_pick_exit(ve2)
ar_wait_for_control()
ar_state("end of chapter 14")
ar_checkpoint(14)
