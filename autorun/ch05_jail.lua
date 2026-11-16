-- Chapter 5: the Meche conversation ends, and walking along the hallway is the end of Manny's
-- freedom: with Meche reaped the camera by Eva's desk starts Copal's cutscene (ha.funny_bones)
-- and Manny is locked in Glottis' shop. Salvador answers the knock and, after the right
-- choices, lets him out and takes him to the headquarters. Checkpoint in slot 14.

ar_load(4)
ar_log("start in " .. ar_set_name())
-- Meche's conversation starts as the chapter before ends (its intro is skipped by ar_skipper).
-- Wait for its choices and say goodbye, otherwise the choice list stays on the screen.
if ar_dialog_ready(me1, 90000) then
	ar_pick_exit(me1)
	ar_wait_for(function() return system.buttonHandler ~= me1 end, 30000)
else
	ar_fail("Meche's conversation never came up")
end
ar_wait_for_control()

ar_go(mo.ha_door, ha)
-- on toward the elevators: the camera by Eva's desk starts the cutscene
AR_JAIL = gs
ar_walk_to(ha.lo_door.use_pnt_x, ha.lo_door.use_pnt_y, ha.lo_door.use_pnt_z, function() return system.currentSet == AR_JAIL end)
ar_expect_set(gs, "locked in Glottis' shop")

-- (100% modes: Salvador is talked to at the door first, again and again while he has a line left: each talk ends with Manny still in the shop, by
-- a line that ends it in a node with no way back (fold_node, angry_node) or the exit line; the chapter's own talk below lets Manny out)
if AR_FULL then
	AR_TALK_OBJ = gs.ga_door
	ar_extra_run("talk to Salvador at the door", ar_talk_one)
	ar_wait_for_control()
	ar_check(system.currentSet == gs, "still in Glottis' shop after the talks at the door")
end
ar_do("use", gs.ga_door)
-- the dialog table only exists once the conversation has been started
ar_wait_for(function() return sa1 end, 60000)
ar_pick(sa1, 120)
ar_pick(sa1, 220)
ar_pick(sa1, 400)
ar_expect_set(hq, "in the headquarters")
ar_checkpoint(5)
