-- Chapter 29: one trip to the ship from the coat check. The sailor Naranja is made drunk with the dishwater baster and passes out; the dog tags from his cot; with him out
-- the slip of paper (chapter 21) gets Toto to hand over the photo finish picture; and the ticket printer (it works anywhere) is set to the winning ticket.
-- Checkpoint in slot 45.

ar_load(21)
AR_NEW = TRUE
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
ar_go(cc.ce_door, ce)
ar_go(ce.ev_door, ev)
ar_go(ev.be_door, bw)
ar_go(bw.hb_door, hb)
ar_go(hb.xb_door, xb)
ar_go(xb.se_door, se)
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
ar_do("use", si.toto_obj, cc.anchor_paper)
ar_wait_for(function() return si.photofinish.owner == manny end, 600000)
ar_wait_for_control()
ar_check(si.photofinish.owner == manny, "Manny has the photo finish")
ar_do("use", cn.printer)
ar_wait_for(function() return system.buttonHandler == tpButtonHandler end, 60000)
ar_check(system.buttonHandler == tpButtonHandler, "the printer is open")
local tap = function(control)
	ar_key_down(control)
	sleep_for(150)
	ar_key_up(control)
	sleep_for(300)
	ar_wait_for_control()
end
local i = 0
-- race: 1 up to 6
while i < 5 do
	tap("MOVE_FORWARD")
	i = i + 1
end
tap("TURN_LEFT")
tap("MOVE_FORWARD")
tap("TURN_LEFT")
tap("MOVE_FORWARD")
ar_log("printer: race " .. tostring(tp.race) .. " day " .. tostring(tp.day) .. " week " .. tostring(tp.week))
ar_check(tp.race == 6 and tp.day == 2 and tp.week == 2, "the printer shows race 6, day 2, week 2")
tap("TURN_LEFT")
ar_check(tp.current_button == tp.PRINT, "on the print button")
tap("MOVE_FORWARD")
ar_wait_for(function() return cn.ticket.owner == manny end, 60000)
ar_wait_for_control()
ar_check(cn.ticket.owner == manny, "Manny has the ticket")
ar_state("end of chapter 29")
ar_checkpoint(29)
