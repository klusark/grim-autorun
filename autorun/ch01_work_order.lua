-- Chapter 1: from Manny's office to the work order. Down the elevator, talk Glottis into
-- helping (he hands over the work order), checkpoint in slot 10.

ar_log("start in " .. ar_set_name())
-- the new game starts here, once the intro is over: the save the other runs start from
ar_wait_for_control()

if system.currentSet == mo then
	ar_log("step: office to hallway")
	ar_go(mo.ha_door, ha)
end

if system.currentSet == ha then
	ar_log("step: hallway to garage")
	ar_go(ha.ga_door, ga)
end

if system.currentSet ~= ga then
	ar_log("FAIL not in the garage: " .. ar_set_name())
	ar_finish()
end

ar_log("step: fountain")
ar_walk_to(ga.fountain.use_pnt_x, ga.fountain.use_pnt_y, ga.fountain.use_pnt_z, function() return system.buttonHandler == gl1 end)
-- (after the walk: Manny arrives on the elevator spot, where the floor is no way to anywhere until he has stepped off it)
ar_extra("ch01 garage")
if system.buttonHandler ~= gl1 then
	ar_do("use", ga.fountain)
end

ar_log("step: talk to Glottis")
ar_extra("ch01 glottis first")
ar_pick(gl1, 60)
ar_pick(gl1, 70)
ar_pick(gl1, 80)
ar_pick(gl1, 90)
ar_extra("ch01 glottis beg")
ar_pick(gl1, 220)
ar_wait_for(function() return ar_has(ga.work_order) end, 120000)
ar_check(ar_has(ga.work_order), "Manny has the work order")
ar_wait_for_control()
ar_state("end of chapter 1")
ar_check(cur_puzzle_state[1], "puzzle state 1 set (Glottis recruited)")
ar_checkpoint(1)
