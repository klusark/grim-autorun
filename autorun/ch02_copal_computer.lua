-- Chapter 2: with the work order in hand, go out of the building, up the rope to the ledge,
-- in through Copal's window and set his computer to the right answer (5), back down and hand
-- the work order to Eva. That starts the Land of the Living. Checkpoint in slot 11.

ar_load(1)
ar_log("start in " .. ar_set_name())
ar_state("start of chapter 2")

-- garage -> hallway (the elevator up), then hallway -> lobby (the other elevator)
if system.currentSet == ga then
	ar_go(ga.ha_door, ha)
end
ar_go(ha.lo_door, lo)
ar_expect_set(lo, "in the lobby")

-- lobby -> outside, the door of the building
ar_do("use", lo.os_door)
ar_expect_set(os, "outside")

-- outside -> street -> alley, through the door sectors
ar_go(os.st_door, st)

-- the first time outside: the clown at the festival gives the two dead worms (empty balloons) and the inflated cat balloon, and the bread
-- is in the basket; chapters 4 and 6 use them
ar_log("step: the clown")
ar_go(st.fe_door, fe)
ar_do("use", fe.clown_obj)
ar_pick(cl1, 50)
ar_pick(cl1, 60)
ar_pick(cl1, 63)
ar_pick(cl1, 104)
ar_wait_for(function() return ar_find_owned(fe.balloons) end, 120000)
ar_check(ar_find_owned(fe.balloons), "the first dead worm")
ar_wait_for_control()
ar_do("use", fe.clown_obj)
ar_pick(cl1, 64)
ar_pick(cl1, 104)
ar_wait_for(function() return ar_find_owned(fe.balloons) end, 5000)
ar_wait_for_control()
ar_do("use", fe.clown_obj)
ar_pick(cl1, 64)
ar_pick(cl1, 100)
ar_wait_for(function() return fe.balloon_cat.owner == manny end, 120000)
ar_check(fe.balloon_cat.owner == manny, "Manny has the cat balloon")
ar_wait_for_control()
ar_do("pickUp", fe.basket)
ar_check(ar_find_owned(fe.breads), "Manny has a piece of bread")
ar_go(fe.st_door, st)
ar_go(st.al_door, al)

-- the rope up to the ledge, in through the window
ar_do("use", al.rope)
ar_expect_set(le, "on the ledge")
ar_do("use", le.co_door)
ar_expect_set(co, "in Copal's office")

-- Copal's computer: select the fifth answer and confirm
ar_do("use", co.computer)
ar_wait_for(function() return co.computer.interface_active end, 20000)
ar_check(co.computer.interface_active, "the computer interface is up")
-- the computer takes the keys itself: down four times to the fifth answer, then USE
while co.computer.selection < 4 do
	ar_press("down")
	sleep_for(1200)
end
ar_press("use")
ar_wait_for(function() return not co.computer.interface_active end, 60000)
ar_wait_for_control()
ar_check(co.computer.auto_response == 5, "the answer is set to 5")
ar_check(co.computer.set_to_sign, "the work order will be signed")

-- back out the window, down the rope, through the building to Eva
ar_do("use", co.le_door)
ar_expect_set(le, "back on the ledge")
ar_do("use", le.rope_down)
ar_expect_set(al, "back in the alley")
ar_go(al.st_door, st)
ar_go(st.os_door, os)
ar_do("use", os.lo_door)
ar_expect_set(lo, "back in the lobby")
ar_go(lo.ha_door, ha)

ar_do("use", ha.eva_obj, ga.work_order)
ar_wait_for(function() return system.currentSet == lr end, 180000)
ar_expect_set(lr, "the Land of the Living")
ar_wait_for_control()
ar_state("end of chapter 2")
ar_checkpoint(2)
