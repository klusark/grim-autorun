-- Chapter 10 (Year 2): back at the signpost fork from the tree pumps. Out of the wagon, pick up the signpost that Glottis loosened when he backed into
-- it and plant it in the navigation room at the point the route to Rubacava runs through: the floor opens to a trapdoor. Checkpoint in slot 25.

ar_load(9)
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
ar_check(system.currentSet == sg, "at the signpost fork")
-- leave the wagon (USE leaves it)
if manny.is_driving then
	ar_press("use")
	ar_wait_for(function() return not manny.is_driving end, 60000)
	ar_wait_for_control()
end
-- (the wagon stands just west of where Manny gets out, its side a wall from 7.3 -3.6 to 6.6 -2.3 across the way to the signpost, and the planner does not
-- know it: round its rear end, to the south, first)
if manny:getpos().x > 6 then
	-- (with the stick, which stops where the wagon holds him: the planner would plan the same blocked way again and again)
	ar_walk_stick(7.4, -4.9, 0, nil, 5000)
	ar_walk_stick(5.0, -5.0, 0, nil, 5000)
	local p = manny:getpos()
	ar_log(format("past the wagon at %.2f %.2f", p.x, p.y))
end
-- (100% modes: a look at the signpost first; now that it is loose it is the close view of Manny at it, sg_mancu, that only this shows)
if AR_FULL then
	ar_do("lookAt", sg.signpost)
	ar_wait_for_control()
end
ar_do("pickUp", sg.signpost)
ar_check(cur_puzzle_state[12], "Manny has the signpost (puzzle state 12)")

ar_go(sg.na_door, na)
-- the point the signpost has to be planted at
ar_walk_to(na.rubacava_point.x, na.rubacava_point.y, na.rubacava_point.z)
ar_do("use", sg.signpost)
ar_wait_for(function() return nav_solved end, 120000)
ar_check(nav_solved, "the navigation is solved, the trapdoor is open (puzzle state 13)")
ar_wait_for_control()
ar_state("end of chapter 10")
ar_checkpoint(10)
