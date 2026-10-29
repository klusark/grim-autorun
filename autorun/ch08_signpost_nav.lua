-- Chapter 8 (Year 2): Glottis has his heart, he backs the Bone Wagon into the signpost and
-- drives off. Get out of the wagon, pick up the loosened signpost and plant it in the navigation
-- room at the point the route to Rubacava runs through: the floor opens to a trapdoor.
-- Checkpoint in slot 23.

ar_load(7)
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
-- leave the wagon (USE leaves it)
ar_press("use")
ar_wait_for(function() return not manny.is_driving end, 60000)
ar_wait_for_control()
ar_do("pickUp", sg.signpost)
ar_check(cur_puzzle_state[12], "Manny has the signpost (puzzle state 12)")

ar_go(sg.na_door, na)
-- the point the signpost has to be planted at
ar_walk_to(na.rubacava_point.x, na.rubacava_point.y, na.rubacava_point.z)
ar_do("use", sg.signpost)
ar_wait_for(function() return nav_solved end, 120000)
ar_check(nav_solved, "the navigation is solved, the trapdoor is open (puzzle state 13)")
ar_wait_for_control()
ar_state("end of chapter 8")
ar_checkpoint(8)
